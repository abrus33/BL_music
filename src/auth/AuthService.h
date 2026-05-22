// ============================================================================
// AuthService.h - 登录认证服务
// 功能：管理 B站登录状态，提供两种登录方式：
//         1. Cookie 导入登录（用户从浏览器复制 Cookie 字符串）
//         2. 扫码登录（B站 APP 扫描二维码确认）
//
// 数据流总览：
//   Cookie登录: 导入Cookie → PersistentCookieJar → checkLogin() → 状态通知
//   扫码登录:   generateQrCode() → 轮询pollQrCode() → Set-Cookie自动保存 → checkLogin()
//
// 扫码登录状态机：
//   startQrLogin() → [qrLoginActive=true]
//     ├─ API回调(过期) ──→ genId不匹配，丢弃 ←─ m_qrGenerationId 防竞态
//     ├─ API回调(失败) ──→ 显示错误，qrLoginActive=false
//     └─ API回调(成功) ──→ 显示二维码，启动2秒轮询定时器
//           │
//           ├─ 定时器 → pollQrLoginStatus() → pollQrCode()
//           │     ├─ code=86101 ──→ 未扫码，继续轮询（不更新UI）
//           │     ├─ code=86090 ──→ 已扫码待确认，更新状态文字
//           │     ├─ code=86038 ──→ 二维码过期，停止定时器
//           │     ├─ code=0     ──→ 登录成功！保存Cookie → checkLogin()
//           │     └─ code<0     ──→ 网络错误，显示错误信息
//           │
//           └─ stopQrLogin() ──→ 停止定时器，清除所有状态
//
// 设计要点：
//   1. m_qrGenerationId: 每次调用 startQrLogin() 递增，异步回调中检查 genId
//      匹配性，丢弃过期的响应（用户快速点击"获取二维码"多次时）
//   2. 轮询使用独立 QNetworkReply 连接（BilibiliApiClient 内部），
//      不与全局 requestFinished 信号混用，避免多个并发请求的响应窜扰
//   3. Cookie 自动持久化：扫码成功后 B站 Set-Cookie 由 PersistentCookieJar
//      的 setCookiesFromUrl 重写自动保存到磁盘，无需手动保存
// ============================================================================

#pragma once

#include <QObject>
#include <QTimer>

class PersistentCookieJar;
class BilibiliApiClient;

/**
 * @brief 登录认证服务
 *
 * 职责：
 * - 验证当前 Cookie 的登录态（通过 B站 nav 接口）
 * - 导入用户提供的浏览器 Cookie
 * - 管理扫码登录全流程（生成二维码 → 轮询状态 → 保存Cookie）
 * - 暴露登录状态和扫码进度给 QML 层
 *
 * 两种登录方式：
 * 1. Cookie 导入登录：用户从浏览器复制 Cookie 字符串粘贴
 * 2. 扫码登录：使用 B站 APP 扫描二维码确认登录
 *
 * 与 QML 的交互：
 * - 通过 Q_PROPERTY 暴露登录状态和扫码进度，QML 可直接绑定
 * - 提供 Q_INVOKABLE 方法供 QML 按钮等控件调用
 * - 通过 signal 通知 QML 状态变更（异步回调 → UI 更新）
 *
 * 扫码登录 B站 API 端点：
 * - 生成: GET https://passport.bilibili.com/x/passport-login/web/qrcode/generate
 *         返回 {url, qrcode_key}
 * - 轮询: GET https://passport.bilibili.com/x/passport-login/web/qrcode/poll?qrcode_key={key}
 *         返回 {code: 0, data: {code: <状态码>, message: "..."}}
 *
 * 轮询状态码含义：
 *   86101 = 未扫码 — 继续等待
 *   86090 = 已扫码，等待用户在手机上确认
 *   86038 = 二维码已过期（有效期约3分钟）
 *   0     = 扫码确认成功，Set-Cookie 已由服务器返回
 *   负数   = 网络错误
 */
class AuthService : public QObject
{
    Q_OBJECT
    // 暴露给 QML 的属性
    Q_PROPERTY(bool isLoggedIn READ isLoggedIn NOTIFY loginStateChanged)
    Q_PROPERTY(QString userName READ userName NOTIFY loginStateChanged)
    Q_PROPERTY(QString userAvatar READ userAvatar NOTIFY loginStateChanged)
    Q_PROPERTY(qint64 userMid READ userMid NOTIFY loginStateChanged)

    // ---- QR 扫码登录相关属性 (QML 可直接绑定) ----
    // qrImageUrl: 二维码图片URL — 空字符串表示无二维码
    //   URL 由 api.qrserver.com 在线生成，参数为 B站扫码链接的 URL 编码
    //   格式: "https://api.qrserver.com/v1/create-qr-code/?size=220x220&data={encodedUrl}"
    Q_PROPERTY(QString qrImageUrl READ qrImageUrl NOTIFY qrCodeGenerated)

    // qrStatus: 当前扫码状态文字，显示在二维码下方
    //   可能值: "正在生成二维码..." / "请使用B站APP扫描二维码" / "已扫码，请在手机上确认登录" /
    //          "扫码登录成功！" / "二维码已过期，点击刷新重新生成" / "网络错误: xxx"
    Q_PROPERTY(QString qrStatus READ qrStatus NOTIFY qrStatusChanged)

    // qrLoginActive: 是否正在进行扫码登录流程（定时器是否在轮询）
    //   QML 用此属性控制"获取二维码"按钮的 enabled 状态
    //   以及"取消"按钮的 visible 状态
    Q_PROPERTY(bool qrLoginActive READ qrLoginActive NOTIFY qrLoginActiveChanged)

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

    /** @return 当前二维码图片URL */
    QString qrImageUrl() const;

    /** @return 当前扫码状态文字 */
    QString qrStatus() const;

    /** @return 是否正在进行扫码登录 */
    bool qrLoginActive() const;

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

    /**
     * @brief 开始扫码登录（Q_INVOKABLE，QML 按钮触发）
     *
     * 完整流程：
     * 1. 停止之前可能活跃的扫码流程（防止重复）
     * 2. 设置 qrLoginActive = true，发出 qrLoginActiveChanged 信号
     * 3. 递增 m_qrGenerationId（用于丢弃过期的异步回调）
     * 4. 调用 BilibiliApiClient::generateQrCode()
     * 5. 收到回调后：
     *    a. 检查 genId 是否匹配当前 m_qrGenerationId
     *       （不匹配 → 用户已发起新请求，丢弃此回调）
     *    b. 构造二维码图片 URL（通过 api.qrserver.com 在线生成）
     *    c. 发出 qrCodeGenerated 信号（QML 显示图片）
     *    d. 启动 2 秒轮询定时器，每 2 秒调用 pollQrLoginStatus()
     *
     * 生成的二维码有效期约 3 分钟，过期后状态码 86038
     */
    Q_INVOKABLE void startQrLogin();

    /**
     * @brief 停止/取消扫码登录（Q_INVOKABLE，QML 取消按钮触发）
     *
     * 操作：
     * - 停止轮询定时器
     * - 清除 qrImageUrl、qrStatus、qrcodeKey
     * - 设置 qrLoginActive = false
     * - 发出 qrLoginActiveChanged / qrStatusChanged 信号
     *
     * 注意：不调用 B站取消 API（B站无此端点），仅停止本地轮询
     */
    Q_INVOKABLE void stopQrLogin();

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

    /** @brief QR 二维码图片已生成，QML 应显示图片 */
    void qrCodeGenerated();

    /** @brief QR 扫码状态文字发生变化，QML 应更新状态标签 */
    void qrStatusChanged();

    /** @brief QR 登录激活状态变化，QML 应切换按钮可用性 */
    void qrLoginActiveChanged();

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

    /**
     * @brief 轮询扫码状态（由 QTimer 每2秒触发）
     *
     * 门控条件（任一不满足则跳过本次轮询）：
     * - m_qrLoginActive == true（用户未取消）
     * - m_qrcodeKey 非空（已成功生成二维码）
     *
     * 调用 BilibiliApiClient::pollQrCode()，在回调中根据状态码更新UI:
     * - 86101: 未扫码 → 不更新文字（静默等待）
     * - 86090: 已扫码 → 更新状态为"已扫码，请在手机上确认登录"
     * - 86038: 过期 → 停止定时器，提示刷新
     * - 0:     成功 → 停止定时器，保存 Cookie，调用 checkLogin()
     * - 负数:  失败 → 显示网络错误
     *
     * 回调中再次检查 m_qrLoginActive（防止在请求往返期间用户取消）
     */
    void pollQrLoginStatus();

    /** Cookie 持久化管理器 */
    PersistentCookieJar *m_cookieJar;

    /** B站 API 客户端 */
    BilibiliApiClient *m_apiClient;

    // ---- 登录状态 ----
    bool m_isLoggedIn = false;       // 是否已登录
    QString m_userName;              // 用户昵称
    QString m_userAvatar;            // 用户头像 URL
    qint64 m_userMid = 0;            // 用户 mid

    // ---- 扫码登录状态 ----
    QString m_qrImageUrl;            // 二维码图片URL
    QString m_qrStatus;              // 当前扫码状态文字
    QString m_qrcodeKey;             // 轮询用的 key
    bool m_qrLoginActive = false;    // 是否正在进行扫码登录
    QTimer *m_qrPollTimer = nullptr; // 轮询定时器
    int m_qrGenerationId = 0;        // 生成ID, 用于丢弃过期的异步回调
};
