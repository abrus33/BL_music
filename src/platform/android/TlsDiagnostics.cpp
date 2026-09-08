// Android TLS/HTTPS 的一次性诊断，属于平台基础设施验证层。
// main.cpp 仅在 BL_ANDROID_TLS_DIAGNOSTICS 开启时调用；Qt 事件循环执行后续信号回调。
// 调用链：独立 QNetworkAccessManager → QSslSocket → Qt OpenSSL backend → libssl/libcrypto。
// Qt backend 是统一 TLS 接口的具体实现，OpenSSL 承担实际握手、证书验证与加密。
// 不复用业务 CookieJar，也不读取/输出响应正文、Cookie 或认证信息。
#include "TlsDiagnostics.h"

#include <QDebug>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QSslError>
#include <QSslSocket>
#include <QTimer>
#include <memory>

namespace AndroidTlsDiagnostics {

const char *outcome(const HttpsResult &result)
{
    if (!result.tlsAvailable)
        return "tls-unavailable";
    if (result.certificateError)
        return "certificate-error";
    if (result.timedOut || result.networkError == QNetworkReply::TimeoutError)
        return "timeout";
    if (result.networkError == QNetworkReply::SslHandshakeFailedError)
        return "tls-handshake-error";
    if (result.networkError == QNetworkReply::HostNotFoundError)
        return "dns-error";
    // HTTP 4xx/5xx 在 Qt 中也会设置 networkError，先识别服务端已返回的 HTTP 错误。
    if (result.httpStatus != 0 && (result.httpStatus < 200 || result.httpStatus >= 300))
        return "http-status-error";
    if (result.networkError != QNetworkReply::NoError)
        return "network-error";
    if (!result.encrypted)
        return "unencrypted-response";
    if (result.httpStatus == 0)
        return "http-status-error";
    return "ok";
}

void start(QObject *lifetimeOwner)
{
    // QSslSocket 是 Qt TLS socket 接口；这些静态查询针对当前进程的实际后端和运行库。
    // 编译版本表示 Qt 构建时使用的 OpenSSL，运行版本表示手机此刻成功加载的库。
    const bool tlsAvailable = QSslSocket::supportsSsl();
    qInfo() << "[AndroidTlsProbe] supportsSsl=" << tlsAvailable
            << "availableBackends=" << QSslSocket::availableBackends()
            << "activeBackend=" << QSslSocket::activeBackend()
            << "buildVersion=" << QSslSocket::sslLibraryBuildVersionString()
            << "runtimeVersion=" << QSslSocket::sslLibraryVersionString();
    if (!tlsAvailable) {
        qWarning() << "[AndroidTlsProbe] result=tls-unavailable; HTTPS request not started";
        return;
    }

    // 独立 manager 确保这是一次新的 TLS 连接，不共享业务 Cookie、缓存或已有连接。
    auto *manager = new QNetworkAccessManager(lifetimeOwner);
    QNetworkRequest request(QUrl(QStringLiteral("https://www.qt.io/robots.txt")));
    // 只验证这一个 HTTPS URL；重定向作为 HTTP 结果报告，避免测试转到另一站点。
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::ManualRedirectPolicy);
    request.setAttribute(QNetworkRequest::CacheLoadControlAttribute, QNetworkRequest::AlwaysNetwork);
    QNetworkReply *reply = manager->get(request);
    reply->setReadBufferSize(64 * 1024);

    // 多个异步信号共享本次请求的证据；连接随 reply 销毁而释放，不进入全局业务状态。
    auto result = std::make_shared<HttpsResult>();
    result->tlsAvailable = tlsAvailable;
    auto receivedBytes = std::make_shared<qint64>(0);
    auto *deadline = new QTimer(reply);
    deadline->setSingleShot(true);
    QObject::connect(deadline, &QTimer::timeout, reply, [reply, result]() {
        result->timedOut = true;
        reply->abort();
    });
    QObject::connect(reply, &QNetworkReply::encrypted, reply, [result]() {
        result->encrypted = true;
        qInfo() << "[AndroidTlsProbe] encrypted=true";
    });
    QObject::connect(reply, &QNetworkReply::sslErrors, reply, [result](const QList<QSslError> &errors) {
        result->certificateError |= !errors.isEmpty();
        for (const auto &error : errors)
            qWarning() << "[AndroidTlsProbe] certificateError=" << error.error() << error.errorString();
        // 仅记录证据，保持默认的证书与主机名校验，不忽略错误。
    });
    QObject::connect(reply, &QIODevice::readyRead, reply, [reply, receivedBytes]() {
        *receivedBytes += reply->readAll().size();
    });
    QObject::connect(reply, &QNetworkReply::finished, reply,
                     [manager, reply, deadline, result, receivedBytes]() {
        deadline->stop();
        *receivedBytes += reply->readAll().size();
        result->httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        result->networkError = reply->error();
        qInfo() << "[AndroidTlsProbe] result=" << outcome(*result)
                << "httpStatus=" << result->httpStatus << "networkError=" << result->networkError
                << "encrypted=" << result->encrypted << "bytes=" << *receivedBytes
                << "error=" << reply->errorString();
        // finished 信号仍在调用栈中，延迟销毁 manager，同时释放其子对象 reply 和 deadline。
        manager->deleteLater();
    });
    // 绝对截止时间覆盖 DNS、连接、握手和接收阶段；超时会单独分类，不误报为证书错误。
    deadline->start(30000);
    qInfo() << "[AndroidTlsProbe] request=https://www.qt.io/robots.txt deadlineMs=30000";
}

} // namespace AndroidTlsDiagnostics
