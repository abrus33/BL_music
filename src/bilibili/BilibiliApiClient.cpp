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
#include <QCryptographicHash>
#include <QDateTime>
#include <QMap>
#include <QSet>

#include "network/HttpClient.h"

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

// ============================================================================
// 通用请求方法
// ============================================================================

/**
 * @brief 发送 GET 请求并解析 JSON 响应
 * @param apiName  API 名称（日志/错误报告用）
 * @param url      完整请求 URL
 * @param callback 回调 (success, jsonObj, errorMsg)
 *
 * 所有 B站 API 的通用调用模式：
 * 1. 通过 HttpClient::get() 发送请求
 * 2. 连接 requestFinished 信号处理响应
 * 3. 解析 JSON，检查 code 字段
 * 4. 通过 callback 返回结果
 */
void BilibiliApiClient::getJson(const QString &apiName, const QUrl &url,
                                 std::function<void(bool, QJsonObject, QString)> callback)
{
    // 发送 GET 请求
    m_httpClient->get(url);

    // 连接信号：请求完成后处理响应
    // 使用 QObject::connect 的 lambda 形式
    QMetaObject::Connection *conn = new QMetaObject::Connection();
    *conn = connect(m_httpClient, &HttpClient::requestFinished,
                    this, [this, conn, apiName, callback](const HttpClient::Response &response) {
        // 断开连接（一次性回调，避免重复触发）
        disconnect(*conn);
        delete conn;

        // 检查网络层是否成功
        if (!response.success) {
            callback(false, QJsonObject(), QStringLiteral("网络错误: ") + response.errorString);
            return;
        }

        // 解析 JSON 响应
        QJsonObject json = response.json();
        if (json.isEmpty()) {
            callback(false, QJsonObject(), QStringLiteral("JSON 解析失败"));
            return;
        }

        // 检查 B站 API 返回码
        // 常见的 B站 code 值：
        //   0    = 成功
        //  -101  = 账号未登录
        //  -111  = CSRF 校验失败
        //  -400  = 请求错误
        //  -403  = 访问权限不足
        //   其他 = 业务错误
        int code = json.value(QStringLiteral("code")).toInt(-1);
        QString message = json.value(QStringLiteral("message")).toString();

        if (code != 0) {
            // API 返回错误（但网络层面是成功的）
            if (code != -1) {
                emit apiError(apiName, code, message);
            }
            callback(false, json, message);
            return;
        }

        // 成功
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
    QUrl url(QStringLiteral("https://api.bilibili.com/x/v3/fav/resource/list"));
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("media_id"), QString::number(mediaId));
    query.addQueryItem(QStringLiteral("pn"), QString::number(page));
    query.addQueryItem(QStringLiteral("ps"), QString::number(qBound(1, pageSize, 20)));
    query.addQueryItem(QStringLiteral("platform"), QStringLiteral("web"));
    url.setQuery(query);

    getJson(QStringLiteral("fav_resource_list"), url,
            [callback](bool success, QJsonObject json, QString error) {
        if (!success) {
            callback(false, QJsonObject(), QJsonArray(), false, error);
            return;
        }
        QJsonObject data = json.value(QStringLiteral("data")).toObject();
        QJsonObject info = data.value(QStringLiteral("info")).toObject();
        QJsonArray medias = data.value(QStringLiteral("medias")).toArray();
        bool hasMore = data.value(QStringLiteral("has_more")).toBool(false);
        callback(true, info, medias, hasMore, QString());
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
void BilibiliApiClient::getAudioStreamUrl(qint64 audioId,
    std::function<void(bool, QString, QString)> callback)
{
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

        if (!response.success) {
            callback(false, QString(), QStringLiteral("网络错误: ") + response.errorString);
            return;
        }

        QJsonObject json = response.json();
        if (json.isEmpty()) {
            callback(false, QString(), QStringLiteral("JSON 解析失败"));
            return;
        }

        // 音频接口使用 code + msg 字段
        int code = json.value(QStringLiteral("code")).toInt(-1);
        if (code != 0) {
            QString msg = json.value(QStringLiteral("msg")).toString(QStringLiteral("未知错误"));
            emit apiError(QStringLiteral("audio_url"), code, msg);
            callback(false, QString(), QString::number(code) + QStringLiteral(": ") + msg);
            return;
        }

        // 从 cdns 数组中取第一个可播放 URL
        QJsonObject data = json.value(QStringLiteral("data")).toObject();
        QJsonArray cdns = data.value(QStringLiteral("cdns")).toArray();
        if (cdns.isEmpty()) {
            callback(false, QString(), QStringLiteral("没有可用的音频流地址"));
            return;
        }

        // cdns[0] 为主地址，cdns[1] 为备用地址
        QString audioUrl = cdns[0].toString();
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

            // 优先尝试 DASH 格式的视频流
            QJsonObject dash = data.value(QStringLiteral("dash")).toObject();
            if (!dash.isEmpty()) {
                // DASH 格式：取第一个视频流的 baseUrl
                QJsonArray video = dash.value(QStringLiteral("video")).toArray();
                if (!video.isEmpty()) {
                    QString baseUrl = video[0].toObject().value(QStringLiteral("baseUrl")).toString();
                    if (!baseUrl.isEmpty()) {
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
