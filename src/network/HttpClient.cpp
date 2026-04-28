#include "HttpClient.h"

#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QTimer>
#include <QUrl>

HttpClient::HttpClient(QObject *parent)
    : QObject(parent)
    , m_manager(new QNetworkAccessManager(this))
{
    // Set default headers commonly required by Bilibili API
    m_defaultHeaders[QStringLiteral("User-Agent")] = userAgent();
    m_defaultHeaders[QStringLiteral("Referer")] = QStringLiteral("https://www.bilibili.com");
}

QString HttpClient::userAgent()
{
    return QStringLiteral("Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                          "AppleWebKit/537.36 (KHTML, like Gecko) "
                          "Chrome/120.0.0.0 Safari/537.36");
}

QNetworkAccessManager *HttpClient::networkManager() const
{
    return m_manager;
}

void HttpClient::setDefaultHeader(const QString &name, const QString &value)
{
    m_defaultHeaders[name] = value;
}

void HttpClient::removeDefaultHeader(const QString &name)
{
    m_defaultHeaders.remove(name);
}

QNetworkReply *HttpClient::sendRequest(const QUrl &url, const QByteArray &verb,
                                        const QByteArray &body,
                                        const QString &contentType)
{
    QNetworkRequest request(url);
    request.setRawHeader("Accept", "application/json, text/plain, */*");

    // Apply default headers
    for (auto it = m_defaultHeaders.constBegin(); it != m_defaultHeaders.constEnd(); ++it) {
        request.setRawHeader(it.key().toUtf8(), it.value().toUtf8());
    }

    if (!contentType.isEmpty()) {
        request.setHeader(QNetworkRequest::ContentTypeHeader, contentType);
    }

    if (verb == "GET") {
        return m_manager->get(request);
    } else if (verb == "POST") {
        return m_manager->post(request, body);
    } else {
        return nullptr;
    }
}

void HttpClient::get(const QUrl &url, int timeoutMs)
{
    QNetworkReply *reply = sendRequest(url, "GET");
    if (reply)
        handleReply(reply, timeoutMs);
}

void HttpClient::post(const QUrl &url, const QByteArray &data,
                       const QString &contentType, int timeoutMs)
{
    QNetworkReply *reply = sendRequest(url, "POST", data, contentType);
    if (reply)
        handleReply(reply, timeoutMs);
}

void HttpClient::handleReply(QNetworkReply *reply, int timeoutMs)
{
    // Timeout handling
    QTimer *timer = new QTimer(reply);
    timer->setSingleShot(true);
    timer->setInterval(timeoutMs);

    QObject::connect(timer, &QTimer::timeout, reply, [reply, timer]() {
        if (!reply->isFinished()) {
            reply->abort();
        }
        timer->deleteLater();
    });

    QObject::connect(reply, &QNetworkReply::finished, this, [this, reply, timer]() {
        timer->stop();
        timer->deleteLater();

        Response response;
        response.statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        response.body = reply->readAll();
        response.success = (reply->error() == QNetworkReply::NoError);
        response.errorString = reply->errorString();

        reply->deleteLater();
        emit requestFinished(response);
    });

    timer->start();
}

// --- Response helper methods ---

QJsonObject HttpClient::Response::json() const
{
    QJsonDocument doc = QJsonDocument::fromJson(body);
    if (doc.isObject())
        return doc.object();
    return QJsonObject();
}

bool HttpClient::Response::isHttpOk() const
{
    return statusCode >= 200 && statusCode < 300;
}
