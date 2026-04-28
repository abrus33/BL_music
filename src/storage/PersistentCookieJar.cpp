// ============================================================================
// PersistentCookieJar.cpp - 持久化 Cookie 管理器实现
// 功能：实现 Cookie 的磁盘读写和自动持久化
// ============================================================================

#include "PersistentCookieJar.h"

#include <QFile>
#include <QDataStream>
#include <QStandardPaths>
#include <QDir>
#include <QUrl>

/**
 * @brief 构造函数
 * @param parent Qt 父对象
 *
 * 注意：构造函数中不会自动调用 load()，
 * 加载需要在合适的时机由 ApplicationContext 调用。
 */
PersistentCookieJar::PersistentCookieJar(QObject *parent)
    : QNetworkCookieJar(parent)
{
}

/**
 * @brief 从磁盘加载 Cookie
 *
 * 数据流：
 * cookies.dat（磁盘）
 *   -> QFile::open(ReadOnly)
 *   -> QDataStream >> QList<QByteArray>     // 反序列化
 *   -> QNetworkCookie::parseCookies(raw)    // 逐条解析
 *   -> setAllCookies(cookies)               // 设置到 CookieJar 内存
 *
 * 容错：如果文件不存在（首次运行），直接返回，不报错
 */
void PersistentCookieJar::load()
{
    QFile file(cookieFilePath());
    if (!file.open(QIODevice::ReadOnly))
        return;  // 文件不存在是正常情况（首次运行），静默返回

    // QDataStream: Qt 的二进制序列化工具
    // 用于读写 QByteArray、QList 等 Qt 内置类型
    QDataStream stream(&file);

    // 从流中读取之前保存的原始 Cookie 数据列表
    QList<QByteArray> rawCookies;
    stream >> rawCookies;
    file.close();

    // 将原始格式逐条解析为 QNetworkCookie 对象
    QList<QNetworkCookie> cookies;
    for (const auto &raw : rawCookies) {
        // parseCookies 解析 HTTP Set-Cookie 格式的字符串
        // 一条原始数据可能解析出多个 Cookie（因为 Set-Cookie 支持多属性）
        auto parsed = QNetworkCookie::parseCookies(raw);
        for (const auto &cookie : parsed) {
            cookies.append(cookie);
        }
    }

    // 将解析后的 Cookie 载入内存
    if (!cookies.isEmpty()) {
        setAllCookies(cookies);
    }
}

/**
 * @brief 保存 Cookie 到磁盘
 *
 * 数据流：
 * allCookies()（内存）
 *   -> cookie.toRawForm()                // 转为 HTTP Set-Cookie 原始格式
 *   -> QList<QByteArray>                // 收集到列表
 *   -> QDataStream << QList<QByteArray>  // 序列化
 *   -> cookies.dat（磁盘）
 */
void PersistentCookieJar::save()
{
    QFile file(cookieFilePath());
    if (!file.open(QIODevice::WriteOnly))
        return;  // 无法写入（权限问题等），静默失败

    // 将内存中的每个 Cookie 转为原始字符串格式
    QList<QByteArray> rawCookies;
    const auto cookies = allCookies();
    for (const auto &cookie : cookies) {
        // toRawForm() 返回 HTTP Set-Cookie 格式的字节数组
        // 例如: "SESSDATA=abc123; Path=/; Domain=.bilibili.com"
        rawCookies.append(cookie.toRawForm());
    }

    // 序列化到文件
    QDataStream stream(&file);
    stream << rawCookies;
    file.close();
}

/**
 * @brief 根据名称查找 Cookie
 * @param name Cookie 名称
 * @return QNetworkCookie 对象，找不到时返回空 Cookie
 *
 * 注意：QNetworkCookie 有一个 isNull() 方法可以判断是否为空
 */
QNetworkCookie PersistentCookieJar::getCookie(const QString &name) const
{
    const auto cookies = allCookies();
    for (const auto &cookie : cookies) {
        if (cookie.name() == name)
            return cookie;
    }
    return QNetworkCookie();  // 返回空 Cookie
}

/**
 * @brief 从浏览器 Cookie 字符串导入
 * @param cookieString 浏览器 Cookie 字符串
 *
 * 浏览器 Cookie 格式（Cookie 请求头格式）：
 *   "SESSDATA=abc123; bili_jct=def456; DedeUserID=789"
 *
 * 注意：不能使用 QNetworkCookie::parseCookies()，因为它只解析 Set-Cookie 响应头格式
 * Set-Cookie 格式（parseCookies 所需）：
 *   "SESSDATA=abc123; Path=/; Domain=.bilibili.com; HttpOnly"
 * Cookie 请求头格式（浏览器导出）：
 *   "SESSDATA=abc123; bili_jct=def456; DedeUserID=789"
 *
 * 这里手动解析：按分号拆分，对每个 key=value 创建 QNetworkCookie
 * 并设置正确的 Domain 和 Path 以便在访问 B站 API 时自动携带
 */
void PersistentCookieJar::setCookieString(const QString &cookieString)
{
    // 按分号分割每个 key=value 对
    const auto parts = cookieString.split(';');
    QList<QNetworkCookie> cookies;

    for (const auto &part : parts) {
        int eqPos = part.indexOf('=');
        if (eqPos > 0) {
            QString name = part.left(eqPos).trimmed();
            QString value = part.mid(eqPos + 1).trimmed();

            if (!name.isEmpty()) {
                // 创建 QNetworkCookie 并设置 Domain/Path
                // Domain=.bilibili.com 使其能匹配 api.bilibili.com 和 www.bilibili.com
                // Path=/ 使其对所有路径生效
                QNetworkCookie cookie(name.toUtf8(), value.toUtf8());
                cookie.setDomain(QStringLiteral(".bilibili.com"));
                cookie.setPath(QStringLiteral("/"));
                cookies.append(cookie);
            }
        }
    }

    // 将解析后的 Cookie 逐个插入到 CookieJar
    if (!cookies.isEmpty()) {
        for (const auto &cookie : cookies) {
            insertCookie(cookie);
        }
        save();  // 立即持久化到磁盘
    }
}

/**
 * @brief 获取指定 URL 的 Cookie（重写父类方法）
 * @param url 目标 URL
 * @return Cookie 列表
 *
 * 直接委托给父类实现，保持标准的域/路径匹配逻辑
 */
QList<QNetworkCookie> PersistentCookieJar::cookiesForUrl(const QUrl &url) const
{
    return QNetworkCookieJar::cookiesForUrl(url);
}

/**
 * @brief 从服务器响应中设置 Cookie（重写父类方法）
 * @param cookieList 服务器返回的 Cookie 列表
 * @param url        来源 URL
 * @return 是否成功设置
 *
 * 在父类标准行为基础上新增：Cookie 有变更时自动持久化到磁盘
 * 这意味着：任何 HTTP 响应带来的 Cookie 更新都会自动保存
 * 不需要手动调用 save()，实现"设置即保存"的自动持久化
 */
bool PersistentCookieJar::setCookiesFromUrl(const QList<QNetworkCookie> &cookieList, const QUrl &url)
{
    bool result = QNetworkCookieJar::setCookiesFromUrl(cookieList, url);
    if (result)
        save();  // Cookie 有更新，自动持久化
    return result;
}

/**
 * @brief 检查是否已登录
 * @return true 如果有非空的 SESSDATA
 *
 * B站登录态判断逻辑：
 * 1. SESSDATA Cookie 存在且非空 = 当前有登录会话
 * 2. bili_jct Cookie 存在 = 可以进行 POST 操作（点赞、评论等）
 *
 * 注意：这仅是本地快速判断，不保证登录态有效
 * 登录态可能已过期，需要通过 API 验证：
 * 调用 x/web-interface/nav 接口，检查返回的 code 是否为 0
 */
bool PersistentCookieJar::isLoggedIn() const
{
    // SESSDATA 是 B站的核心会话凭证，空值表示未登录
    return !getCookie(QStringLiteral("SESSDATA")).value().isEmpty();
}

/**
 * @brief 清除所有 Cookie
 *
 * 先清空内存中的 Cookie 列表（通过基类的 setAllCookies 保护方法）
 * 然后保存空文件到磁盘覆盖旧数据
 */
void PersistentCookieJar::clearCookies()
{
    setAllCookies(QList<QNetworkCookie>());
    save();
}

/**
 * @brief 获取 Cookie 文件路径
 * @return 完整路径字符串
 *
 * 路径示例：
 * Windows: C:/Users/<用户名>/AppData/Roaming/cursor_music/cookies.dat
 * Linux:   ~/.local/share/cursor_music/cookies.dat
 *
 * 目录不存在时自动创建
 */
QString PersistentCookieJar::cookieFilePath() const
{
    // QStandardPaths::AppDataLocation 返回的是应用数据目录
    // 需要配合 setApplicationName / setOrganizationName 使用
    QString path = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    // 确保目录存在
    QDir().mkpath(path);
    // 返回 cookies.dat 文件的完整路径
    return path + QStringLiteral("/cookies.dat");
}
