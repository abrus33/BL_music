// ============================================================================
// ApplicationContext.h - 全局应用上下文 / 服务管理器
// 功能：作为整个应用的依赖注入容器，持有所有核心服务（HttpClient、AppSettings 等）
//       并将它们暴露给 QML 层使用
// ============================================================================

#pragma once

#include <QObject>
#include <QString>

// 前向声明（Forward Declaration）
// 在头文件中仅声明类名，不包含完整定义，可减少头文件依赖和编译时间
// 完整的类定义在对应的 .cpp 文件中通过 #include 引入
class HttpClient;          // 通用 HTTP 客户端（src/network/HttpClient.h）
class AppSettings;         // 应用配置存储（src/storage/AppSettings.h）
class PersistentCookieJar; // 持久化 Cookie 管理器（src/storage/PersistentCookieJar.h）

/**
 * @brief 全局应用上下文（ApplicationContext）
 *
 * 职责：
 * - 作为全局单例，持有所有核心服务的实例
 * - 通过 Q_PROPERTY 将 C++ 对象暴露给 QML 层
 * - 管理服务的生命周期（创建、初始化、销毁）
 *
 * QML 访问方式：
 * 在 main.cpp 中通过 engine.rootContext()->setContextProperty("applicationContext", this)
 * 注册后，QML 文件可直接使用 applicationContext.xxx 访问属性和方法。
 */
class ApplicationContext : public QObject
{
    Q_OBJECT
    // Q_PROPERTY: 将 C++ 成员变量/方法暴露给 QML 的属性机制
    // 格式: Q_PROPERTY(类型 属性名 READ 获取函数 选项...)
    // CONSTANT 表示属性值不会改变，QML 在首次读取后缓存结果
    Q_PROPERTY(QString appName READ appName CONSTANT)   // 应用名称，供 QML 显示
    Q_PROPERTY(QString qtVersion READ qtVersion CONSTANT) // 当前 Qt 版本号

public:
    /**
     * @brief 构造函数
     * @param parent Qt 对象父指针，用于内存管理（父对象销毁时自动销毁子对象）
     *
     * 构造函数中会创建各个服务实例：
     * - AppSettings:      参数设置（窗口位置、用户偏好等）
     * - PersistentCookieJar: Cookie 持久化存储
     * - HttpClient:       通用的 HTTP 网络请求客户端
     */
    explicit ApplicationContext(QObject *parent = nullptr);

    // ---- Q_PROPERTY 对应的只读属性访问方法 ----

    /** @return 应用名称 "cursor_music" */
    QString appName() const;

    /** @return 当前运行的 Qt 版本号，例如 "6.10.2" */
    QString qtVersion() const;

    // ---- 服务实例访问方法 ----
    // 这些方法返回各服务的指针，供 C++ 代码使用
    // QML 可以通过 applicationContext.settings 等方式调用，但前提是返回类型
    // 必须是 QObject* 派生类、且对应类已注册到 QML 类型系统

    /** @return 应用设置管理器指针 */
    AppSettings *settings() const;

    /** @return 持久化 Cookie 管理器指针 */
    PersistentCookieJar *cookieJar() const;

    /** @return HTTP 客户端指针 */
    HttpClient *httpClient() const;

    /**
     * @brief 初始化各服务
     *
     * 必须在使用任何服务之前调用！
     * 初始化流程：
     * 1. 从磁盘加载持久化的 Cookie（PersistentCookieJar::load()）
     * 2. 将 CookieJar 挂载到 HttpClient 的 QNetworkAccessManager 上
     *    使得所有 HTTP 请求自动携带已保存的 Cookie
     */
    void initialize();

private:
    // 各服务的实例指针（使用原始指针，ApplicationContext 作为父对象管理其生命周期）
    AppSettings *m_settings;              // 应用配置管理器
    PersistentCookieJar *m_cookieJar;    // Cookie 持久化管理器（磁盘读写）
    HttpClient *m_httpClient;             // HTTP 网络请求客户端
};
