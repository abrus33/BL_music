// ============================================================================
// BilibiliApiClient.cpp - B站 API 客户端实现
// 功能：实现所有 B站 REST API 的调用封装
// ============================================================================

#include "BilibiliApiClient.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QUrlQuery>
#include <QUrl>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QCryptographicHash>
#include <QDateTime>
#include <QMap>
#include <QSet>
#include <QThread>
#include <QDebug>

#include "network/HttpClient.h"

#define DBG qDebug().noquote() << "[BilibiliApiClient]"

/**
 * @brief 构造函数
 * @param httpClient HttpClient 实例指针
 * @param parent     Qt 父对象
 *
 * HttpClient 由 ApplicationContext 创建和管理，本类只使用不拥有。
 */
BilibiliApiClient::BilibiliApiClient(HttpClient *httpClient, QObject *parent)
    : QObject(parent)
    , m_httpClient(httpClient)
{
}

void BilibiliApiClient::warmUp()
{
    DBG << "warmUp() - 访问 B站 首页建立会话...";
    QNetworkRequest request(QUrl(QStringLiteral("https://www.bilibili.com/")));
    request.setRawHeader("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8");
    request.setRawHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                         "AppleWebKit/537.36 (KHTML, like Gecko) "
                         "Chrome/120.0.0.0 Safari/537.36");
    // warmUp 不需要 Referer/Origin（浏览器直接访问首页本来就没有）
    QNetworkReply *reply = m_httpClient->networkManager()->get(request);
    QObject::connect(reply, &QNetworkReply::finished, this, [reply]() {
        int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        DBG << "warmUp 响应: httpStatus:" << status
            << "cookies:" << reply->header(QNetworkRequest::SetCookieHeader).toString();
        reply->deleteLater();
    });
}

// ============================================================================
// 通用请求方法
// ============================================================================

/**
 * @brief 发送 GET 请求并解析 JSON 响应（核心通用方法）
 * @param apiName  API 名称（日志/错误报告用）
 * @param url      完整请求 URL
 * @param callback 回调 (success, jsonObj, errorMsg)
 *
 * **设计决策 —— 为什么不用 HttpClient::get() + requestFinished 全局信号？**
 *
 * HttpClient 的信号路由模式有一个致命缺陷：当多个 getJson 调用并发时
 * （如 generateQrCode 和 checkLogin 同时活跃），两者的回调都连接到了
 * 同一个 requestFinished 信号。如果 generateQrCode 的 code:0 响应先到达，
 * 它可能触发 checkLogin 的回调（反之亦然），导致：
 *   - 扫码登录成功信号被当成 nav 接口的响应处理
 *   - 用户看到"登录成功"但实际上 Cookie 并未导入
 *   - 不同回调的时序完全不确定
 *
 * **解决方案：独立 QNetworkReply 连接**
 * 不再经过 HttpClient 的信号总线，直接使用 QNetworkAccessManager::get()
 * 并为每个 reply 创建独占的 QNetworkReply::finished 连接。
 * 每个请求和它的回调之间是 1:1 的绑定关系，不存在窜扰可能。
 *
 * **为什么仍然需要 HttpClient？**
 * HttpClient 持有 QNetworkAccessManager 实例（含 PersistentCookieJar），
 * 通过 m_httpClient->networkManager() 访问，确保所有请求自动携带 Cookie。
 * 同时手动设置了必需的 HTTP Headers（User-Agent、Referer、Accept）。
 */
void BilibiliApiClient::getJson(const QString &apiName, const QUrl &url,
                                 std::function<void(bool, QJsonObject, QString)> callback)
{
    DBG << "getJson REQUEST api:" << apiName
        << "url:" << url.toString(QUrl::RemoveQuery).left(80)
        << "thread:" << QThread::currentThread();

    // 直接使用 QNetworkAccessManager 创建独立请求
    QNetworkRequest request(url);
    request.setRawHeader("Accept", "application/json, text/plain, */*");
    request.setRawHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                         "AppleWebKit/537.36 (KHTML, like Gecko) "
                         "Chrome/120.0.0.0 Safari/537.36");
    request.setRawHeader("Referer", "https://www.bilibili.com");
    request.setRawHeader("Origin", "https://www.bilibili.com");

    QNetworkReply *reply = m_httpClient->networkManager()->get(request);

    QObject::connect(reply, &QNetworkReply::finished, this, [reply, apiName, callback, this]() {
        reply->deleteLater();

        int statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        QByteArray body = reply->readAll();
        bool networkOk = (reply->error() == QNetworkReply::NoError);

        DBG << "getJson RESPONSE api:" << apiName
            << "httpStatus:" << statusCode
            << "networkOk:" << networkOk
            << "bodySize:" << body.size();

        if (!networkOk) {
            QString bodyPreview = QString::fromUtf8(body.left(500));
            DBG << "getJson ERROR body:" << bodyPreview;
            emit apiError(apiName, statusCode, reply->errorString());
            callback(false, QJsonObject(), QStringLiteral("网络错误: ") + reply->errorString());
            return;
        }

        QJsonDocument doc = QJsonDocument::fromJson(body);
        if (!doc.isObject()) {
            callback(false, QJsonObject(), QStringLiteral("JSON 解析失败"));
            return;
        }

        QJsonObject json = doc.object();
        int code = json.value(QStringLiteral("code")).toInt(-1);
        QString message = json.value(QStringLiteral("message")).toString();

        if (code != 0) {
            DBG << "getJson API ERROR api:" << apiName << "code:" << code << "msg:" << message;
            if (code != -1) {
                emit apiError(apiName, code, message);
            }
            callback(false, json, message);
            return;
        }

        DBG << "getJson API OK api:" << apiName;
        callback(true, json, QString());
    });
}

// ============================================================================
// 登录相关 API
// ============================================================================

/**
 * @brief 获取导航栏用户信息（判断登录态）
 *
 * 这是 B站最常用的登录态检测接口：
 * - code=0 且 data.isLogin=true -> 已登录
 * - code=-101 -> 未登录
 *
 * @param callback 回调 (success, data, error)
 *                 data 包含：isLogin, uname, mid, face 等用户信息
 */
void BilibiliApiClient::getNavInfo(std::function<void(bool, QJsonObject, QString)> callback)
{
    QUrl url(QStringLiteral("https://api.bilibili.com/x/web-interface/nav"));

    getJson(QStringLiteral("nav"), url, [callback](bool success, QJsonObject json, QString error) {
        if (!success) {
            callback(false, QJsonObject(), error);
            return;
        }
        // data 字段包含实际的用户信息
        QJsonObject data = json.value(QStringLiteral("data")).toObject();
        callback(true, data, QString());
    });
}

/**
 * @brief 检查 Cookie 是否需要刷新
 *
 * 根据 B站的风控机制，Cookie 可能需要在每日首次访问时刷新。
 * 刷新流程较为复杂（需要 RSA 加密生成 correspondPath），
 * 此处先实现检查逻辑，刷新逻辑作为后续增强。
 *
 * @param callback 回调 (needRefresh, timestamp)
 */
void BilibiliApiClient::checkCookieRefresh(
    std::function<void(bool needRefresh, qint64 timestamp)> callback)
{
    QUrl url(QStringLiteral("https://passport.bilibili.com/x/passport-login/web/cookie/info"));

    getJson(QStringLiteral("cookie_info"), url,
            [callback](bool success, QJsonObject json, QString error) {
        if (!success) {
            callback(false, 0);
            return;
        }
        QJsonObject data = json.value(QStringLiteral("data")).toObject();
        bool needRefresh = data.value(QStringLiteral("refresh")).toBool(false);
        qint64 timestamp = static_cast<qint64>(data.value(QStringLiteral("timestamp")).toDouble(0));
        callback(needRefresh, timestamp);
    });
}

void BilibiliApiClient::generateQrCode(
    std::function<void(bool, QString, QString, QString)> callback)
{
    DBG << "generateQrCode() - 请求生成二维码";

    QUrl url(QStringLiteral("https://passport.bilibili.com/x/passport-login/web/qrcode/generate"));

    // 使用 getJson 发送请求（独立 QNetworkReply 连接，无信号窜扰）
    getJson(QStringLiteral("qrcode_generate"), url,
            [callback](bool success, QJsonObject json, QString error) {
        DBG << "generateQrCode 响应: success=" << success << "error=" << error;
        if (!success) {
            callback(false, QString(), QString(), error);
            return;
        }

        // 提取 data 中的 url 和 qrcode_key
        QJsonObject data = json.value(QStringLiteral("data")).toObject();
        QString qrUrl = data.value(QStringLiteral("url")).toString();
        QString qrcodeKey = data.value(QStringLiteral("qrcode_key")).toString();

        DBG << "  qrcode_key=" << qrcodeKey << "url_len=" << qrUrl.length();

        // 校验：两个字段都必须非空才算成功
        callback(!qrUrl.isEmpty() && !qrcodeKey.isEmpty(), qrUrl, qrcodeKey, QString());
    });
}

void BilibiliApiClient::pollQrCode(const QString &qrcodeKey,
                                   std::function<void(int, QString)> callback)
{
    QUrl url(QStringLiteral("https://passport.bilibili.com/x/passport-login/web/qrcode/poll"));
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("qrcode_key"), qrcodeKey);
    url.setQuery(query);

    // 手动设置请求头（模拟浏览器行为，避免被反爬拦截）
    QNetworkRequest request(url);
    request.setRawHeader("Accept", "application/json, text/plain, */*");
    request.setRawHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                         "AppleWebKit/537.36 (KHTML, like Gecko) "
                         "Chrome/120.0.0.0 Safari/537.36");
    request.setRawHeader("Referer", "https://www.bilibili.com");

    // ★ 关键设计：独立 QNetworkReply 连接
    // 不使用 getJson()，因为轮询请求每2秒一次，若复用 getJson 的信号路由
    // 可能与 checkLogin/getNavInfo 等并发请求产生响应窜扰
    QNetworkReply *reply = m_httpClient->networkManager()->get(request);

    // 连接 reply 的 finished 信号（1:1 绑定，不会被其他请求的回调干扰）
    QObject::connect(reply, &QNetworkReply::finished, this, [reply, callback]() {
        reply->deleteLater();

        int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        QByteArray body = reply->readAll();

        // 完整响应日志（调试用）
        DBG << "pollQrCode httpStatus=" << httpStatus << "body=" << QString::fromUtf8(body);

        // 网络层错误
        if (reply->error() != QNetworkReply::NoError) {
            DBG << "pollQrCode 网络错误:" << reply->errorString();
            callback(-1, QStringLiteral("网络错误: ") + reply->errorString());
            return;
        }

        QJsonDocument doc = QJsonDocument::fromJson(body);
        if (!doc.isObject()) {
            DBG << "pollQrCode JSON解析失败";
            callback(-1, QStringLiteral("JSON 解析失败"));
            return;
        }

        // =====================================================================
        // ★ B站 poll API 嵌套 JSON 解析逻辑（曾是最棘手的 Bug 根源）
        //
        // B站 poll API 返回的 JSON 有两种可能的格式：
        //
        // 格式 A — 嵌套格式（最常见）：
        //   { "code": 0,
        //     "data": {
        //       "code": 86101,       // ← 这才是扫码状态码！
        //       "message": "未扫码"
        //     }
        //   }
        //
        // 格式 B — 扁平格式（成功时可能返回）：
        //   { "code": 0,
        //     "data": {
        //       "url": "https://...",          // 无 data.code 字段
        //       "refresh_token": "abc123..."    // 但有登录凭据
        //     }
        //   }
        //
        // 早期的 Bug：直接取顶层 code（永远是 0=请求成功），导致：
        //   二维码刚生成就显示"登录成功"（实际 data.code=86101 未扫码）
        //   用户扫码确认后登录不生效  （顶层 code 仍为 0，未进入成功分支）
        //
        // 修复策略：
        //   1. 优先检查 data.code 是否存在（嵌套格式）
        //   2. 如果 data 无 code 字段但含 url/refresh_token → 登录成功（扁平格式）
        //   3. 如果 data 无 code 且无凭据 → 按未扫码处理（顶层 code=0 是假阳性）
        // =====================================================================
        QJsonObject json = doc.object();
        int topCode = json.value(QStringLiteral("code")).toInt(-1);
        QJsonObject data = json.value(QStringLiteral("data")).toObject();

        int scanCode = topCode;
        QString scanMsg;

        if (data.contains(QStringLiteral("code"))) {
            // 格式 A：嵌套格式，取 data.code 作为真实扫码状态
            scanCode = data.value(QStringLiteral("code")).toInt(-1);
            scanMsg = data.value(QStringLiteral("message")).toString();
        } else if (topCode == 0) {
            // 格式 B：顶层 code=0，但 data 没有 code 字段
            // 检查 data 是否包含登录凭据（url 或 refresh_token）
            if (!data.value(QStringLiteral("url")).toString().isEmpty() ||
                !data.value(QStringLiteral("refresh_token")).toString().isEmpty()) {
                scanCode = 0; // 真正的登录成功（服务器已返回 Cookie）
            } else {
                // topCode=0 但 data 无任何有用信息 → 当作未扫码继续轮询
                scanCode = 86101;
            }
        }

        DBG << "pollQrCode scanCode=" << scanCode << "msg=" << scanMsg;
        callback(scanCode, scanMsg);
    });
}

// ============================================================================
// 收藏夹相关 API
// ============================================================================

/**
 * @brief 获取用户创建的收藏夹列表
 *
 * @param upMid    用户 mid（从 nav 接口的 data.mid 获取）
 * @param callback 回调 (success, folders, error)
 *                 folders 数组中每个元素包含：id, title, media_count 等
 */
void BilibiliApiClient::getFavoriteFolderList(qint64 upMid,
    std::function<void(bool, QJsonArray, QString)> callback)
{
    QUrl url(QStringLiteral("https://api.bilibili.com/x/v3/fav/folder/created/list-all"));
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("up_mid"), QString::number(upMid));
    url.setQuery(query);

    getJson(QStringLiteral("fav_folder_list"), url,
            [callback](bool success, QJsonObject json, QString error) {
        if (!success) {
            callback(false, QJsonArray(), error);
            return;
        }
        QJsonObject data = json.value(QStringLiteral("data")).toObject();
        QJsonArray list = data.value(QStringLiteral("list")).toArray();
        callback(true, list, QString());
    });
}

/**
 * @brief 获取收藏夹内容明细列表
 *
 * @param mediaId   收藏夹 mlid（完整 id，从收藏夹列表的 id 字段获取）
 * @param page      页码（从 1 开始）
 * @param pageSize  每页数量（1-20）
 * @param callback  回调 (success, info, medias, hasMore, error)
 *                  info: 收藏夹元数据（标题等）
 *                  medias: 内容列表（audio/video）
 *                  hasMore: 是否有下一页
 */
void BilibiliApiClient::getFavoriteResourceList(qint64 mediaId, int page, int pageSize,
    std::function<void(bool, QJsonObject, QJsonArray, bool, QString)> callback)
{
    DBG << "getFavoriteResourceList() mediaId:" << mediaId
        << "page:" << page << "pageSize:" << pageSize;

    QUrl url(QStringLiteral("https://api.bilibili.com/x/v3/fav/resource/list"));
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("media_id"), QString::number(mediaId));
    query.addQueryItem(QStringLiteral("pn"), QString::number(page));
    query.addQueryItem(QStringLiteral("ps"), QString::number(qBound(1, pageSize, 20)));
    query.addQueryItem(QStringLiteral("platform"), QStringLiteral("web"));
    url.setQuery(query);

    getJson(QStringLiteral("fav_resource_list"), url,
            [callback, mediaId, page](bool success, QJsonObject json, QString error) {
        DBG << "getFavoriteResourceList 响应: mediaId:" << mediaId
            << "page:" << page << "success:" << success
            << "error:" << error;

        if (!success) {
            callback(false, QJsonObject(), QJsonArray(), false, error);
            return;
        }
        QJsonObject data = json.value(QStringLiteral("data")).toObject();
        QJsonObject info = data.value(QStringLiteral("info")).toObject();
        QJsonArray medias = data.value(QStringLiteral("medias")).toArray();
        bool hasMore = data.value(QStringLiteral("has_more")).toBool(false);

        DBG << "getFavoriteResourceList 解析: medias_count:" << medias.size()
            << "hasMore:" << hasMore;

        callback(true, info, medias, hasMore, QString());
    });
}

// ============================================================================
// 音乐区 API
// ============================================================================

void BilibiliApiClient::getMusicRank(int page, int pageSize,
    std::function<void(bool, QJsonArray, QString)> callback)
{
    DBG << "getMusicRank() - page:" << page << "size:" << pageSize;
    QUrl url(QStringLiteral("https://www.bilibili.com/audio/music-service-c/web/menu/rank"));
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("pn"), QString::number(page));
    query.addQueryItem(QStringLiteral("ps"), QString::number(pageSize));
    url.setQuery(query);

    getJson(QStringLiteral("music_rank"), url,
            [callback](bool success, QJsonObject json, QString error) {
        if (!success) { callback(false, QJsonArray(), error); return; }
        QJsonObject data = json.value(QStringLiteral("data")).toObject();
        QJsonArray list = data.value(QStringLiteral("data")).toArray();
        callback(true, list, QString());
    });
}

// ============================================================================
// 音频/视频流 API
// ============================================================================

/**
 * @brief 获取音频播放 URL
 *
 * web 端音频接口（无需登录，192K 音质）：
 * GET https://www.bilibili.com/audio/music-service-c/web/url?sid={audioId}
 *
 * 返回的 cdns 数组中包含可播放的音频 URL（一般为 m4a 格式）
 * QMediaPlayer 可直接播放此 URL
 *
 * @param audioId  音频 auid
 * @param callback 回调 (success, url, error)
 *                 url 可直接用于 QMediaPlayer 播放
 */
/**
 * @brief 获取视频分P信息（获取 cid）
 */
void BilibiliApiClient::getVideoCid(const QString &bvid,
    std::function<void(bool, qint64, QString)> callback)
{
    DBG << "getVideoCid() - bvid:" << bvid;
    QUrl url(QStringLiteral("https://api.bilibili.com/x/web-interface/view"));
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("bvid"), bvid);
    url.setQuery(query);
    getJson(QStringLiteral("video_view"), url,
            [callback, bvid](bool success, QJsonObject json, QString error) {
        if (!success) { callback(false, 0, error); return; }
        QJsonObject data = json.value(QStringLiteral("data")).toObject();
        qint64 cid = static_cast<qint64>(data.value(QStringLiteral("cid")).toDouble(0));
        DBG << "cid:" << cid;
        callback(cid != 0, cid, QString());
    });
}

void BilibiliApiClient::getAudioStreamUrl(qint64 audioId,
    std::function<void(bool, QString, QString)> callback)
{
    DBG << "getAudioStreamUrl() - audioId:" << audioId;
    QUrl url(QStringLiteral("https://www.bilibili.com/audio/music-service-c/web/url"));
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("sid"), QString::number(audioId));
    url.setQuery(query);

    // 注意：音频接口返回的是 code+msg（不是标准的 code+message）
    // 使用 getJson 会导致 msg 被当做 message 字段
    m_httpClient->get(url);

    QMetaObject::Connection *conn = new QMetaObject::Connection();
    *conn = connect(m_httpClient, &HttpClient::requestFinished,
                    this, [this, conn, callback](const HttpClient::Response &response) {
        disconnect(*conn);
        delete conn;

        DBG << "音频URL响应 - statusCode:" << response.statusCode
            << "body.length:" << response.body.length();

        if (!response.success) {
            DBG << "网络错误:" << response.errorString;
            callback(false, QString(), QStringLiteral("网络错误: ") + response.errorString);
            return;
        }

        QJsonObject json = response.json();
        if (json.isEmpty()) {
            DBG << "JSON 解析失败, body:" << QString::fromUtf8(response.body.left(200));
            callback(false, QString(), QStringLiteral("JSON 解析失败"));
            return;
        }

        // 音频接口使用 code + msg 字段
        int code = json.value(QStringLiteral("code")).toInt(-1);
        DBG << "音频响应 code:" << code;
        if (code != 0) {
            QString msg = json.value(QStringLiteral("msg")).toString(QStringLiteral("未知错误"));
            DBG << "API 错误:" << code << msg;
            emit apiError(QStringLiteral("audio_url"), code, msg);
            callback(false, QString(), QString::number(code) + QStringLiteral(": ") + msg);
            return;
        }

        // 从 cdns 数组中取第一个可播放 URL
        QJsonObject data = json.value(QStringLiteral("data")).toObject();
        QJsonArray cdns = data.value(QStringLiteral("cdns")).toArray();
        DBG << "cdns 数量:" << cdns.size();
        if (cdns.isEmpty()) {
            callback(false, QString(), QStringLiteral("没有可用的音频流地址"));
            return;
        }

        // cdns[0] 为主地址，cdns[1] 为备用地址
        QString audioUrl = cdns[0].toString();
        DBG << "音频URL获取成功, 长度:" << audioUrl.length();
        callback(true, audioUrl, QString());
    });
}

/**
 * @brief 获取视频播放 URL
 *
 * 使用 WBI 签名认证的 playurl 接口：
 * GET https://api.bilibili.com/x/player/wbi/playurl
 *
 * @param bvid    视频 BV 号
 * @param cid     视频分 P 的 cid（至少需要第一个分 P）
 * @param callback 回调 (success, url, error)
 *                 对于 DASH 格式返回首个视频流的 URL
 */
void BilibiliApiClient::getVideoPlayUrl(const QString &bvid, qint64 cid,
    std::function<void(bool, QString, QString)> callback)
{
    // 构建请求参数
    QMap<QString, QString> params;
    params[QStringLiteral("bvid")] = bvid;
    params[QStringLiteral("cid")] = QString::number(cid);
    params[QStringLiteral("qn")] = QStringLiteral("64");    // 720P 高清
    params[QStringLiteral("fnval")] = QStringLiteral("16");  // DASH 格式
    params[QStringLiteral("fourk")] = QStringLiteral("1");

    // 先获取 WBI 签名密钥，再签名并发送请求
    getWbiKeys([this, params, callback](QString imgKey, QString subKey) {
        // 对参数进行 WBI 签名
        QMap<QString, QString> signedParams = signWbi(params, imgKey, subKey);

        // 构建带签名的 URL
        QUrl url(QStringLiteral("https://api.bilibili.com/x/player/wbi/playurl"));
        QUrlQuery query;
        for (auto it = signedParams.constBegin(); it != signedParams.constEnd(); ++it) {
            query.addQueryItem(it.key(), it.value());
        }
        url.setQuery(query);

        // 发送请求
        getJson(QStringLiteral("video_playurl"), url,
                [callback](bool success, QJsonObject json, QString error) {
            if (!success) {
                callback(false, QString(), error);
                return;
            }

            QJsonObject data = json.value(QStringLiteral("data")).toObject();

            // 优先尝试 DASH 格式的音频流（音乐客户端只需要音频）
            QJsonObject dash = data.value(QStringLiteral("dash")).toObject();
            if (!dash.isEmpty()) {
                // DASH 格式：取第一个音频流的 baseUrl
                QJsonArray audio = dash.value(QStringLiteral("audio")).toArray();
                if (!audio.isEmpty()) {
                    QString baseUrl = audio[0].toObject().value(QStringLiteral("baseUrl")).toString();
                    if (!baseUrl.isEmpty()) {
                        DBG << "使用 DASH 音频流";
                        callback(true, baseUrl, QString());
                        return;
                    }
                }
            }

            // 尝试 MP4 格式的备用地址
            QJsonArray durl = data.value(QStringLiteral("durl")).toArray();
            if (!durl.isEmpty()) {
                QString url = durl[0].toObject().value(QStringLiteral("url")).toString();
                if (!url.isEmpty()) {
                    callback(true, url, QString());
                    return;
                }
            }

            callback(false, QString(), QStringLiteral("无法获取视频播放地址"));
        });
    });
}

// ============================================================================
// WBI 签名相关（私有方法）
// ============================================================================

/**
 * @brief 获取 WBI 签名密钥
 * @param callback 回调 (imgKey, subKey)
 *
 * WBI 密钥从 nav 接口的 wbi_img 字段获取
 * 即使未登录也可以获取，但每日会更新
 */
void BilibiliApiClient::getWbiKeys(std::function<void(QString, QString)> callback)
{
    // 如果已有缓存的密钥，直接使用
    // 注意：生产环境应每日刷新缓存
    if (!m_wbiImgKey.isEmpty() && !m_wbiSubKey.isEmpty()) {
        callback(m_wbiImgKey, m_wbiSubKey);
        return;
    }

    // 从 nav 接口获取新的密钥
    getNavInfo([this, callback](bool success, QJsonObject data, QString error) {
        Q_UNUSED(success)
        Q_UNUSED(error)

        // 从 wbi_img 对象中提取密钥
        // 即使未登录，nav 接口也会返回 wbi_img
        QJsonObject wbiImg = data.value(QStringLiteral("wbi_img")).toObject();
        QString imgUrl = wbiImg.value(QStringLiteral("img_url")).toString();
        QString subUrl = wbiImg.value(QStringLiteral("sub_url")).toString();

        // 从 URL 中提取文件名（去掉目录和扩展名）
        // 例如: https://i0.hdslb.com/bfs/wbi/abc123def456.png -> abc123def456
        auto extractKey = [](const QString &url) -> QString {
            int lastSlash = url.lastIndexOf('/');
            int dot = url.lastIndexOf('.');
            if (lastSlash >= 0 && dot > lastSlash) {
                return url.mid(lastSlash + 1, dot - lastSlash - 1);
            }
            return QString();
        };

        m_wbiImgKey = extractKey(imgUrl);
        m_wbiSubKey = extractKey(subUrl);

        callback(m_wbiImgKey, m_wbiSubKey);
    });
}

/**
 * @brief WBI 签名算法
 * @param params  原始请求参数
 * @param imgKey  WBI img_key
 * @param subKey  WBI sub_key
 * @return 添加了 w_rid 和 wts 后的完整参数映射
 *
 * 签名步骤：
 * 1. 将 imgKey 和 subKey 拼接
 * 2. 使用 MIXIN_KEY_ENC_TAB 重排，取前 32 位得到 mixinKey
 * 3. 将参数按 key 排序后拼接为字符串
 * 4. 在字符串后追加 mixinKey
 * 5. 计算 MD5 得到 w_rid
 * 6. 添加当前时间戳 wts
 */
QMap<QString, QString> BilibiliApiClient::signWbi(
    const QMap<QString, QString> &params,
    const QString &imgKey, const QString &subKey)
{
    // WBI 重排映射表（B站固定的 64 字节索引表）
    static const int mixinKeyEncTab[64] = {
        46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35,
        27, 43, 5, 49, 33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13,
        37, 48, 7, 16, 24, 55, 40, 61, 26, 17, 0, 1, 60, 51, 30, 4,
        22, 25, 54, 21, 56, 59, 6, 63, 57, 62, 11, 36, 20, 34, 44, 52
    };

    // 1. 拼接 imgKey + subKey
    QString rawKey = imgKey + subKey;

    // 2. 按映射表重排，取前 32 位
    QByteArray mixinKey;
    mixinKey.reserve(32);
    for (int i = 0; i < 32; ++i) {
        int idx = mixinKeyEncTab[i];
        if (idx < rawKey.length()) {
            mixinKey.append(rawKey.at(idx).toLatin1());
        }
    }

    // 3. 复制参数并添加当前时间戳
    QMap<QString, QString> sortedParams = params;
    QString wts = QString::number(QDateTime::currentSecsSinceEpoch());
    sortedParams[QStringLiteral("wts")] = wts;

    // 4. 按 key 字典序排序，拼接为字符串
    QStringList keys = sortedParams.keys();
    keys.sort();
    QString queryString;
    for (const QString &key : keys) {
        if (!queryString.isEmpty())
            queryString += '&';
        queryString += key + '=' + sortedParams[key];
    }

    // 5. 拼接 mixinKey，计算 MD5
    QString toSign = queryString + QString::fromLatin1(mixinKey);
    QByteArray wRid = QCryptographicHash::hash(toSign.toUtf8(), QCryptographicHash::Md5).toHex();

    // 6. 返回添加了签名的完整参数
    QMap<QString, QString> result = params;
    result[QStringLiteral("w_rid")] = QString::fromLatin1(wRid);
    result[QStringLiteral("wts")] = wts;

    return result;
}
