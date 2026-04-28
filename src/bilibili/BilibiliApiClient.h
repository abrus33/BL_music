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

    // ==================== 音频/视频流 API ====================

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
