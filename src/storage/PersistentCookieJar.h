// ============================================================================
// PersistentCookieJar.h - 持久化 Cookie 管理器
// 功能：继承 QNetworkCookieJar，在标准的 Cookie 管理基础上增加磁盘持久化能力
// 关键作用：B站登录态的保持——登录成功后 Cookie 保存在磁盘，下次启动自动加载
// ============================================================================

#pragma once

#include <QNetworkCookieJar>
#include <QNetworkCookie>
#include <QString>
#include <QList>
#include <QByteArray>

/**
 * @brief 持久化 Cookie 管理器
 *
 * 标准 QNetworkCookieJar 仅在内存中管理 Cookie，程序退出后丢失。
 * 本类在其基础上增加了 Cookie 的磁盘持久化：
 * - load(): 从磁盘文件加载 Cookie 到内存
 * - save(): 将内存中的 Cookie 写入磁盘文件
 *
 * 持久化策略：
 * - 使用 QNetworkCookie::toRawForm() 将每个 Cookie 转为原始字符串格式
 * - 以 QList<QByteArray> 形式通过 QDataStream 序列化到文件
 * - Cookie 文件路径：%APPDATA%/cursor_music/cookies.dat
 *
 * 在 ApplicationContext::initialize() 中调用 load() 加载，之后
 * 所有通过 HttpClient 发出的请求都会自动携带这些 Cookie。
 *
 * B站关键 Cookie：
 * - SESSDATA:    登录会话凭证（判断登录态的核心）
 * - bili_jct:    CSRF Token（用于 POST 请求的安全校验）
 * - DedeUserID:  用户 UID
 * - refresh_token: 用于刷新过期的 SESSDATA
 */
class PersistentCookieJar : public QNetworkCookieJar
{
    Q_OBJECT

public:
    /**
     * @brief 构造函数
     * @param parent Qt 父对象
     */
    explicit PersistentCookieJar(QObject *parent = nullptr);

    /**
     * @brief 从磁盘加载 Cookie
     *
     * 读取 cookies.dat 文件，通过 QDataStream 反序列化为 QList<QByteArray>
     * 然后使用 QNetworkCookie::parseCookies() 还原为 QNetworkCookie 对象
     * 最后通过 setAllCookies() 设置到 CookieJar 中
     *
     * 如果文件不存在或读取失败（首次运行），静默返回，CookieJar 为空
     */
    void load();

    /**
     * @brief 保存 Cookie 到磁盘
     *
     * 遍历 allCookies()，使用 toRawForm() 将每个 Cookie 转为原始字符串
     * 以 QList<QByteArray> 形式通过 QDataStream 序列化到 cookies.dat 文件
     */
    void save();

    /**
     * @brief 根据名称查找指定 Cookie
     * @param name Cookie 名称，例如 "SESSDATA"
     * @return QNetworkCookie 对象（如果找不到，返回一个值全空的 QNetworkCookie）
     *
     * 典型用途：检查 SESSDATA 是否为空来判断登录态
     */
    QNetworkCookie getCookie(const QString &name) const;

    /**
     * @brief 从 Cookie 字符串导入（用于手动导入浏览器 Cookie）
     * @param cookieString 半角分号分隔的 Cookie 字符串
     *        （格式如 "SESSDATA=abc123; bili_jct=def456; ..."）
     *
     * 解析浏览器导出的 Cookie 字符串并导入到 Jar 中。
     * 导入后自动调用 save() 持久化到磁盘。
     *
     * 导入方式：
     * 用户登录 B站网页版后，从浏览器开发者工具复制 Cookie 字符串，
     * 在客户端中粘贴导入，完成登录态的建立。
     */
    void setCookieString(const QString &cookieString);

    // ---- 重写 QNetworkCookieJar 的方法 ----

    /**
     * @brief 获取指定 URL 对应的 Cookie（重写父类方法）
     * @param url 目标 URL
     * @return 匹配该 URL 的 Cookie 列表
     *
     * 委托给父类的 cookiesForUrl，保持标准行为不变
     */
    QList<QNetworkCookie> cookiesForUrl(const QUrl &url) const override;

    /**
     * @brief 从 URL 响应中设置 Cookie（重写父类方法）
     * @param cookieList 服务器返回的 Cookie 列表
     * @param url        来源 URL
     * @return 是否成功设置
     *
     * 在父类标准行为的基础上，Cookie 有变更时自动触发 save()
     * 实现 Cookie 的自动持久化
     */
    bool setCookiesFromUrl(const QList<QNetworkCookie> &cookieList, const QUrl &url) override;

    /**
     * @brief 清除所有 Cookie（退出登录时使用）
     *
     * 清空内存中的 Cookie 并保存空文件到磁盘
     */
    void clearCookies();

    /**
     * @brief 检查是否已登录
     * @return true 如果存在非空的 SESSDATA Cookie
     *
     * SESSDATA 是 B站登录态的核心凭证，其存在且非空 = 已登录
     * 注意：这仅检查 Cookie 是否存在，不验证其有效性
     * 有效性需要调用 B站 API x/web-interface/nav 来确认
     */
    bool isLoggedIn() const;

private:
    /**
     * @brief 获取 Cookie 文件的完整路径
     * @return 文件路径字符串
     *
     * 路径：%APPDATA%/cursor_music/cookies.dat
     * 会自动创建父目录
     */
    QString cookieFilePath() const;
};
