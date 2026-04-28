// ============================================================================
// ApplicationContext.cpp - 全局应用上下文实现
// 功能：创建并初始化所有核心服务实例
// ============================================================================

#include "ApplicationContext.h"          // 对应头文件

#include <QtGlobal>                      // qVersion() 函数
#include <QUrl>                          // URL 处理
#include <QStandardPaths>                // 标准路径（如 AppDataLocation）
#include <QDir>                          // 目录操作（创建目录等）
#include <QNetworkAccessManager>         // 网络访问管理器（需完整定义来调用 setCookieJar）

// 各服务的完整头文件
#include "network/HttpClient.h"          // HTTP 客户端
#include "storage/AppSettings.h"         // 应用设置
#include "storage/PersistentCookieJar.h" // Cookie 持久化

/**
 * @brief 构造函数
 * @param parent Qt 父对象
 *
 * 以 ApplicationContext 自身为父对象创建各服务实例，
 * 这样当 ApplicationContext 销毁时，各服务会自动被 Qt 内存管理机制释放。
 */
ApplicationContext::ApplicationContext(QObject *parent)
    : QObject(parent)

    // 创建三个核心服务实例：
    // ------
    // AppSettings: 基于 QSettings 的 INI 配置存储
    //              -> 配置文件位于 %APPDATA%/cursor_music/cursor_music.ini
    // ------
    // PersistentCookieJar: 继承 QNetworkCookieJar
    //              -> Cookie 文件位于 %APPDATA%/cursor_music/cookies.dat
    //              -> 通过 QDataStream 序列化/反序列化
    // ------
    // HttpClient: 基于 QNetworkAccessManager 的 HTTP 请求封装
    //              -> 自动设置 UA、Referer 等 B站请求必需的 Header
    , m_settings(new AppSettings(this))
    , m_cookieJar(new PersistentCookieJar(this))
    , m_httpClient(new HttpClient(this))
{
}

/** @return 应用名称（常量属性，供 QML 显示用） */
QString ApplicationContext::appName() const
{
    return QStringLiteral("cursor_music");
}

/** @return 当前 Qt 版本号，例如 "6.10.2" */
QString ApplicationContext::qtVersion() const
{
    // qVersion() 是 QtGlobal 提供的全局函数，返回编译时链接的 Qt 版本
    return QString::fromLatin1(qVersion());
}

/** @return 应用设置管理器指针 */
AppSettings *ApplicationContext::settings() const
{
    return m_settings;
}

/** @return Cookie 持久化管理器指针 */
PersistentCookieJar *ApplicationContext::cookieJar() const
{
    return m_cookieJar;
}

/** @return HTTP 客户端指针 */
HttpClient *ApplicationContext::httpClient() const
{
    return m_httpClient;
}

/**
 * @brief 初始化服务
 *
 * 执行顺序很重要：
 * 1. 先加载 Cookie：因为 setCookieJar() 之后，网络请求会立即开始使用这个 CookieJar
 *    如果在加载之前就有网络请求，会导致 Cookie 丢失
 *
 * 2. 再设置 CookieJar：将我们自定义的持久化 CookieJar 设置到 QNetworkAccessManager
 *    Qt6 的 setCookieJar() 不会接管 CookieJar 的所有权（不负责销毁）
 *    所以 m_cookieJar 仍然由 ApplicationContext 管理生命周期
 *
 * 这样所有后续通过 HttpClient 发出的 HTTP 请求都会自动携带已保存的 Cookie，
 * 实现登录态的持久化。
 */
void ApplicationContext::initialize()
{
    // 从磁盘加载之前持久化的 Cookie 数据
    // cookies.dat 中存储的是基于 QDataStream 序列化的 QList<QByteArray>
    m_cookieJar->load();

    // 将自定义 CookieJar 挂载到 QNetworkAccessManager
    // 注意：在 Qt6 中 QNetworkAccessManager::setCookieJar() **不** 接管所有权
    // 所以 m_cookieJar 仍然由 this（ApplicationContext）管理生命周期
    m_httpClient->networkManager()->setCookieJar(m_cookieJar);
}
