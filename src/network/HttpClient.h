#pragma once

#include <QObject>
#include <QUrl>
#include <QByteArray>
#include <QString>
#include <QJsonObject>
#include <QJsonDocument>
#include <QMap>

class QNetworkAccessManager;
class QNetworkReply;
class QTimer;

class HttpClient : public QObject
{
    Q_OBJECT

public:
    struct Response {
        int statusCode = 0;
        QByteArray body;
        bool success = false;
        QString errorString;

        QJsonObject json() const;
        bool isHttpOk() const;
    };

    explicit HttpClient(QObject *parent = nullptr);

    void get(const QUrl &url, int timeoutMs = 15000);
    void post(const QUrl &url, const QByteArray &data,
              const QString &contentType = QStringLiteral("application/json"),
              int timeoutMs = 15000);

    void setDefaultHeader(const QString &name, const QString &value);
    void removeDefaultHeader(const QString &name);

    QNetworkAccessManager *networkManager() const;

signals:
    void requestFinished(const HttpClient::Response &response);

private:
    QNetworkAccessManager *m_manager;
    QMap<QString, QString> m_defaultHeaders;

    QNetworkReply *sendRequest(const QUrl &url, const QByteArray &verb,
                               const QByteArray &body = QByteArray(),
                               const QString &contentType = QString());
    void handleReply(QNetworkReply *reply, int timeoutMs);

    static QString userAgent();
};
