// ============================================================================
// ApplicationContext.h - 全局应用上下文 / 服务管理器
// 功能：作为整个应用的依赖注入容器，持有所有核心服务（HttpClient、AppSettings 等）
//       并将它们暴露给 QML 层使用
// ============================================================================

#pragma once

#include <QObject>
#include <QString>

// 阶段一基础服务头文件（Q_PROPERTY 需要完整类型定义才能被 MOC 处理）
#include "network/HttpClient.h"
#include "storage/AppSettings.h"
#include "storage/PersistentCookieJar.h"

// 阶段二业务服务头文件
#include "bilibili/BilibiliApiClient.h"
#include "auth/AuthService.h"
#include "bilibili/FavoriteService.h"
#include "player/MediaResolver.h"
#include "player/PlayerController.h"

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
 *
 * 阶段二新增服务（可通过 QML 直接调用）：
 * - authService:       applicationContext.authService.checkLogin()
 * - favoriteService:   applicationContext.favoriteService.loadFavoriteFolders(mid)
 * - mediaResolver:     applicationContext.mediaResolver.resolve(id, type, bvid)
 * - playerController:  applicationContext.playerController.play()
 */
class ApplicationContext : public QObject
{
    Q_OBJECT
    // Q_PROPERTY: 将 C++ 成员变量/方法暴露给 QML 的属性机制
    // 格式: Q_PROPERTY(类型 属性名 READ 获取函数 选项...)
    // CONSTANT 表示属性值不会改变，QML 在首次读取后缓存结果
    Q_PROPERTY(QString appName READ appName CONSTANT)         // 应用名称，供 QML 显示
    Q_PROPERTY(QString qtVersion READ qtVersion CONSTANT)     // 当前 Qt 版本号
    Q_PROPERTY(AuthService *authService READ authService CONSTANT)    // 登录认证服务
    Q_PROPERTY(FavoriteService *favoriteService READ favoriteService CONSTANT) // 收藏夹服务
    Q_PROPERTY(MediaResolver *mediaResolver READ mediaResolver CONSTANT) // 媒体解析器
    Q_PROPERTY(PlayerController *playerController READ playerController CONSTANT) // 播放器

public:
    /**
     * @brief 构造函数
     * @param parent Qt 对象父指针，用于内存管理（父对象销毁时自动销毁子对象）
     *
     * 构造函数中会创建各个服务实例：
     * - AppSettings:          参数设置（窗口位置、用户偏好等）
     * - PersistentCookieJar:  Cookie 持久化存储
     * - HttpClient:           通用的 HTTP 网络请求客户端
     * - BilibiliApiClient:    B站 API 客户端（依赖 HttpClient）
     * - AuthService:          登录认证服务（依赖 CookieJar + ApiClient）
     * - FavoriteService:      收藏夹服务（依赖 ApiClient）
     * - MediaResolver:        媒体解析器（依赖 ApiClient）
     * - PlayerController:     播放器控制器
     */
    explicit ApplicationContext(QObject *parent = nullptr);

    // ---- Q_PROPERTY 对应的只读属性访问方法 ----

    /** @return 应用名称 "cursor_music" */
    QString appName() const;

    /** @return 当前运行的 Qt 版本号，例如 "6.10.2" */
    QString qtVersion() const;

    // ---- 服务实例访问方法 ----

    /** @return 应用设置管理器指针 */
    AppSettings *settings() const;

    /** @return 持久化 Cookie 管理器指针 */
    PersistentCookieJar *cookieJar() const;

    /** @return HTTP 客户端指针 */
    HttpClient *httpClient() const;

    /** @return B站 API 客户端指针（供 C++ 服务间调用） */
    BilibiliApiClient *bilibiliApiClient() const;

    /** @return 登录认证服务指针（QML 可直接调用其 Q_INVOKABLE 方法） */
    AuthService *authService() const;

    /** @return 收藏夹服务指针（QML 可直接调用） */
    FavoriteService *favoriteService() const;

    /** @return 媒体解析器指针（QML 可直接调用） */
    MediaResolver *mediaResolver() const;

    /** @return 播放器控制器指针（QML 可直接绑定属性） */
    PlayerController *playerController() const;

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
    // ==== 基础服务（阶段一） ====
    AppSettings *m_settings;              // 应用配置管理器
    PersistentCookieJar *m_cookieJar;    // Cookie 持久化管理器（磁盘读写）
    HttpClient *m_httpClient;             // HTTP 网络请求客户端

    // ==== 阶段二新增服务 ====
    BilibiliApiClient *m_bilibiliApiClient; // B站 API 客户端
    AuthService *m_authService;            // 登录认证服务
    FavoriteService *m_favoriteService;    // 收藏夹服务
    MediaResolver *m_mediaResolver;        // 媒体解析器
    PlayerController *m_playerController;  // 播放器控制器
};
