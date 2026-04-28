#pragma once

#include <QObject>
#include <QVariant>
#include <QSettings>
#include <QByteArray>

class AppSettings : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString appDataPath READ appDataPath CONSTANT)

public:
    explicit AppSettings(QObject *parent = nullptr);

    QVariant value(const QString &key, const QVariant &defaultValue = QVariant()) const;
    void setValue(const QString &key, const QVariant &value);

    QByteArray windowGeometry() const;
    void setWindowGeometry(const QByteArray &geometry);

    QString appDataPath() const;

private:
    QSettings m_settings;
};
