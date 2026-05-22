// ============================================================================
// AuthService.cpp - 登录认证服务实现
// 功能：Cookie 导入、登录态验证、用户信息管理
// ============================================================================

#include "AuthService.h"

#include <QJsonObject>
#include <QJsonArray>
#include <QDateTime>
#include <QUrl>
#include <QUrlQuery>
#include <QDebug>

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
 * @brief 验证登录态（核心方法，Q_INVOKABLE）
 *
 * 调用 BilibiliApiClient::getNavInfo() → B站 /x/web-interface/nav 接口
 *
 * 处理逻辑：
 * - success=true 且 data.isLogin=true → 更新用户信息（昵称、头像、mid）
 * - 其他情况 → 清空所有用户信息，标记未登录
 *
 * 结束后始终发出两个信号：
 * - loginStateChanged()  — QML 属性绑定自动刷新
 * - loginChecked(success, userName) — 供 QML Connections 处理
 *
 * 使用场景：
 * - 应用启动后调用（确认本地 Cookie 是否仍有效）
 * - 导入 Cookie 后调用（验证导入的 Cookie 是否正确）
 * - 扫码登录成功后调用（获取扫码用户的昵称等信息）
 * - 可扩展为定时检查（检测登录是否过期）
 */
void AuthService::checkLogin()
{
    qDebug() << "[Auth] checkLogin() - 开始验证登录态";

    // 调用 B站 nav 接口验证 Cookie 有效性
    // getNavInfo 内部使用 getJson → 独立 QNetworkReply 连接，无竞态
    m_apiClient->getNavInfo([this](bool success, QJsonObject data, QString error) {
        Q_UNUSED(error)

        qDebug() << "[Auth] checkLogin 响应: success=" << success
                 << "isLogin=" << data.value(QStringLiteral("isLogin")).toBool(false)
                 << "uname=" << data.value(QStringLiteral("uname")).toString();

        if (success && data.value(QStringLiteral("isLogin")).toBool(false)) {
            // ✓ 登录有效：提取并保存用户信息
            qDebug() << "[Auth] ✓ 登录态有效, 更新用户信息";
            updateUserInfo(data);
            m_isLoggedIn = true;
        } else {
            // ✗ 登录无效（Cookie 过期/未登录/API 错误）
            qDebug() << "[Auth] ✗ 未登录或登录态无效";
            m_isLoggedIn = false;
            m_userName.clear();
            m_userAvatar.clear();
            m_userMid = 0;
        }

        // 通知 QML：属性绑定刷新 + Connections 回调
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

QString AuthService::qrImageUrl() const
{
    return m_qrImageUrl;
}

QString AuthService::qrStatus() const
{
    return m_qrStatus;
}

bool AuthService::qrLoginActive() const
{
    return m_qrLoginActive;
}

void AuthService::startQrLogin()
{
    // ---- 第一步：清理旧的扫码流程 ----
    // 如果用户快速点击两次"获取二维码"，先停止上一个流程
    // 防止出现两个轮询定时器同时运行
    if (m_qrLoginActive) {
        qDebug() << "[QrLogin] 已有活跃的扫码流程，先停止旧的";
        if (m_qrPollTimer) m_qrPollTimer->stop();
    }

    // ---- 第二步：初始化状态 ----
    m_qrLoginActive = true;
    m_qrStatus = QStringLiteral("正在生成二维码...");
    m_qrImageUrl.clear();
    m_qrcodeKey.clear();

    // ---- 第三步：递增生成 ID（防竞态核心机制） ----
    // 每次调用 startQrLogin() 都会生成一个新的 genId
    // 异步回调中会检查 genId == m_qrGenerationId：
    //   匹配 → 这是最新一次请求的响应，正常处理
    //   不匹配 → 用户又点击了"获取二维码"，此回调已过期，丢弃
    // 这解决了"快速多次点击导致旧回调覆盖新状态"的竞态问题
    int genId = ++m_qrGenerationId;
    qDebug() << "[QrLogin] startQrLogin genId:" << genId;

    // 通知 QML：状态变为"活跃中"（按钮禁用、状态文字更新）
    emit qrLoginActiveChanged();
    emit qrStatusChanged();

    // ---- 第四步：异步请求生成二维码 ----
    // 回调中按值捕获 genId 和 this
    m_apiClient->generateQrCode([this, genId](bool success, QString url, QString qrcodeKey, QString error) {
        // 4a. 过期回调检查：genId 不匹配 → 用户已发起新请求，丢弃
        if (genId != m_qrGenerationId) {
            qDebug() << "[QrLogin] generateQrCode 回调被丢弃 (genId:" << genId
                     << "!= current:" << m_qrGenerationId << ")";
            return;
        }

        // 4b. 生成失败：显示错误，恢复非活跃状态
        if (!success) {
            qDebug() << "[QrLogin] 二维码生成失败:" << error;
            m_qrStatus = QStringLiteral("二维码生成失败: ") + error;
            m_qrLoginActive = false;
            emit qrStatusChanged();
            emit qrLoginActiveChanged();
            return;
        }

        // 4c. 生成成功：保存 qrcode_key 用于后续轮询
        qDebug() << "[QrLogin] 二维码生成成功, qrcode_key 长度:" << qrcodeKey.length();
        m_qrcodeKey = qrcodeKey;

        // 4d. 构造二维码图片 URL
        // B站 API 返回的是扫码链接（如 https://passport.bilibili.com/...）
        // 需要编码后通过在线服务生成二维码图片
        QString encodedUrl = QUrl::toPercentEncoding(url);
        m_qrImageUrl = QStringLiteral("https://api.qrserver.com/v1/create-qr-code/?size=220x220&data=") + encodedUrl;
        m_qrStatus = QStringLiteral("请使用B站APP扫描二维码");

        // 4e. 通知 QML 显示二维码
        emit qrCodeGenerated();
        emit qrStatusChanged();

        // ---- 第五步：启动轮询定时器 ----
        // 每 2 秒调用一次 pollQrLoginStatus() 检查扫码进度
        // QTimer 懒初始化，只创建一次
        if (!m_qrPollTimer) {
            m_qrPollTimer = new QTimer(this);
            QObject::connect(m_qrPollTimer, &QTimer::timeout, this, &AuthService::pollQrLoginStatus);
        }
        m_qrPollTimer->start(2000);  // 2000ms = 2秒
        qDebug() << "[QrLogin] 轮询定时器已启动, 每2秒";
    });
}

void AuthService::stopQrLogin()
{
    qDebug() << "[QrLogin] stopQrLogin 被调用";

    // 停止轮询定时器（防止在回调飞行期间继续轮询）
    if (m_qrPollTimer) {
        m_qrPollTimer->stop();
    }

    // 重置所有扫码相关状态
    m_qrLoginActive = false;
    m_qrImageUrl.clear();
    m_qrStatus.clear();
    m_qrcodeKey.clear();

    // 通知 QML：状态变为非活跃，UI 回到初始态
    emit qrLoginActiveChanged();
    emit qrStatusChanged();
}

void AuthService::pollQrLoginStatus()
{
    // ---- 门控条件 ----
    // 1. m_qrLoginActive == false → 用户已取消或流程已结束
    // 2. m_qrcodeKey.isEmpty() → 二维码尚未生成成功（理论上不会发生，但防御性检查）
    if (!m_qrLoginActive || m_qrcodeKey.isEmpty()) {
        qDebug() << "[QrLogin] pollQrLoginStatus 跳过: active=" << m_qrLoginActive
                 << "key_empty=" << m_qrcodeKey.isEmpty();
        return;
    }

    qDebug() << "[QrLogin] 轮询扫码状态...";

    // ---- 发起轮询请求 ----
    // BilibiliApiClient::pollQrCode 内部使用独立 QNetworkReply 连接，
    // 不会与其他并发请求（如 checkLogin 的 getJson）产生信号窜扰
    m_apiClient->pollQrCode(m_qrcodeKey, [this](int statusCode, QString errorMsg) {
        // 二次检查：在回调到达时再次确认未被取消
        // （可能在请求往返期间用户点击了"取消"）
        if (!m_qrLoginActive) {
            qDebug() << "[QrLogin] poll回调: 不再活跃, 忽略 statusCode:" << statusCode;
            return;
        }

        qDebug() << "[QrLogin] poll回调: statusCode=" << statusCode << "msg=" << errorMsg;

        // ---- 根据 B站状态码更新 UI ----
        // 状态码由 BilibiliApiClient::pollQrCode 内部解析（处理了嵌套 JSON 格式）
        switch (statusCode) {
        case 0:
            // ★ 登录成功：用户在手机上确认了登录
            // B站服务器在此响应中设置了 Set-Cookie (SESSDATA/bili_jct等)
            // PersistentCookieJar::setCookiesFromUrl 已自动捕获并保存到磁盘
            qDebug() << "[QrLogin] ★ 扫码登录成功! 停止轮询, 保存Cookie, 验证登录态";
            m_qrPollTimer->stop();
            m_qrStatus = QStringLiteral("扫码登录成功！");
            m_qrLoginActive = false;
            emit qrStatusChanged();
            emit qrLoginActiveChanged();

            // 显式调用 save 确保 Cookie 已写入磁盘（虽然 setCookiesFromUrl 已自动保存）
            m_cookieJar->save();
            qDebug() << "[QrLogin] Cookie已保存到磁盘";

            // 验证登录态：用新获取的 Cookie 调用 nav 接口获取用户昵称等信息
            // checkLogin 是异步的，完成后会发射 loginStateChanged 信号
            checkLogin();
            break;

        case 86038:
            // 二维码已过期（B站有效期约 3 分钟）
            qDebug() << "[QrLogin] 二维码已过期";
            m_qrStatus = QStringLiteral("二维码已过期，点击刷新重新生成");
            m_qrPollTimer->stop();
            m_qrLoginActive = false;
            emit qrStatusChanged();
            emit qrLoginActiveChanged();
            break;

        case 86090:
            // 已扫码但未确认 — 用户用 APP 扫了码但还没点"确认登录"
            qDebug() << "[QrLogin] 已扫码，等待用户确认";
            m_qrStatus = QStringLiteral("已扫码，请在手机上确认登录");
            emit qrStatusChanged();
            break;

        case 86101:
            // 未扫码 — 最常见的情况，不更新 UI（避免频繁刷新文字）
            // 静默等待下一次轮询
            break;

        default:
            // 未知状态码或网络错误
            qDebug() << "[QrLogin] 未知状态码:" << statusCode;
            if (statusCode < 0) {
                // 负数表示网络层错误（非 B站 API 错误）
                m_qrStatus = QStringLiteral("网络错误: ") + errorMsg;
                emit qrStatusChanged();
            }
            break;
        }
    });
}

/**
 * @brief 退出登录（Q_INVOKABLE，QML 退出按钮触发）
 *
 * 操作：
 * 1. 清除 PersistentCookieJar 中的所有 Cookie（内存 + 磁盘文件）
 * 2. 重置所有用户状态字段
 * 3. 发射 loginStateChanged 信号 → QML 自动更新 UI
 *
 * 注意：退出登录不影响扫码登录流程（如果扫码正在进行中）
 * 但实际使用中，扫码成功后的 checkLogin 会覆盖退出状态
 */
void AuthService::logout()
{
    // 清空 CookieJar → 内存清空 + 写入空文件覆盖磁盘
    m_cookieJar->clearCookies();

    // 重置用户信息
    m_isLoggedIn = false;
    m_userName.clear();
    m_userAvatar.clear();
    m_userMid = 0;

    // 通知 QML：属性绑定自动刷新 UI
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
