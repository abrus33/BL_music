#include "AppSettings.h"

#include <QStandardPaths>
#include <QDir>

AppSettings::AppSettings(QObject *parent)
    : QObject(parent)
    , m_settings(QSettings::IniFormat, QSettings::UserScope,
                 QStringLiteral("cursor_music"), QStringLiteral("cursor_music"))
{
}

QVariant AppSettings::value(const QString &key, const QVariant &defaultValue) const
{
    return m_settings.value(key, defaultValue);
}

void AppSettings::setValue(const QString &key, const QVariant &value)
{
    m_settings.setValue(key, value);
}

QByteArray AppSettings::windowGeometry() const
{
    return m_settings.value(QStringLiteral("window/geometry")).toByteArray();
}

void AppSettings::setWindowGeometry(const QByteArray &geometry)
{
    m_settings.setValue(QStringLiteral("window/geometry"), geometry);
}

QString AppSettings::appDataPath() const
{
    QString path = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(path);
    return path;
}
