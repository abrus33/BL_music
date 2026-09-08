// ============================================================================
// 入口文件 - main.cpp
// 功能：程序启动入口，初始化 QML 引擎并注入 C++ 服务对象到 QML 环境
// ============================================================================

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickStyle>              // QML 风格设置（支持 Button 自定义背景）

#include "app/ApplicationContext.h"

#ifdef BL_ANDROID_LIFECYCLE_DIAGNOSTICS
#include "platform/android/LifecycleDiagnostics.h"
#endif

#ifdef BL_ANDROID_TLS_DIAGNOSTICS
#include "platform/android/TlsDiagnostics.h"
#include <QTimer>
#endif

/**
 * @brief 程序入口函数
 * @param argc 命令行参数个数
 * @param argv 命令行参数数组
 * @return     程序退出码
 *
 * 启动流程：
 * 1. 创建 QGuiApplication（无窗口小部件的 Qt 应用）
 * 2. 设置应用元信息（名称、组织、版本）——用于 QSettings 的存储路径
 * 3. 设置 QML 控件风格为 Fusion（支持自定义 Button 背景/文字样式）
 * 4. 创建 ApplicationContext（全局服务容器，持有 HttpClient / AppSettings / CookieJar）
 * 5. 调用 initialize() 初始化各服务（加载 Cookie、关联网络管理器）
 * 6. 将 ApplicationContext 注册为 QML 上下文属性 "applicationContext"
 *    -> 从此 QML 中可通过 applicationContext.qtVersion 等方式访问 C++ 对象
 * 7. 加载 QML 模块 "cursor_music" 的 "Main" 组件
 * 8. 进入事件循环（app.exec()）
 */
int main(int argc, char *argv[])
{
    // ---- 1. 创建 Qt 应用实例 ----
    QGuiApplication app(argc, argv);

    // ---- 2. 设置应用元信息 ----
    QGuiApplication::setApplicationName(QStringLiteral("cursor_music"));
    QGuiApplication::setOrganizationName(QStringLiteral("cursor_music"));
    QGuiApplication::setApplicationVersion(QStringLiteral("0.1"));

    // ---- 3. 设置 QML 控件风格 ----
    // 使用 Fusion 风格（非原生风格），支持自定义 Button 的 background/contentItem
    QQuickStyle::setStyle(QStringLiteral("Fusion"));

    // ---- 4. 创建 QML 引擎 和 全局服务上下文 ----
    QQmlApplicationEngine engine;
    ApplicationContext applicationContext;

#ifdef BL_ANDROID_LIFECYCLE_DIAGNOSTICS
    // 在事件循环开始前挂载只读观测器，覆盖初始化后异步加载及前后台变化；不控制播放。
    LifecycleDiagnostics::start(app, *applicationContext.playerController());
#endif

    // ---- 5. 初始化各服务 ----
    applicationContext.initialize();

    // ---- 6. 将 C++ 对象暴露给 QML 层 ----
    engine.setInitialProperties({
        {QStringLiteral("appContext"), QVariant::fromValue(&applicationContext)}
    });

    // ---- 7. 连接引擎创建失败信号 ----
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    // ---- 8. 加载 QML 模块 ----
    engine.loadFromModule("cursor_music", "Main");

#ifdef BL_ANDROID_TLS_DIAGNOSTICS
    // 仅诊断 APK 在 QML 创建成功后安排一次异步 HTTPS 检查。
    // app 负责回调和网络对象的生命周期，退出时会取消尚未执行的回调。
    if (!engine.rootObjects().isEmpty()) {
        QTimer::singleShot(0, &app, [&app]() { AndroidTlsDiagnostics::start(&app); });
    }
#endif

    // ---- 9. 进入 Qt 事件循环 ----
    return app.exec();
}
