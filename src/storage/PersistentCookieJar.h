#pragma once

#include <QNetworkCookieJar>
#include <QNetworkCookie>
#include <QString>
#include <QList>
#include <QByteArray>

class PersistentCookieJar : public QNetworkCookieJar
{
    Q_OBJECT

public:
    explicit PersistentCookieJar(QObject *parent = nullptr);

    void load();
    void save();

    QNetworkCookie getCookie(const QString &name) const;
    void setCookieString(const QString &cookieString);

    // Override to auto-save
    QList<QNetworkCookie> cookiesForUrl(const QUrl &url) const override;
    bool setCookiesFromUrl(const QList<QNetworkCookie> &cookieList, const QUrl &url) override;

    bool isLoggedIn() const;

private:
    QString cookieFilePath() const;
};
