// ============================================================================
// BilibiliApiClient.h - B站 API 客户端
// 功能：封装所有 B站 REST API 的调用，管理接口地址和请求参数
//       基于 HttpClient 发送请求，解析返回的 JSON 数据
// ============================================================================

#pragma once

#include <QObject>
#include <QJsonObject>
#include <QJsonArray>
#include <QUrl>
#include <functional>

class HttpClient;

/**
 * @brief B站 API 客户端
 *
 * 封装对 B站各种 REST API 的调用，提供类型安全的接口。
 * 所有方法都是异步的，通过信号或回调返回结果。
 *
 * 依赖 HttpClient 完成底层的 HTTP 请求。
 * Cookie 由 ApplicationContext 统一管理，通过 HttpClient 自动携带。
 */
class BilibiliApiClient : public QObject
{
    Q_OBJECT

public:
    /**
     * @brief 构造函数
     * @param httpClient HttpClient 实例指针（由 ApplicationContext 创建和管理）
     * @param parent     Qt 父对象
     */
    explicit BilibiliApiClient(HttpClient *httpClient, QObject *parent = nullptr);

    /**
     * @brief 预热会话 —— 先访问 B站 首页建立完整 Cookie/Session
     *
     * B站 对收藏夹内容等敏感接口有更严格的风控（HTTP 412），
     * 直接请求 API 容易被拦截。先访问一次首页可以让 B站 后端
     * 建立完整的会话上下文（写入必要的 cookie/指纹），
     * 后续 API 请求就不容易触发风控。
     *
     * 此方法是 fire-and-forget 的，不需要等待结果。
     */
    void warmUp();

    // ==================== 登录相关 API ====================

    /**
     * @brief 获取导航栏用户信息（判断登录态）
     *
     * API: GET https://api.bilibili.com/x/web-interface/nav
     * 认证方式：Cookie（SESSDATA）
     *
     * 返回示例（已登录）：
     *   { "code": 0, "data": { "isLogin": true, "uname": "昵称", ... } }
     * 返回示例（未登录）：
     *   { "code": -101, "message": "账号未登录" }
     *
     * @param callback 回调函数，参数为 (success, jsonData, errorString)
     */
    void getNavInfo(std::function<void(bool success, QJsonObject data, QString error)> callback);

    /**
     * @brief 检查 Cookie 是否需要刷新
     *
     * API: GET https://passport.bilibili.com/x/passport-login/web/cookie/info
     * 参数：csrf = bili_jct Cookie 的值
     *
     * 返回：{ "code": 0, "data": { "refresh": true/false, "timestamp": 1234567890 } }
     */
    void checkCookieRefresh(std::function<void(bool needRefresh, qint64 timestamp)> callback);

    /**
     * @brief 生成扫码登录二维码
     *
     * API: GET https://passport.bilibili.com/x/passport-login/web/qrcode/generate
     * 无需登录态即可调用
     *
     * 成功返回 data 包含：
     *   - url:          B站扫码链接（如 https://passport.bilibili.com/h5-app/...）
     *                   此 URL 不可直接显示为二维码图片，需通过在线服务编码为图片
     *   - qrcode_key:   用于后续轮询的临时密钥（约32字符），有效期约3分钟
     *
     * 返回格式示例：
     *   { "code": 0, "data": {
     *       "url": "https://passport.bilibili.com/h5-app/passport-login/scan?navhide=1&qrcode_key=xxx",
     *       "qrcode_key": "a1b2c3d4e5f6..."
     *   }}
     *
     * 内部实现：
     *   调用 getJson() → 独立 QNetworkReply 连接，不与全局信号混淆
     *
     * @param callback 回调 (success, url, qrcodeKey, error)
     *                 success=false 表示网络错误或 B站返回 code≠0
     */
    void generateQrCode(std::function<void(bool success, QString url, QString qrcodeKey, QString error)> callback);

    /**
     * @brief 轮询扫码登录状态
     *
     * API: GET https://passport.bilibili.com/x/passport-login/web/qrcode/poll?qrcode_key={key}
     * 无需登录态即可调用
     *
     * B站 poll API 使用嵌套 JSON 格式:
     *   { "code": 0, "data": { "code": <状态码>, "message": "<描述>" } }
     *
     * 注意：顶层 code 是请求处理状态（0=成功），data.code 才是扫码状态。
     * 本方法内部已处理嵌套解析，回调的 statusCode 参数直接是扫码状态码。
     *
     * 返回状态码含义：
     *   =============================================================================
     *   86101  — 未扫码           用户还没用 APP 扫码，继续轮询
     *   86090  — 已扫码待确认      用户在 APP 扫了码，但还没点"确认登录"
     *   86038  — 二维码已过期     有效期约 3 分钟，需重新生成
     *   0      — 扫码登录成功      用户在手机上确认了登录，
     *                              服务器在此响应中设置了 Set-Cookie（SESSDATA 等），
     *                              PersistentCookieJar 会自动捕获并持久化
     *   负数   — 网络错误          DNS失败/超时/连接中断等
     *   =============================================================================
     *
     * 设计决策 —— 为什么不用 getJson 而独立实现 HTTP 调用：
     *   轮询请求每 2 秒发送一次，如果复用 getJson，响应可能被其他并发请求的
     *   监听器误收（getJson 的信号路由问题）。独立创建 QNetworkReply 连接，
     *   确保回调直达正确的调用方，从根本上避免信号窜扰。
     *
     * @param qrcodeKey 从 generateQrCode 获取的 qrcode_key
     * @param callback  回调 (statusCode, errorMsg)
     *                  statusCode: B站扫码状态码（0/86101/86090/86038/负数）
     *                  errorMsg:   仅在 statusCode<0 时有值
     */
    void pollQrCode(const QString &qrcodeKey,
                    std::function<void(int statusCode, QString errorMsg)> callback);

    // ==================== 收藏夹相关 API ====================

    /**
     * @brief 获取指定用户创建的所有收藏夹列表
     *
     * API: GET https://api.bilibili.com/x/v3/fav/folder/created/list-all
     * 参数：up_mid = 用户 mid
     *
     * @param upMid    用户 mid（从 nav 接口获取）
     * @param callback 回调函数，参数为 (success, foldersArray, error)
     *                 foldersArray 中每个对象包含：id, title, media_count 等字段
     */
    void getFavoriteFolderList(qint64 upMid,
        std::function<void(bool success, QJsonArray folders, QString error)> callback);

    /**
     * @brief 获取收藏夹内容明细列表
     *
     * API: GET https://api.bilibili.com/x/v3/fav/resource/list
     * 参数：media_id, pn, ps, platform=web
     *
     * @param mediaId  收藏夹完整 id（mlid）
     * @param page     页码（从 1 开始）
     * @param pageSize 每页数量（1-20）
     * @param callback 回调函数，参数为 (success, info, mediasArray, hasMore, error)
     */
    void getFavoriteResourceList(qint64 mediaId, int page, int pageSize,
        std::function<void(bool success, QJsonObject info, QJsonArray medias, bool hasMore, QString error)> callback);

    // ==================== 音乐区 API ====================

    /**
     * @brief 获取热门音乐榜单（含音频预处理列表）
     *
     * API: GET https://www.bilibili.com/audio/music-service-c/web/menu/rank
     * 无需登录
     * 返回榜单列表，每项含 audios[] 数组（音频id/标题/时长）
     *
     * @param page     页码
     * @param pageSize 每页数量
     * @param callback 回调 (success, jsonArray, error)
     */
    void getMusicRank(int page, int pageSize,
        std::function<void(bool, QJsonArray, QString)> callback);

    // ==================== 音频/视频流 API ====================

    /**
     * @brief 获取视频分P信息（获取 cid）
     *
     * API: GET https://api.bilibili.com/x/web-interface/view?bvid={bvid}
     * 返回 data.cid 为第一分P的 cid
     *
     * @param bvid    视频 BV 号
     * @param callback 回调 (success, cid, error)
     */
    void getVideoCid(const QString &bvid,
        std::function<void(bool success, qint64 cid, QString error)> callback);

    /**
     * @brief 获取音频播放 URL（web 端 192K）
     *
     * API: GET https://www.bilibili.com/audio/music-service-c/web/url
     * 参数：sid = 音频 auid
     * 不需要登录即可获取 192K 音质
     *
     * @param audioId 音频 auid（如收藏夹内容中的 id，type=12）
     * @param callback 回调 (success, url, error)
     */
    void getAudioStreamUrl(qint64 audioId,
        std::function<void(bool success, QString url, QString error)> callback);

    /**
     * @brief 获取视频播放 URL
     *
     * API: GET https://api.bilibili.com/x/player/wbi/playurl
     * 需要 WBI 签名，已登录状态
     *
     * @param bvid    视频 BV 号
     * @param cid     视频分 P 的 cid
     * @param callback 回调 (success, url, error)
     */
    void getVideoPlayUrl(const QString &bvid, qint64 cid,
        std::function<void(bool success, QString url, QString error)> callback);

signals:
    /** @brief 所有 API 请求的通用错误信号 */
    void apiError(const QString &apiName, int code, const QString &message);

private:
    /**
     * @brief 发送 GET 请求并解析 JSON 响应
     * @param apiName  API 名称（用于错误报告）
     * @param url      请求 URL
     * @param callback 回调 (success, jsonObj, errorMsg)
     */
    void getJson(const QString &apiName, const QUrl &url,
                 std::function<void(bool, QJsonObject, QString)> callback);

    /**
     * @brief 从 nav 接口获取 WBI 签名密钥
     * @param callback 回调 (imgKey, subKey)
     *
     * WBI 密钥从 nav 接口的 wbi_img 字段获取（即使未登录也可以获取）
     * 缓存每日刷新
     */
    void getWbiKeys(std::function<void(QString imgKey, QString subKey)> callback);

    /**
     * @brief 对请求参数进行 WBI 签名
     * @param params  原始请求参数（键值对映射）
     * @param imgKey  WBI img_key
     * @param subKey  WBI sub_key
     * @return 添加了 w_rid 和 wts 后的完整参数映射
     */
    QMap<QString, QString> signWbi(const QMap<QString, QString> &params,
                                    const QString &imgKey, const QString &subKey);

    /** @brief HttpClient 实例（不拥有所有权，由 ApplicationContext 管理） */
    HttpClient *m_httpClient;

    /** @brief 缓存的 WBI img_key（每日更替） */
    QString m_wbiImgKey;

    /** @brief 缓存的 WBI sub_key（每日更替） */
    QString m_wbiSubKey;
};
