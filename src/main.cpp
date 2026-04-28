#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#include "app/ApplicationContext.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    QGuiApplication::setApplicationName(QStringLiteral("cursor_music"));
    QGuiApplication::setOrganizationName(QStringLiteral("cursor_music"));
    QGuiApplication::setApplicationVersion(QStringLiteral("0.1"));

    QQmlApplicationEngine engine;
    ApplicationContext applicationContext;

    applicationContext.initialize();

    engine.rootContext()->setContextProperty("applicationContext", &applicationContext);

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    engine.loadFromModule("cursor_music", "Main");

    return app.exec();
}
