// ============================================================================
// AuthService.h - 登录认证服务
// 功能：管理 B站登录状态，提供 Cookie 登录和登录态验证
// 数据流：用户导入Cookie -> PersistentCookieJar -> checkLogin() -> 状态通知
// ============================================================================

#pragma once

#include <QObject>

class PersistentCookieJar;
class BilibiliApiClient;

/**
 * @brief 登录认证服务
 *
 * 职责：
 * - 验证当前 Cookie 的登录态（通过 nav 接口）
 * - 导入用户提供的浏览器 Cookie
 * - 暴露登录状态给 QML 层
 *
 * 登录方式（阶段二）：
 * 优先实现 Cookie 导入登录（用户从浏览器复制 Cookie 字符串）
 * 扫码登录作为后续增强
 *
 * 与 QML 的交互：
 * 通过 Q_PROPERTY 暴露登录状态，QML 可绑定 isLoggedIn 属性
 * 提供 Q_INVOKABLE 方法供 QML 调用
 */
class AuthService : public QObject
{
    Q_OBJECT
    // 暴露给 QML 的属性
    Q_PROPERTY(bool isLoggedIn READ isLoggedIn NOTIFY loginStateChanged)
    Q_PROPERTY(QString userName READ userName NOTIFY loginStateChanged)
    Q_PROPERTY(QString userAvatar READ userAvatar NOTIFY loginStateChanged)
    Q_PROPERTY(qint64 userMid READ userMid NOTIFY loginStateChanged)

public:
    /**
     * @brief 构造函数
     * @param cookieJar  PersistentCookieJar 实例（由 ApplicationContext 管理）
     * @param apiClient  BilibiliApiClient 实例
     * @param parent     Qt 父对象
     */
    explicit AuthService(PersistentCookieJar *cookieJar,
                         BilibiliApiClient *apiClient,
                         QObject *parent = nullptr);

    /** @return 是否已登录（基于 Cookie 存在性 + API 验证） */
    bool isLoggedIn() const;

    /** @return 当前登录用户的昵称 */
    QString userName() const;

    /** @return 当前登录用户的头像 URL */
    QString userAvatar() const;

    /** @return 当前登录用户的 mid（用户唯一标识） */
    qint64 userMid() const;

    /**
     * @brief 验证当前登录态
     *
     * 调用 B站 nav 接口验证 Cookie 是否有效
     * 如果有效，更新用户信息（昵称、头像等）
     * 如果无效，清空登录状态
     *
     * 建议在应用启动时和每次需要登录态的操作前调用
     */
    Q_INVOKABLE void checkLogin();

    /**
     * @brief 导入 Cookie 字符串（从浏览器复制）
     * @param cookieString 浏览器 Cookie 字符串
     *        格式: "SESSDATA=abc123; bili_jct=def456; DedeUserID=789"
     *
     * 调用方式（从 QML）：
     *   applicationContext.authService.importCookie("SESSDATA=xxx;...")
     *
     * 流程：
     * 1. 将 Cookie 字符串解析并存入 PersistentCookieJar
     * 2. 自动保存到磁盘
     * 3. 调用 checkLogin() 验证登录态
     */
    Q_INVOKABLE void importCookie(const QString &cookieString);

    /**
     * @brief 退出登录（清除 Cookie）
     *
     * 清除内存和磁盘中的所有 Cookie
     * 页面会回到未登录状态
     */
    Q_INVOKABLE void logout();

signals:
    /**
     * @brief 登录状态变更信号
     * QML 可通过 onLoginStateChanged 绑定此信号
     * 绑定 isLoggedIn 属性的 QML 元素会自动更新
     */
    void loginStateChanged();

    /** @brief 登录验证完成信号（无论成功失败都会触发） */
    void loginChecked(bool success, const QString &userName);

    /** @brief Cookie 导入结果信号 */
    void cookieImportResult(bool success, const QString &message);

private:
    /**
     * @brief 更新用户信息
     * @param data nav 接口返回的 data 对象
     *
     * 从 nav 接口的 data 中提取：
     * - uname -> m_userName
     * - face  -> m_userAvatar
     * - mid   -> m_userMid
     */
    void updateUserInfo(const QJsonObject &data);

    /** Cookie 持久化管理器 */
    PersistentCookieJar *m_cookieJar;

    /** B站 API 客户端 */
    BilibiliApiClient *m_apiClient;

    // ---- 登录状态 ----
    bool m_isLoggedIn = false;       // 是否已登录
    QString m_userName;              // 用户昵称
    QString m_userAvatar;            // 用户头像 URL
    qint64 m_userMid = 0;            // 用户 mid
};
