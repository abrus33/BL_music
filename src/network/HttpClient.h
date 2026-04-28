// ============================================================================
// HttpClient.h - 通用 HTTP 客户端
// 功能：封装 QNetworkAccessManager，提供统一的 GET/POST 请求接口
//       支持超时控制、自定义请求头、JSON 响应解析
// 设计目的：为后续 BilibiliApiClient 等模块提供底层网络通信能力
// ============================================================================

#pragma once

#include <QObject>
#include <QUrl>
#include <QByteArray>
#include <QString>
#include <QJsonObject>
#include <QJsonDocument>
#include <QMap>

// 前向声明：这些 Qt 网络类在 .h 中仅用于指针/引用声明
// 完整定义在 .cpp 中通过 #include 引入，以减少头文件依赖
class QNetworkAccessManager;    // Qt 网络访问管理器（核心网络引擎）
class QNetworkReply;            // Qt 网络响应（接收服务器返回的数据）
class QTimer;                   // Qt 定时器（用于请求超时控制）

/**
 * @brief 通用 HTTP 客户端
 *
 * 典型用法：
 * @code
 * HttpClient client;
 *
 * // 发送 GET 请求
 * client.get(QUrl("https://api.bilibili.com/x/web-interface/nav"));
 *
 * // 连接信号获取结果
 * QObject::connect(&client, &HttpClient::requestFinished,
 *     [](const HttpClient::Response &resp) {
 *         if (resp.success) {
 *             QJsonObject json = resp.json();
 *             // 处理 JSON 响应...
 *         }
 *     });
 * @endcode
 *
 * B站 API 特殊需求：
 * - 需要特定的 User-Agent（模拟 Chrome 浏览器）
 * - 需要设置 Referer 为 https://www.bilibili.com
 * - 需要携带 Cookie（通过 PersistentCookieJar 自动处理）
 *
 * 本类自动完成上述 Header 设置，开发者只需关心 URL 和响应解析。
 */
class HttpClient : public QObject
{
    Q_OBJECT

public:
    /**
     * @brief HTTP 响应数据结构体
     *
     * 包含服务器响应的所有关键信息：
     * - statusCode: HTTP 状态码（200=成功，403=禁止访问，404=资源不存在 等）
     * - body:       原始响应体数据（字节数组）
     * - success:    网络层是否成功（true = 没有网络错误，不代表业务逻辑成功）
     *               B站 API 的业务成功需要解析 body 中的 json.code
     * - errorString:网络错误描述（无错误时为空字符串）
     */
    struct Response {
        int statusCode = 0;         // HTTP 状态码，例如 200、403、500
        QByteArray body;            // 原始响应体（可能是 JSON / HTML / 二进制）
        bool success = false;       // 网络请求是否成功（不等于业务成功）
        QString errorString;        // 错误信息（网络层面）

        /** @brief 将响应体解析为 JSON 对象 */
        QJsonObject json() const;

        /** @brief 判断 HTTP 状态码是否为 2xx（200-299） */
        bool isHttpOk() const;
    };

    /**
     * @brief 构造函数
     * @param parent Qt 父对象
     *
     * 内部创建 QNetworkAccessManager 实例
     * 并自动设置 B站 API 必需的默认请求头：
     * - User-Agent: 模拟 Chrome 120 浏览器
     * - Referer: https://www.bilibili.com
     */
    explicit HttpClient(QObject *parent = nullptr);

    // ==================== 公开 HTTP 方法 ====================

    /**
     * @brief 发送 HTTP GET 请求
     * @param url       请求的目标 URL（完整地址，含协议）
     * @param timeoutMs 超时时间，单位毫秒，默认 15 秒
     *
     * 请求完成后通过 requestFinished 信号返回结果。
     * 示例：
     * @code
     * client.get(QUrl("https://api.bilibili.com/x/web-interface/nav"));
     * @endcode
     */
    void get(const QUrl &url, int timeoutMs = 15000);

    /**
     * @brief 发送 HTTP POST 请求
     * @param url         请求的目标 URL
     * @param data        请求体数据（通常为 JSON 字符串或表单数据）
     * @param contentType 请求体的 Content-Type，默认 application/json
     * @param timeoutMs   超时时间，默认 15 秒
     *
     * 示例：
     * @code
     * QByteArray jsonData = "{\"action\":\"like\"}";
     * client.post(url, jsonData);
     * @endcode
     */
    void post(const QUrl &url, const QByteArray &data,
              const QString &contentType = QStringLiteral("application/json"),
              int timeoutMs = 15000);

    /**
     * @brief 设置默认请求头
     * @param name  请求头名称，例如 "User-Agent"
     * @param value 请求头值
     *
     * 设置的默认请求头会应用于所有后续请求。
     * 常用于设置身份验证 Token、自定义标识等。
     */
    void setDefaultHeader(const QString &name, const QString &value);

    /**
     * @brief 移除之前设置的默认请求头
     * @param name 要移除的请求头名称
     */
    void removeDefaultHeader(const QString &name);

    /**
     * @brief 获取内部的 QNetworkAccessManager 指针
     * @return QNetworkAccessManager* 指针
     *
     * 用于外部设置 CookieJar 等底层配置。
     * 在 ApplicationContext::initialize() 中调用此方法获取管理器，
     * 然后将持久化 CookieJar 设置到该管理器。
     */
    QNetworkAccessManager *networkManager() const;

signals:
    /**
     * @brief 请求完成信号
     * @param response 包含状态码、响应体、错误信息的 Response 结构体
     *
     * 无论是成功还是失败，请求完成后都会触发此信号。
     * 通过检查 response.success 和 response.statusCode 判断实际结果。
     */
    void requestFinished(const HttpClient::Response &response);

private:
    // ==================== 私有方法 ====================

    /**
     * @brief 内部发送请求方法
     * @param url         请求 URL
     * @param verb        HTTP 方法名（"GET" 或 "POST"）
     * @param body        请求体数据（仅 POST 请求需要）
     * @param contentType 请求体类型（仅 POST 请求需要）
     * @return QNetworkReply* 网络响应对象的指针
     *
     * 此方法负责：
     * 1. 创建 QNetworkRequest 对象
     * 2. 设置默认请求头（UA、Referer 等）
     * 3. 设置 Accept 头为 JSON 格式
     * 4. 根据 verb 参数选择调用 get() 或 post()
     */
    QNetworkReply *sendRequest(const QUrl &url, const QByteArray &verb,
                               const QByteArray &body = QByteArray(),
                               const QString &contentType = QString());

    /**
     * @brief 处理网络响应
     * @param reply     QNetworkReply 对象（发送请求时返回的指针）
     * @param timeoutMs 超时时间（毫秒）
     *
     * 负责：
     * 1. 创建 QTimer 实现请求超时控制
     * 2. 连接 reply->finished 信号，构造 Response 结构体
     * 3. 通过 requestFinished 信号将结果发出
     * 4. 清理 reply 和 timer 对象（deleteLater）
     */
    void handleReply(QNetworkReply *reply, int timeoutMs);

    /** @brief 生成模拟 Chrome 浏览器的 User-Agent 字符串 */
    static QString userAgent();

    // ==================== 成员变量 ====================

    /** Qt 网络访问管理器，负责底层的 HTTP 连接管理 */
    QNetworkAccessManager *m_manager;

    /**
     * 默认请求头映射表
     * key = 请求头名称（如 "User-Agent"）
     * val = 请求头值（如 "Mozilla/5.0 ..."）
     * 每次请求时都会将此表中的所有 Header 写入 QNetworkRequest
     */
    QMap<QString, QString> m_defaultHeaders;
};
