// ============================================================================
// 入口文件 - main.cpp
// 功能：程序启动入口，初始化 QML 引擎并注入 C++ 服务对象到 QML 环境
// ============================================================================

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#include "app/ApplicationContext.h"

/**
 * @brief 程序入口函数
 * @param argc 命令行参数个数
 * @param argv 命令行参数数组
 * @return     程序退出码
 *
 * 启动流程：
 * 1. 创建 QGuiApplication（无窗口小部件的 Qt 应用）
 * 2. 设置应用元信息（名称、组织、版本）——用于 QSettings 的存储路径
 * 3. 创建 ApplicationContext（全局服务容器，持有 HttpClient / AppSettings / CookieJar）
 * 4. 调用 initialize() 初始化各服务（加载 Cookie、关联网络管理器）
 * 5. 将 ApplicationContext 注册为 QML 上下文属性 "applicationContext"
 *    -> 从此 QML 中可通过 applicationContext.qtVersion 等方式访问 C++ 对象
 * 6. 加载 QML 模块 "cursor_music" 的 "Main" 组件
 * 7. 进入事件循环（app.exec()）
 */
int main(int argc, char *argv[])
{
    // ---- 1. 创建 Qt 应用实例（纯 GUI 应用，无需 QApplication 的 Widget 支持） ----
    QGuiApplication app(argc, argv);

    // ---- 2. 设置应用元信息 ----
    // 注意：必须在创建 QSettings 之前设置，因为 QSettings 依赖于组织名和应用名
    QGuiApplication::setApplicationName(QStringLiteral("cursor_music"));
    QGuiApplication::setOrganizationName(QStringLiteral("cursor_music"));
    QGuiApplication::setApplicationVersion(QStringLiteral("0.1"));

    // ---- 3. 创建 QML 引擎 和 全局服务上下文 ----
    QQmlApplicationEngine engine;                   // QML 引擎：负责解析、加载和运行 QML 文件
    ApplicationContext applicationContext;           // 全局服务容器：持有所有 C++ 业务服务实例

    // ---- 4. 初始化各服务（必须在引擎加载 QML 之前完成） ----
    // initialize() 内部会：
    //   - 从磁盘加载持久化的 Cookie（PersistentCookieJar::load()）
    //   - 将 CookieJar 挂载到 HttpClient 的 QNetworkAccessManager 上
    applicationContext.initialize();

    // ---- 5. 将 C++ 对象暴露给 QML 层 ----
    // setContextProperty() 会将 applicationContext 注册为 QML 全局属性
    // 在 QML 文件中可以通过 "applicationContext" 直接访问这个 C++ 对象
    // 例如: applicationContext.qtVersion  -> 返回 Qt 版本号
    //        applicationContext.settings   -> 返回 AppSettings 对象指针
    engine.rootContext()->setContextProperty("applicationContext", &applicationContext);

    // ---- 6. 连接引擎创建失败信号，确保出错时能退出 ----
    // Qt::QueuedConnection 确保信号在正确的事件循环中处理
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    // ---- 7. 加载 QML 模块 ----
    // 第一个参数 "cursor_music" 是 CMakeLists.txt 中 qt_add_qml_module 定义的 URI
    // 第二个参数 "Main" 是 qml/Main.qml 的组件名（文件名去掉 .qml 后缀）
    // Qt 会在编译时自动将 QML 文件编译为二进制资源，运行时直接加载
    engine.loadFromModule("cursor_music", "Main");

    // ---- 8. 进入 Qt 事件循环 ----
    // exec() 会阻塞直到窗口关闭或 quit() 被调用
    return app.exec();
}
