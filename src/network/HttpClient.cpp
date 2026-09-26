// ============================================================================
// HttpClient.cpp - 通用 HTTP 客户端实现
// 功能：实现 GET/POST 请求、超时控制、响应解析
// ============================================================================

#include "HttpClient.h"
#include "platform/android/LifecycleDiagnostics.h"

#include <QNetworkAccessManager>    // 核心网络引擎
#include <QNetworkRequest>          // HTTP 请求封装（URL、Header）
#include <QNetworkReply>            // HTTP 响应封装（状态码、数据）
#include <QTimer>                   // 超时定时器
#include <QUrl>                     // URL 解析

/**
 * @brief 构造函数
 * @param parent Qt 父对象
 *
 * 初始化步骤：
 * 1. 创建 QNetworkAccessManager（Qt 网络引擎核心）
 * 2. 设置 B站 API 必需的默认请求头
 */
HttpClient::HttpClient(QObject *parent)
    : QObject(parent)
    , m_manager(new QNetworkAccessManager(this))
{
    // ---- 设置 B站 API 请求的默认请求头 ----
    // B站对请求的 User-Agent 和 Referer 有校验，缺少或错误可能导致 403 拒绝访问

    // User-Agent: 模拟 Chrome 120 浏览器的完整标识字符串
    // B站会检查 UA 是否为常见的浏览器，过于简单的 UA 可能被风控拦截
    m_defaultHeaders[QStringLiteral("User-Agent")] = userAgent();

    // Referer: 来源页面地址
    // B站很多接口要求 Referer 为 bilibili.com 域名下的页面
    // 如果 Referer 缺失或错误，接口可能返回空数据或错误码
    m_defaultHeaders[QStringLiteral("Referer")] = QStringLiteral("https://www.bilibili.com");
}

/**
 * @brief 生成模拟 Chrome 浏览器的 User-Agent
 * @return 完整的 User-Agent 字符串
 *
 * 格式说明：
 * - Mozilla/5.0: 兼容性标记
 * - Windows NT 10.0: Windows 10 操作系统
 * - Win64; x64: 64位系统
 * - AppleWebKit/537.36: Chrome 使用的渲染引擎
 * - Chrome/120.0.0.0: Chrome 浏览器版本
 * - Safari/537.36: Safari 兼容性标记
 */
QString HttpClient::userAgent()
{
    return QStringLiteral("Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                          "AppleWebKit/537.36 (KHTML, like Gecko) "
                          "Chrome/120.0.0.0 Safari/537.36");
}

/**
 * @brief 获取内部的 QNetworkAccessManager
 * @return QNetworkAccessManager* 指针
 *
 * 主要用于外部设置 CookieJar，通过 setCookieJar() 将自定义的 CookieJar
 * 注入到 QNetworkAccessManager 中，使所有 HTTP 请求自动携带 Cookie。
 */
QNetworkAccessManager *HttpClient::networkManager() const
{
    return m_manager;
}

/**
 * @brief 设置一个默认请求头
 * @param name  请求头名称（如 "Authorization"）
 * @param value 请求头值
 *
 * 设置的 Header 会应用到所有后续发出的请求中。
 * 如果 name 已存在，会覆盖旧值。
 */
void HttpClient::setDefaultHeader(const QString &name, const QString &value)
{
    m_defaultHeaders[name] = value;
}

/**
 * @brief 移除一个默认请求头
 * @param name 要移除的请求头名称
 */
void HttpClient::removeDefaultHeader(const QString &name)
{
    m_defaultHeaders.remove(name);
}

/**
 * @brief 内部：发送 HTTP 请求并返回 QNetworkReply 指针
 * @param url         请求的目标 URL
 * @param verb        HTTP 方法（"GET" 或 "POST"）
 * @param body        POST 请求的请求体数据（GET 请求忽略此参数）
 * @param contentType POST 请求的 Content-Type（GET 请求忽略此参数）
 * @return QNetworkReply* 网络响应对象指针，失败返回 nullptr
 *
 * 此方法执行以下操作：
 * 1. 创建 QNetworkRequest 并填入目标 URL
 * 2. 设置基础请求头：Accept: application/json
 * 3. 遍历 m_defaultHeaders，将所有默认 Header 应用到请求
 * 4. 如果是 POST 请求，设置 Content-Type
 * 5. 调用相应方法发起网络请求
 */
QNetworkReply *HttpClient::sendRequest(const QUrl &url, const QByteArray &verb,
                                        const QByteArray &body,
                                        const QString &contentType)
{
    // ---- 1. 创建请求对象 ----
    QNetworkRequest request(url);

    // ---- 2. 设置基础请求头 ----
    // Accept: 告知服务器客户端期望接收 JSON 格式的响应
    request.setRawHeader("Accept", "application/json, text/plain, */*");

    // ---- 3. 遍历并应用所有默认请求头 ----
    for (auto it = m_defaultHeaders.constBegin(); it != m_defaultHeaders.constEnd(); ++it) {
        // toUtf8() 将 QString 转换为 QByteArray（setRawHeader 需要的格式）
        request.setRawHeader(it.key().toUtf8(), it.value().toUtf8());
    }

    // ---- 4. POST 请求设置 Content-Type ----
    if (!contentType.isEmpty()) {
        request.setHeader(QNetworkRequest::ContentTypeHeader, contentType);
    }

    // ---- 5. 根据 HTTP 方法发起请求 ----
    if (verb == "GET") {
        return m_manager->get(request);       // GET 请求：不携带请求体
    } else if (verb == "POST") {
        return m_manager->post(request, body); // POST 请求：携带请求体数据
    } else {
        return nullptr;  // 不支持的 HTTP 方法
    }
}

/**
 * @brief 发送 HTTP GET 请求
 * @param url       目标 URL
 * @param timeoutMs 超时时间（毫秒，默认 15000ms = 15 秒）
 */
void HttpClient::get(const QUrl &url, int timeoutMs)
{
    QNetworkReply *reply = sendRequest(url, "GET");
    if (reply)
        handleReply(reply, timeoutMs);
}

/**
 * @brief 发送 HTTP POST 请求
 * @param url         目标 URL
 * @param data        请求体数据
 * @param contentType 请求体类型（默认 application/json）
 * @param timeoutMs   超时时间（默认 15 秒）
 */
void HttpClient::post(const QUrl &url, const QByteArray &data,
                       const QString &contentType, int timeoutMs)
{
    QNetworkReply *reply = sendRequest(url, "POST", data, contentType);
    if (reply)
        handleReply(reply, timeoutMs);
}

/**
 * @brief 处理网络响应（核心逻辑）
 * @param reply     QNetworkReply 指针（发起请求时返回的原始指针）
 * @param timeoutMs 超时时间（毫秒）
 *
 * 使用 QTimer 实现超时控制：
 * 1. 创建一个 singleShot 定时器，挂在 reply 对象上（reply 销毁时自动销毁）
 * 2. 定时器超时时，如果请求尚未完成，调用 reply->abort() 终止请求
 * 3. 请求正常完成时，停止定时器，构造 Response，发出信号
 *
 * Qt 网络请求的典型模式：
 * - 异步：请求发出后不阻塞，通过信号/槽机制在请求完成时接收通知
 * - QNetworkReply 会在请求完成后发射 finished() 信号
 */
void HttpClient::handleReply(QNetworkReply *reply, int timeoutMs)
{
    BL_LIFECYCLE_REQUEST(reply, "HTTP_CLIENT");
    // ---- 1. 创建超时定时器 ----
    // new QTimer(reply): 将定时器的父对象设为 reply
    // 这样 reply 被 deleteLater 时，timer 也会自动释放
    QTimer *timer = new QTimer(reply);
    timer->setSingleShot(true);   // 单次触发，不是周期性定时器
    timer->setInterval(timeoutMs); // 设置超时间隔

    // ---- 2. 连接定时器的超时信号 ----
    // 如果超时，终止请求并清理定时器
    QObject::connect(timer, &QTimer::timeout, reply, [reply, timer]() {
        if (!reply->isFinished()) {
            reply->abort();            // 终止网络请求
        }
        timer->deleteLater();          // 在事件循环的下一次迭代中销毁定时器
    });

    // ---- 3. 连接请求完成信号 ----
    QObject::connect(reply, &QNetworkReply::finished, this, [this, reply, timer]() {
        // 请求完成，先停止超时定时器（不再需要超时检测）
        timer->stop();
        timer->deleteLater();   // 定时器不再需要，安排销毁

        // 构造响应结构体
        Response response;
        // 获取 HTTP 状态码（例如：200=成功，403=禁止，404=未找到，500=服务器错误）
        response.statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        // 读取服务器返回的完整响应体数据
        response.body = reply->readAll();
        // 判断网络层面是否成功
        // 注意：NoError 仅表示没有网络层面的错误（如连接断开、DNS 解析失败等）
        // 不代表 HTTP 状态码是 200！业务层面的成功需要自行判断 statusCode
        response.success = (reply->error() == QNetworkReply::NoError);
        // 获取错误描述（网络层面）
        response.errorString = reply->errorString();

        // 清理 QNetworkReply 对象
        // deleteLater() 不会立即销毁，而是等当前事件循环处理完毕后再销毁
        // 这是 Qt 的惯用做法，避免在信号处理中直接 delete 对象
        reply->deleteLater();

        // 通过信号将结果发送给所有连接的槽函数
        emit requestFinished(response);
    });

    // ---- 4. 启动超时定时器 ----
    timer->start();
}

// ============================================================================
// Response 结构体的辅助方法
// ============================================================================

/**
 * @brief 将 HTTP 响应体解析为 QJsonObject
 * @return JSON 对象，解析失败时返回空对象
 *
 * 使用场景：
 * 多数 B站 API 返回 JSON 格式数据，可直接用此方法解析
 *
 * 注意：
 * - 如果响应体不是合法 JSON，返回空对象
 * - 如果响应体是 JSON 数组（而非对象），返回空对象
 * - 建议先检查 isHttpOk() 再调用此方法
 */
QJsonObject HttpClient::Response::json() const
{
    QJsonDocument doc = QJsonDocument::fromJson(body);
    if (doc.isObject())
        return doc.object();
    return QJsonObject();
}

/**
 * @brief 判断 HTTP 状态码是否表示成功（2xx）
 * @return true 如果状态码在 200-299 范围内
 *
 * 注意：2xx 仅表示 HTTP 协议层面的成功
 * B站 API 的业务成功需检查返回 JSON 中的 code 字段（通常 code=0 表示成功）
 * 例如：{"code": 0, "data": {...}, "message": "0"}
 */
bool HttpClient::Response::isHttpOk() const
{
    return statusCode >= 200 && statusCode < 300;
}
