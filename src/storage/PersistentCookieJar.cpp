#include "PersistentCookieJar.h"

#include <QFile>
#include <QDataStream>
#include <QStandardPaths>
#include <QDir>
#include <QUrl>

PersistentCookieJar::PersistentCookieJar(QObject *parent)
    : QNetworkCookieJar(parent)
{
}

void PersistentCookieJar::load()
{
    QFile file(cookieFilePath());
    if (!file.open(QIODevice::ReadOnly))
        return;

    QDataStream stream(&file);
    QList<QByteArray> rawCookies;
    stream >> rawCookies;
    file.close();

    QList<QNetworkCookie> cookies;
    for (const auto &raw : rawCookies) {
        auto parsed = QNetworkCookie::parseCookies(raw);
        for (const auto &cookie : parsed) {
            // parseCookies may return multiple cookies from a single raw form
            // and each needs proper domain/path set
            cookies.append(cookie);
        }
    }

    if (!cookies.isEmpty()) {
        setAllCookies(cookies);
    }
}

void PersistentCookieJar::save()
{
    QFile file(cookieFilePath());
    if (!file.open(QIODevice::WriteOnly))
        return;

    QList<QByteArray> rawCookies;
    const auto cookies = allCookies();
    for (const auto &cookie : cookies) {
        rawCookies.append(cookie.toRawForm());
    }

    QDataStream stream(&file);
    stream << rawCookies;
    file.close();
}

QNetworkCookie PersistentCookieJar::getCookie(const QString &name) const
{
    const auto cookies = allCookies();
    for (const auto &cookie : cookies) {
        if (cookie.name() == name)
            return cookie;
    }
    return QNetworkCookie();
}

void PersistentCookieJar::setCookieString(const QString &cookieString)
{
    // Parse a semi-colon separated cookie string (e.g. from browser export)
    const auto parsedCookies = QNetworkCookie::parseCookies(cookieString.toUtf8());
    if (!parsedCookies.isEmpty()) {
        for (const auto &cookie : parsedCookies) {
            insertCookie(cookie);
        }
        save();
    }
}

QList<QNetworkCookie> PersistentCookieJar::cookiesForUrl(const QUrl &url) const
{
    return QNetworkCookieJar::cookiesForUrl(url);
}

bool PersistentCookieJar::setCookiesFromUrl(const QList<QNetworkCookie> &cookieList, const QUrl &url)
{
    bool result = QNetworkCookieJar::setCookiesFromUrl(cookieList, url);
    if (result)
        save();
    return result;
}

bool PersistentCookieJar::isLoggedIn() const
{
    return !getCookie(QStringLiteral("SESSDATA")).value().isEmpty();
}

QString PersistentCookieJar::cookieFilePath() const
{
    QString path = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(path);
    return path + QStringLiteral("/cookies.dat");
}
