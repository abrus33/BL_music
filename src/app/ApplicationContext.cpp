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

// ---- 阶段二新增服务 ----
#include "bilibili/BilibiliApiClient.h"  // B站 API 客户端
#include "auth/AuthService.h"            // 登录认证服务
#include "bilibili/FavoriteService.h"    // 收藏夹服务
#include "player/MediaResolver.h"        // 媒体解析器
#include "player/PlayerController.h"     // 播放器控制器
#include "bilibili/MusicService.h"       // 音乐区服务
#include "player/PlaylistService.h"     // 播放列表服务

/**
 * @brief 构造函数
 * @param parent Qt 父对象
 *
 * 以 ApplicationContext 自身为父对象创建各服务实例，
 * 这样当 ApplicationContext 销毁时，各服务会自动被 Qt 内存管理机制释放。
 *
 * 服务创建顺序（注意依赖关系）：
 * 1. 基础层：AppSettings, PersistentCookieJar, HttpClient（无依赖）
 * 2. API 层：BilibiliApiClient（依赖 HttpClient）
 * 3. 业务层：AuthService（依赖 CookieJar + ApiClient）
 *             FavoriteService（依赖 ApiClient）
 *             MediaResolver（依赖 ApiClient）
 * 4. 表现层：PlayerController（无依赖）
 */
ApplicationContext::ApplicationContext(QObject *parent)
    : QObject(parent)

    // ==== 阶段一：基础服务 ====
    , m_settings(new AppSettings(this))
    , m_cookieJar(new PersistentCookieJar(this))
    , m_httpClient(new HttpClient(this))

    // ==== 阶段二：B站业务服务 ====
    // BilibiliApiClient 依赖于 HttpClient，用于发送 HTTP 请求
    , m_bilibiliApiClient(new BilibiliApiClient(m_httpClient, this))
    // AuthService 依赖 CookieJar（持久化 Cookie）和 ApiClient（验证登录态）
    , m_authService(new AuthService(m_cookieJar, m_bilibiliApiClient, this))
    // FavoriteService 依赖 ApiClient（获取收藏夹数据）
    , m_favoriteService(new FavoriteService(m_bilibiliApiClient, this))
    // MediaResolver 依赖 ApiClient（解析播放 URL）
    , m_mediaResolver(new MediaResolver(m_bilibiliApiClient, this))
    // PlayerController 独立，内部创建 QMediaPlayer + QAudioOutput
    , m_playerController(new PlayerController(this))
    // MusicService 依赖 BilibiliApiClient（获取音乐榜单数据）
    , m_musicService(new MusicService(m_bilibiliApiClient, this))
    // PlaylistService 依赖 AppSettings（持久化）+ MediaResolver（URL解析）+ PlayerController（播放控制）
    , m_playlistService(new PlaylistService(m_settings, m_mediaResolver, m_playerController, this))
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

/** @return B站 API 客户端指针 */
BilibiliApiClient *ApplicationContext::bilibiliApiClient() const
{
    return m_bilibiliApiClient;
}

/** @return 登录认证服务指针 */
AuthService *ApplicationContext::authService() const
{
    return m_authService;
}

/** @return 收藏夹服务指针 */
FavoriteService *ApplicationContext::favoriteService() const
{
    return m_favoriteService;
}

/** @return 媒体解析器指针 */
MediaResolver *ApplicationContext::mediaResolver() const
{
    return m_mediaResolver;
}

/** @return 播放器控制器指针 */
PlayerController *ApplicationContext::playerController() const
{
    return m_playerController;
}

/** @return 音乐区服务指针 */
MusicService *ApplicationContext::musicService() const
{
    return m_musicService;
}

/** @return 播放列表服务指针 */
PlaylistService *ApplicationContext::playlistService() const
{
    return m_playlistService;
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
 * 3. 验证登录态：如果 Cookie 存在，调用 AuthService::checkLogin()
 *    确认 Cookie 是否仍然有效（未过期）
 *
 * 这样所有后续通过 HttpClient 发出的 HTTP 请求都会自动携带已保存的 Cookie，
 * 实现登录态的持久化。
 */
void ApplicationContext::initialize()
{
    // 1. 从磁盘加载之前持久化的 Cookie 数据
    m_cookieJar->load();

    // 2. 将自定义 CookieJar 挂载到 QNetworkAccessManager
    m_httpClient->networkManager()->setCookieJar(m_cookieJar);

    // 3. 预热 B站会话（先访问首页建立完整 Cookie/Session，避免后续 API 触发 412 风控）
    m_bilibiliApiClient->warmUp();

    // 4. 如果本地有 Cookie，立即验证登录态
    if (m_cookieJar->isLoggedIn()) {
        m_authService->checkLogin();
    }
}
