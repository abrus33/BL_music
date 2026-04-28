#pragma once

#include <QObject>
#include <QString>

class HttpClient;
class AppSettings;
class PersistentCookieJar;

class ApplicationContext : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString appName READ appName CONSTANT)
    Q_PROPERTY(QString qtVersion READ qtVersion CONSTANT)

public:
    explicit ApplicationContext(QObject *parent = nullptr);

    QString appName() const;
    QString qtVersion() const;

    AppSettings *settings() const;
    PersistentCookieJar *cookieJar() const;
    HttpClient *httpClient() const;

    // Initialize services (called after construction)
    void initialize();

private:
    AppSettings *m_settings = nullptr;
    PersistentCookieJar *m_cookieJar = nullptr;
    HttpClient *m_httpClient = nullptr;
};
