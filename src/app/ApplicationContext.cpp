#include "ApplicationContext.h"

#include <QtGlobal>
#include <QUrl>
#include <QStandardPaths>
#include <QDir>
#include <QNetworkAccessManager>

#include "network/HttpClient.h"
#include "storage/AppSettings.h"
#include "storage/PersistentCookieJar.h"

ApplicationContext::ApplicationContext(QObject *parent)
    : QObject(parent)
    , m_settings(new AppSettings(this))
    , m_cookieJar(new PersistentCookieJar(this))
    , m_httpClient(new HttpClient(this))
{
}

QString ApplicationContext::appName() const
{
    return QStringLiteral("cursor_music");
}

QString ApplicationContext::qtVersion() const
{
    return QString::fromLatin1(qVersion());
}

AppSettings *ApplicationContext::settings() const
{
    return m_settings;
}

PersistentCookieJar *ApplicationContext::cookieJar() const
{
    return m_cookieJar;
}

HttpClient *ApplicationContext::httpClient() const
{
    return m_httpClient;
}

void ApplicationContext::initialize()
{
    // Load persisted cookies
    m_cookieJar->load();

    // Attach cookie jar to the network manager
    // QNetworkAccessManager does NOT take ownership in Qt6
    m_httpClient->networkManager()->setCookieJar(m_cookieJar);
}
