#include <QtTest>

#include "storage/AppSettings.h"

class AppSettingsTest : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase();
    void reduceMotionIsPersistedAndNotified();
};

void AppSettingsTest::initTestCase()
{
    QStandardPaths::setTestModeEnabled(true);
}

void AppSettingsTest::reduceMotionIsPersistedAndNotified()
{
    AppSettings settings;
    QSignalSpy spy(&settings, &AppSettings::reduceMotionChanged);
    const bool target = !settings.reduceMotion();

    settings.setReduceMotion(target);

    QCOMPARE(settings.reduceMotion(), target);
    QCOMPARE(spy.count(), 1);

    AppSettings reloaded;
    QCOMPARE(reloaded.reduceMotion(), target);
}

QTEST_APPLESS_MAIN(AppSettingsTest)

#include "tst_appsettings.moc"
