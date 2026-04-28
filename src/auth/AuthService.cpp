// ============================================================================
// AuthService.cpp - 登录认证服务实现
// 功能：Cookie 导入、登录态验证、用户信息管理
// ============================================================================

#include "AuthService.h"

#include <QJsonObject>
#include <QJsonArray>
#include <QDateTime>

#include "storage/PersistentCookieJar.h"
#include "bilibili/BilibiliApiClient.h"

/**
 * @brief 构造函数
 * @param cookieJar  PersistentCookieJar 指针
 * @param apiClient  BilibiliApiClient 指针
 * @param parent     Qt 父对象
 */
AuthService::AuthService(PersistentCookieJar *cookieJar,
                         BilibiliApiClient *apiClient,
                         QObject *parent)
    : QObject(parent)
    , m_cookieJar(cookieJar)
    , m_apiClient(apiClient)
{
    // 启动时检查本地是否有 Cookie（但不验证有效性）
    m_isLoggedIn = m_cookieJar->isLoggedIn();
}

bool AuthService::isLoggedIn() const
{
    return m_isLoggedIn;
}

QString AuthService::userName() const
{
    return m_userName;
}

QString AuthService::userAvatar() const
{
    return m_userAvatar;
}

qint64 AuthService::userMid() const
{
    return m_userMid;
}

/**
 * @brief 验证登录态（核心方法）
 *
 * 1. 调用 BilibiliApiClient::getNavInfo()
 * 2. 如果成功 data.isLogin == true，更新用户信息
 * 3. 如果失败，清除登录状态
 *
 * 使用场景：
 * - 应用启动后调用（确认 Cookie 是否有效）
 * - 导入 Cookie 后调用（验证 Cookie 是否正确）
 * - 定时检查（检测登录是否过期）
 */
void AuthService::checkLogin()
{
    m_apiClient->getNavInfo([this](bool success, QJsonObject data, QString error) {
        Q_UNUSED(error)

        if (success && data.value(QStringLiteral("isLogin")).toBool(false)) {
            // 登录有效，更新用户信息
            updateUserInfo(data);
            m_isLoggedIn = true;
        } else {
            // 登录无效或未登录
            m_isLoggedIn = false;
            m_userName.clear();
            m_userAvatar.clear();
            m_userMid = 0;
        }

        // 发射信号通知 QML 更新
        emit loginStateChanged();
        emit loginChecked(m_isLoggedIn, m_userName);
    });
}

/**
 * @brief 导入 Cookie 字符串（Q_INVOKABLE，可从 QML 调用）
 * @param cookieString 浏览器复制的 Cookie 字符串
 *
 * QML 调用示例：
 *   applicationContext.authService.importCookie("SESSDATA=xxx;bili_jct=yyy")
 *
 * 流程：
 * 1. 解析字符串 -> PersistentCookieJar::setCookieString()
 * 2. 自动保存到磁盘
 * 3. 调用 checkLogin() 验证
 */
void AuthService::importCookie(const QString &cookieString)
{
    if (cookieString.trimmed().isEmpty()) {
        emit cookieImportResult(false, QStringLiteral("Cookie 字符串为空"));
        return;
    }

    // 1. 导入 Cookie 到 PersistentCookieJar（解析 + 持久化到磁盘）
    m_cookieJar->setCookieString(cookieString);

    // 2. 验证登录态（异步请求，结果在回调中处理）
    //    注意：checkLogin() 是异步的，emit cookieImportResult 在回调中触发
    checkLogin();
}

/**
 * @brief 退出登录
 *
 * 清除所有 Cookie（内存 + 磁盘）
 * 重置登录状态
 */
void AuthService::logout()
{
    // 清空 CookieJar 中的所有 Cookie
    m_cookieJar->clearCookies();

    // 重置状态
    m_isLoggedIn = false;
    m_userName.clear();
    m_userAvatar.clear();
    m_userMid = 0;

    emit loginStateChanged();
}

/**
 * @brief 从 nav 接口返回的 data 中提取用户信息
 * @param data nav 接口的 data 对象
 *
 * 提取的字段：
 * - uname: 用户昵称
 * - face:  用户头像
 * - mid:   用户唯一标识
 */
void AuthService::updateUserInfo(const QJsonObject &data)
{
    m_userName = data.value(QStringLiteral("uname")).toString();
    m_userAvatar = data.value(QStringLiteral("face")).toString();
    m_userMid = static_cast<qint64>(data.value(QStringLiteral("mid")).toDouble(0));
}
