# Bili Music — 项目说明与面试准备文档

---

## 第一部分：项目说明文档

### 1. 项目背景与核心功能

这是一个基于 **Qt 6 + QML** 的桌面端 B站音乐播放器。用户导入 B站账号 Cookie 或扫码登录后，可以浏览收藏夹中的视频/音频内容，创建播放列表，支持顺序/随机播放模式。首页展示 B站音乐区热门榜单。

**一句话：** 用桌面原生体验收听 B站收藏夹音乐的第三方客户端。

### 2. 技术栈

| 类别 | 技术 |
|------|------|
| **语言** | C++17（业务逻辑）、QML/JavaScript（UI层） |
| **UI 框架** | Qt 6.8 Quick（QML）、Qt Quick Controls 2 |
| **核心 Qt 模块** | Qt6::Quick、Qt6::QuickControls2、Qt6::Network、Qt6::Multimedia |
| **构建工具** | CMake 3.16+，qt_standard_project_setup |
| **第三方库** | 无（纯 Qt 生态，无外部依赖） |
| **数据格式** | JSON（API 通信 + QML 与 C++ 之间的数据交换） |
| **持久化** | QSettings（INI 格式配置）、自定义 cookies.dat（QDataStream 序列化） |

### 3. 项目架构

```
┌──────────────────────────────────────────────────────────┐
│                      QML UI 层                           │
│  Main.qml → Sidebar + StackLayout(HomePage/Favorites/   │
│              Login) + PlayerBar + PlaylistPopup          │
│  Theme.js → 全局颜色/字号/间距/圆角/动画 设计令牌          │
└─────────────── contextProperty ──────────────────────────┘
                              │
┌─────────────────────────────▼────────────────────────────┐
│          ApplicationContext（依赖注入容器）                │
│  持有全部服务实例的生命周期，通过 contextProperty 暴露给 QML │
├──────────────────────────────────────────────────────────┤
│  AuthService    ←→  PersistentCookieJar (cookies.dat)    │
│  FavoriteService ←→  BilibiliApiClient                   │
│  MusicService   ←→  BilibiliApiClient                    │
│  MediaResolver  ←→  BilibiliApiClient                    │
│  PlaylistService ←→  PlayerController + AppSettings       │
│  PlayerController ←→  QMediaPlayer + QAudioOutput         │
│  HttpClient     ←→  QNetworkAccessManager                │
└──────────────────────────────────────────────────────────┘
```

**核心设计模式：**
- **依赖注入**：ApplicationContext 在构造函数中按依赖顺序创建所有服务，并传入所需依赖（如 BilibiliApiClient 传给 AuthService、FavoriteService 等）
- **信号-槽通信**：C++ 层使用 Qt 信号/槽连接实现事件驱动；C++ 与 QML 之间通过 signal + Q_INVOKABLE + Q_PROPERTY 三种机制通信
- **回调模式**：B站 API 请求使用 `std::function` 回调（非信号/槽），每个请求独立连接 QNetworkReply::finished，避免并发请求的响应窜扰
- **JSON 桥接**：C++ 到 QML 的列表数据以 JSON 字符串传递，QML 端 `JSON.parse()` 转换为 JavaScript 数组

### 4. 关键模块实现思路

#### 4.1 认证系统（AuthService + PersistentCookieJar）

```
用户操作              C++ 处理流程                 QML 反应
─────────           ──────────────              ────────
粘贴 Cookie   →  PersistentCookieJar           loginChecked
                  .setCookieString()              ↓ 信号
                  解析分号分隔的键值对           "登录成功/失败"
                  Domain=.bilibili.com
                  → insertCookie() → save()
                  → BilibiliApiClient           userName/isLoggedIn
                    .getNavInfo()               Q_PROPERTY 变化
                    验证 Cookie 有效             → UI 自动刷新

点击扫码     →  AuthService.startQrLogin()
                  → BilibiliApiClient
                    .generateQrCode()
                    获取 qrcode_url + key
                  → api.qrserver.com 生成二维码
                  → m_qrPollTimer.start(2000)
                    每2秒 pollQrCode(key)
                    检查 data.code:
                      86101=未扫码
                      86090=已扫码待确认
                      0=成功(含refresh_token)
                  → 成功后同上验证 Cookie
```

**防竞态机制**：`m_qrGenerationId` 每次 startQrLogin 递增，回调中检查 genId 匹配性，丢弃过期异步响应。

#### 4.2 播放器系统（PlayerController）

**核心难题：B站 CDN 返回 403 Forbidden**

解决思路——不直接传递 URL 给 QMediaPlayer，而是**代理下载到内存缓冲区**：

```
mediaResolver.resolve(id, type)
  → BilibiliApiClient.getAudioStreamUrl(id)
    或 getVideoPlayUrl(bvid, cid)
  → 返回真实流媒体 URL

PlayerController.setSource(url)
  → 用独立的 QNetworkAccessManager GET 请求（带 UA + Referer 伪装浏览器）
  → reply->finished: 将全部数据读入 QBuffer（QByteArray 内存缓冲）
  → m_player->setSourceDevice(m_mediaBuffer, QUrl())
  → onMediaStatusChanged(LoadedMedia) → 自动 play()
```

**用独立 QNetworkAccessManager 的原因**：全局的 HttpClient 的 QNetworkAccessManager 挂了 PersistentCookieJar，B站在播放请求中看到 Cookie 反而不给资源。播放请求需要"裸"请求（只带 UA + Referer，不带 Cookie）。

#### 4.3 播放列表管理（PlaylistService）

```
createPlaylist(itemsJson, startItemId)
  → JSON.parse 解析所有条目
  → 按 startItemId 定位 currentIndex
  → Fisher-Yates 洗牌生成 m_shuffleOrder（随机模式下用）
  → saveToSettings() 持久化到 QSettings

播放中：
  trackFinished 信号（QMediaPlayer::EndOfMedia 触发）
  → onTrackFinished()
     ├─ 检查门控 m_isResolving（防止正在解析 URL 时重入）
     ├─ computeNextIndex()
     │   ├─ Sequential: (currentIndex+1) % size
     │   └─ Random: m_shuffleOrder[++m_shufflePointer]
     │       到达末尾重新洗牌
     └─ resolveAndPlayCurrentItem()
          → 递增 m_resolveGen（防竞态）
          → mediaResolver.resolve(...)

持久化：
  每 10 秒 m_positionSaveTimer 触发 savePosition()
  保存: playlist/items, playlist/currentIndex, playlist/playMode, playlist/position
  启动时 restoreFromSettings() 恢复上次状态
```

#### 4.4 收藏夹全量加载（FavoriteService）

B站 API 分页每页 20 条。递归逐页加载直到 `hasMore=false`：

```
loadAllFavoriteResources(mediaId)
  → m_accumulating = true, 清空 m_accumulatedMedias
  → loadFavoritesPage(mediaId, 1, 20)

loadFavoritesPage 内部：
  回调中:
    1. 检查 m_accumulating（防止超时/过期回调）
    2. 本页数据追加到 m_accumulatedMedias
    3. 若 hasMore → QTimer::singleShot(0, [=]{ loadFavoritesPage(page+1) })
       在主线程排队，防止递归过深爆栈
    4. 若 !hasMore → m_accumulating = false
       → emit allFavoriteResourcesLoaded(mediasJson)
```

#### 4.5 B站 API 防封控（WarmUp + 请求头伪装）

```
ApplicationContext::initialize()
  → BilibiliApiClient::warmUp()
      GET https://www.bilibili.com/ （访问首页建立 Cookie 会话上下文）

每次 API 请求：
  请求头:
    User-Agent: Chrome 120 Windows 的完整 UA 字符串
    Referer: https://www.bilibili.com
    Origin: https://www.bilibili.com
    Accept: application/json, text/plain, */*
```

之前不加这些头的时候 B站返回 HTTP 412（反爬虫）。WarmUp + 完整浏览器请求头伪装后恢复正常。

### 5. 技术难点与重点理解项

| 难点 | 说明 | 难度 |
|------|------|------|
| **B站 WBI 签名算法** | `getVideoPlayUrl` 需要 WBI 签名：从 nav 接口获取 img_key/sub_key，经 MIXIN_KEY_ENC_TAB 映射表取前 32 位得 mixinKey，参数排序 + mixinKey 后计算 MD5 得 w_rid | ⭐⭐⭐ |
| **QBuffer 代理下载绕过 CDN 403** | PlayerController 不直接传 URL 给 QMediaPlayer，而是先下载到内存 QBuffer，再 setSourceDevice | ⭐⭐⭐ |
| **并发 API 请求防窜扰** | BilibiliApiClient::getJson 不使用全局 requestFinished 信号，而是每个请求独立 connect(reply, finished)，确保 1:1 绑定 | ⭐⭐ |
| **扫码轮询的嵌套 JSON 解析** | B站 poll 接口返回 `{"data":{"code":86101}}` 的嵌套格式，需要先检查 data.code 而非顶层 code | ⭐⭐ |
| **QML 的 property int 溢出** | B站媒体 ID 约 15 位（~1.16×10¹⁴），超出 QML `property int`（32位，最大 ~2.1×10⁹），必须用 `property var` | ⭐⭐ |
| **Fisher-Yates 洗牌 + 随机模式** | 洗牌后确保当前项位于位置 0，支持前进/后退在洗牌序列中导航 | ⭐ |
| **Cookie 自动持久化** | PersistentCookieJar 重写 setCookiesFromUrl，每次设置 Cookie 自动 save，无需手动调用 | ⭐ |

### 6. AI 辅助标注（诚实声明）

| 部分 | 设计方式 | 说明 |
|------|---------|------|
| **项目架构设计** | 自设计 | MVC 分层、依赖注入容器、信号/槽通信模式 |
| **CMake 构建配置** | AI 辅助 | CMakeLists.txt 由 AI 生成，但理解后可以自行修改 |
| **QML UI 布局** | AI 辅助 + 自设计 | 组件拆分思路自己提出，AI 帮助生成具体 QML 代码 |
| **Theme.js 设计令牌** | 自设计 | 颜色/字号/间距体系自己定义 |
| **AppButton/MediaCard 等组件** | AI 辅助 | 自己提出"消除重复"的需求，AI 生成代码后自己审查并修复了 binding loop bug |
| **PlayerController·QBuffer 代理下载** | AI 辅助 | 核心思路是 AI 建议的，但自己理解后确认了必要性 |
| **BilibiliApiClient 并发防窜扰** | 自设计 | 自己在调试中发现回调混乱，提出独立 reply 连接的方案 |
| **WBI 签名算法** | AI 生成 | B站的 WBI 签名是反爬机制，算法由 AI 从公开资料还原，自己尚未完全消化 |
| **扫码轮询嵌套 JSON 解析** | 自调试 | 遇到 B站 poll 返回格式不一致，自己查看响应找出的问题 |
| **int32 溢出修复** | 自调试 | 发现 `property int _pendingStartId` 截断了 15 位 ID，自己定位修复 |
| **HTTP 412 风控修复** | AI 辅助 + 自调试 | AI 建议 warmUp + Origin header，自己验证有效性 |
| **Fisher-Yates 洗牌算法** | AI 生成 | 经典算法，AI 实现，自己理解逻辑 |
| **QML 的 Qt.callLater / Component.onCompleted 时序** | 自设计 | 理解 QML 对象创建顺序后自己设计的延迟初始化方案 |

> **面试策略：** 上述表格中标注"自设计/自调试"的部分可以自信详细介绍；标注"AI 生成"的部分诚实说明"这是 AI 辅助生成的，但我在后续调试中验证了它的正确性并理解了核心逻辑"——这反而体现你的工程化思维和快速学习能力。

---

## 第二部分：面试官追问预测（15-20 题）

### 基础层（项目功能与技术选型）

#### Q1. 这个项目是做什么的？你为什么要做它？

**参考答案：**
这是一个用 Qt 6 + QML 开发的 B站音乐桌面客户端。核心功能是登录 B站账号后，浏览收藏夹中的音频/视频内容，创建播放列表并播放。做这个项目是因为想练习 Qt/QML 的完整项目开发流程，同时解决自己的实际需求——在桌面端方便地收听 B站上收藏的音乐。

#### Q2. 为什么选择 Qt/QML 而不是 Electron 或其他框架？

**参考答案：**
- **性能**：Qt 是 C++ 原生框架，内存占用和启动速度明显优于 Electron
- **QML 开发效率**：声明式 UI 语法类似前端框架，开发效率高，同时底层是 C++ 的高性能
- **Qt Multimedia**：内置多媒体播放能力，不需要引入额外的音频库
- **学习目的**：想深入理解 C++ 与 QML 的混合编程模式

#### Q3. 你的项目中 C++ 和 QML 是如何通信的？

**参考答案：**
三种方式：
1. **Q_PROPERTY**：C++ 属性变化时 QML 自动更新 UI。如 `PlayerController::playbackState` 属性绑定到 PlayerBar 的按钮文字
2. **Q_INVOKABLE**：QML 直接调用 C++ 方法。如点击播放按钮调用 `playerController.play()`
3. **Signal**：C++ 发射信号，QML 通过 `Connections` 或 `.connect()` 接收。如 `favoriteService.favoriteFoldersLoaded` 信号触发 UI 刷新

核心入口是通过 `engine.rootContext()->setContextProperty("applicationContext", &ctx)` 将整个服务容器暴露给 QML。

#### Q4. 你如何管理项目中各个 C++ 服务之间的依赖关系？

**参考答案：**
我用了一个 **ApplicationContext** 类作为依赖注入容器。它在构造函数中按依赖顺序创建所有服务——比如 BilibiliApiClient 在最前面，AuthService/FavoriteService/MusicService 都依赖它，PlaylistService 依赖 PlayerController 和 MediaResolver。这样避免了全局变量和单例模式，依赖关系清晰，也方便单元测试。

---

### 实现细节层

#### Q5. 播放器是如何工作的？QMediaPlayer 怎么播放 B站的音频？

**参考答案：**
B站的音频接口 `getAudioStreamUrl` 返回一个 CDN 流媒体 URL。如果直接传给 `QMediaPlayer::setSource(url)`，CDN 会因为缺少浏览器请求头返回 403。

我的做法是**代理下载**：
1. 用独立的 `QNetworkAccessManager` 发起 GET 请求（带 Chrome UA + Referer 头）
2. 下载完成后将数据写入 `QBuffer`（内存中的 QByteArray 缓冲区）
3. 调用 `m_player->setSourceDevice(m_mediaBuffer, QUrl())` 从缓冲区播放

**追问：为什么用独立的 QNetworkAccessManager？**
因为全局的 HttpClient 挂载了 PersistentCookieJar，B站 CDN 看到 Cookie 反而拒绝服务。播放请求需要"裸"请求。

#### Q6.【重点理解】QBuffer 是什么？为什么不用临时文件？

**参考答案：**
QBuffer 是 Qt 提供的一个 `QIODevice` 子类，它把 `QByteArray`（内存中的字节数组）包装成可读写的 IO 设备。QMediaPlayer 的 `setSourceDevice()` 接受任何 QIODevice，所以可以直接从内存播放。

不用临时文件的原因：
- 避免磁盘 IO 开销
- 不需要管理文件清理
- 内存播放延迟更低

**实际作用：** 本质上是把网络音频流完整下载到内存，然后让 QMediaPlayer 像读本地文件一样从内存读。相当于自己实现了"先缓存后播放"。

> **若答不上来：** "QBuffer 是 Qt 提供的内存 IO 设备，把 QByteArray 包装成 QIODevice 接口，让 QMediaPlayer 可以从内存读取音频数据。核心价值是避免了磁盘 IO 和临时文件管理。"

#### Q7. 播放列表的顺序模式和随机模式是怎么实现的？

**参考答案：**
- **顺序模式**：下一首 = `(currentIndex + 1) % playlistSize`，上一首 = `(currentIndex - 1 + size) % size`
- **随机模式**：创建播放列表时用 **Fisher-Yates 洗牌算法** 生成一个随机索引序列 `m_shuffleOrder`，确保当前项在位置 0。播放时沿着这个序列前进。序列播完后重新洗牌。

切歌的触发点是 `QMediaPlayer::mediaStatusChanged` 信号，当状态变为 `EndOfMedia` 时发射 `trackFinished` 信号，PlaylistService 接收并自动切换到下一首。

#### Q8. 如何处理 B站 API 的并发请求？如果同时发起多个请求，回调不会乱吗？

**参考答案：**
这是一个我实际遇到的问题。BilibiliApiClient 的 `getJson()` 方法**不使用** HttpClient 的全局 `requestFinished` 信号，而是对每个 `QNetworkReply` 独立连接 `finished` 信号：

```cpp
QNetworkReply *reply = m_httpClient->networkManager()->get(request);
connect(reply, &QNetworkReply::finished, this, [this, reply, callback]() {
    // 这个 lambda 只处理这一个 reply 的响应
    callback(...);
    reply->deleteLater();
});
```

这样每个请求的响应处理都是 1:1 绑定的，不会互相干扰。扫码轮询（每 2 秒一次）和普通 API 请求可以同时运行。

#### Q9.【重点理解】WBI 签名是什么？为什么要实现它？

**参考答案：**
WBI（Web Interface）签名是 B站对部分敏感 API（如视频播放链接获取）的防爬虫机制。签名算法流程：

1. 从 `/x/web-interface/nav` 接口的返回中提取 `wbi_img.img_key` 和 `wbi_img.sub_key`
2. 拼接两个 key 后通过一个固定的 64 字节映射表（MIXIN_KEY_ENC_TAB）重排取前 32 位，得到 `mixin_key`
3. 将所有请求参数按 key 字母序排序，拼接为 query string
4. 追加 `mixin_key` 后计算 MD5，得到 `w_rid` 参数
5. 最终请求带上 `w_rid` + `wts`（当前时间戳）

这部分算法是 AI 根据 B站的公开 JS 源码还原生成的。我正在逐步理解映射表的原理，但核心逻辑（参数排序 → 加盐 → MD5 签名）是标准的 API 签名模式。

> **若答不上来：** "WBI 签名是 B站的反爬虫机制，本质是 HMAC 类的请求签名——把参数排序后加上密钥计算 MD5，服务端用同样方式验证。算法部分我是借助 AI 从 B站的公开 JS 代码还原出来的，我理解了核心流程但还没完全消化映射表的具体细节。"

#### Q10. B站扫码登录的流程是怎样的？

**参考答案：**
1. 调用 `generateQrCode` 接口获取 `qrcode_url`（二维码内容）和 `qrcode_key`
2. 将 `qrcode_url` 传给 `api.qrserver.com` 的 API 生成二维码图片，显示在 UI 上
3. 启动 QTimer 每 2 秒调用 `pollQrCode(qrcode_key)`：
   - `data.code = 86101`：用户还没扫码
   - `data.code = 86090`：已扫码，等待用户在手机上确认
   - `data.code = 0`，且 data 中有 `refresh_token`：登录成功
   - `data.code = 86038`：二维码过期
4. 登录成功后，用返回的 `refresh_token` 换取 Cookie

**难点：** B站 poll 接口的响应格式是嵌套的——外面一层 `code=0` 表示 HTTP 请求成功，真正的扫码状态在 `data.code` 里。我一开始只看顶层 code，扫码永远显示"未扫码"。

#### Q11. 你遇到了 QML `property int` 溢出的 Bug，是怎么回事？

**参考答案：**
B站的媒体 ID 约为 15 位数字（如 `116175409253580`），而 QML 的 `property int` 是 32 位有符号整数，最大值约 21 亿（10 位）。这导致 ID 被截断，播放列表创建时找不到对应的资源。

**修复：** 将 `property int` 改为 `property var`。`var` 在 QML 中对应 JavaScript 的 Number 类型（IEEE 754 double），可以精确表示 53 位以内的整数，足够容纳 B站的 ID。

**教训：** 在处理外部 API ID 时，不要假设它们适合 32 位。这是一个常见的跨语言边界 Bug。

---

### 架构与设计层

#### Q12. 为什么不使用 QAbstractListModel 而是用 JSON 字符串传递列表数据？

**参考答案：**
这是一个权衡。QAbstractListModel 是 Qt 的官方数据模型方案，性能更好，支持增量更新。但我选择了 JSON 字符串方案，原因是：

1. **开发速度**：B站 API 返回的就是 JSON，直接序列化传递，不需要为每种数据类型编写 Model 子类
2. **灵活性**：B站不同接口返回的字段差异很大，JSON 天然支持动态字段
3. **QML 生态**：QML 的 JavaScript 引擎可以高效解析 JSON，Repeater 支持直接遍历数组

**坦诚说明：** 如果项目规模增长或需要频繁局部更新，我会考虑重构为 QAbstractListModel。

#### Q13. 你的 PersistentCookieJar 是如何工作的？

**参考答案：**
`PersistentCookieJar` 继承自 `QNetworkCookieJar`，在 Qt 的内存 Cookie 管理基础上增加了磁盘持久化：

- **存储格式**：`cookies.dat` 文件，用 `QDataStream` 序列化 `QList<QByteArray>`（每个 Cookie 的 raw form）
- **自动保存**：重写 `setCookiesFromUrl()`，每次 HTTP 响应设置新 Cookie 时自动调用 `save()`
- **手动导入**：`setCookieString()` 方法解析浏览器导出的 Cookie 字符串（`key1=value1; key2=value2` 格式），为每个键值对创建 `QNetworkCookie`，设置 Domain 为 `.bilibili.com`
- **登录判断**：`isLoggedIn()` 检查是否存在非空的 `SESSDATA` Cookie

#### Q14. 你项目的错误处理策略是怎样的？

**参考答案：**
项目采用了**分层错误处理**：

1. **网络层**：`HttpClient::Response` 封装了 `success`（网络层是否有错误）和 `statusCode`（HTTP 状态码）
2. **API 层**：`BilibiliApiClient::getJson()` 检查 JSON 的 `code` 字段（B站业务错误码），非零时发射 `apiError` 信号并回调 `false`
3. **播放层**：`PlayerController` 连接 `QMediaPlayer::errorOccurred` 信号，将错误转发给 QML
4. **UI 层**：QML 通过信号中的 `success` 布尔值决定显示内容还是错误提示（如 FavoritesPage 的 `_playError` 属性）

**不足之处：** 目前没有统一的错误日志系统（只是 qDebug 输出），也没有错误重试机制——这是后续优化的方向。

#### Q15. Qt Multimedia 的播放状态机是怎样的？你怎么处理异步播放的时序问题？

**参考答案：**
QMediaPlayer 有一个关键的状态转换：

```
StoppedState → (setSource) → LoadingState → LoadedState → (play) → PlayingState
                                                              ↑
                                          PausedState ← (pause) ←┘
```

我遇到的问题：`setSource()` 是异步的——调用后 source 可能还没加载完。我的处理方式：

1. 在 `setSource()` 中设置 `m_pendingPlay = true` 标志
2. 在 `onMediaStatusChanged()` 中检测 `MediaStatus == LoadedMedia && m_pendingPlay` 时自动调用 `play()`
3. 当状态变为 `EndOfMedia` 时发射 `trackFinished` 信号触发切歌

这是一个典型的**异步操作同步化**模式——用状态标志 + 信号驱动的方式来保证操作顺序。

---

### 优化与深度追问

#### Q16. 如果播放一个很大的音频文件（几百 MB），你的 QBuffer 方案会有什么问题？

**参考答案：**
会有一个严重问题——**内存爆炸**。当前方案把整个音频文件下载到内存的 QByteArray 中，几百 MB 的文件会直接占满内存。

**改进方案：**
- 可以实现一个自定义 `QIODevice` 子类，在读取时按需下载（类似流式播放）
- 或者用 `QNetworkReply` 本身作为 source device（QNetworkReply 继承了 QIODevice），这样 `setSourceDevice(reply)` 可以边下载边播放
- 但这需要 B站 CDN 支持 Range 请求（HTTP 206 Partial Content）

> **若答不上来：** "目前项目处理的都是几分钟的音频文件，体积在 10MB 以内，所以内存方案够用。但如果有大文件需求，我会研究流式播放方案。"

#### Q17.【重点理解】HTTP 412 错误你是怎么排查和解决的？

**参考答案：**
B站 API 返回 412 状态码（Precondition Failed），实际含义是 B站的反爬虫风控系统拒绝了请求。

**排查过程：**
1. 先在浏览器中测试同一个 API 接口——浏览器正常返回 200
2. 对比浏览器发出的请求头和我的请求头，发现缺少 `Origin` 头和 `Referer` 头
3. 尝试只加这些头——仍然 412
4. 联想到浏览器访问前会先加载首页，我的程序没有这个"热身"过程

**解决方案：**
- 添加 `warmUp()` 方法：在初始化时先访问 `https://www.bilibili.com/` 首页，让 B站的 session cookie 和风控上下文建立起来
- 所有 API 请求加上完整的浏览器请求头（UA、Referer、Origin、Accept）

**本质：** B站的风控系统是一个有状态的会话机制——它期望看到"正常用户"的浏览行为模式（先访问首页，再调用 API，带正确的请求头链）。

#### Q18. 如果你要添加新功能（如搜索），你会怎么设计？

**参考答案：**
1. 在 `BilibiliApiClient` 中添加搜索接口方法
2. 新建 `SearchService` 类（或者在现有服务中扩展），负责调用 API 和格式化结果
3. 在 `ApplicationContext` 中创建 SearchService 实例并暴露给 QML
4. 新建 `SearchPage.qml`，用 `TextField` + `Repeater` + `MediaCard` 展示结果
5. 在 `Sidebar.qml` 的导航模型中增加"搜索"项

这样设计保持了与现有架构的一致性。

#### Q19. 你提到 QML Repeater 而不是 ListView，在什么场景下 ListView 更好？

**参考答案：**
ListView 的优势：
- **视图复用**：只渲染可见区域的 delegate，大量数据时性能远超 Repeater
- **内置滚动**：自带 `ScrollBar`、`header`/`footer`、`section` 支持
- **选中高亮**：内置 `highlight` 和 `currentIndex` 管理

我的项目中 `PlaylistPopup` 使用了 ListView（因为需要选中高亮 + 大量条目），而 `HomePage` 和 `FavoritesPage` 用 Repeater（条目少，外层已有 ScrollView，不需要选中高亮）。

**坦诚说明：** 如果 FavoritesPage 的收藏夹内容超过几百条，当前 Repeater 方案可能卡顿，这时应该换成 ListView。

#### Q20. 你的项目没有单元测试，如果要加的话你会测什么？

**参考答案：**
我会优先测试以下模块：

1. **BilibiliApiClient 的 URL 构建和签名**：给定已知输入，验证输出的 URL 参数正确（尤其是 WBI 签名）
2. **PlaylistService 的切歌逻辑**：模拟 trackFinished 信号，验证 computeNextIndex 在顺序/随机模式下的正确性
3. **PersistentCookieJar 的序列化/反序列化**：写入一组 Cookie → 保存 → 重新加载 → 验证一致性
4. **PlayerController 的状态机**：验证 play/pause/stop/seek 的状态转换正确

**工具选择：** Qt Test 框架（`QTest`），它原生支持信号/槽测试和异步操作模拟。

---

## 附：如果答不上来时的话术

> **"这部分是借助 AI 生成的初步版本，我后续正在重构理解中。不过我在实际调试中验证了它的正确性，核心逻辑是……（讲你能理解的部分）。"**

> **"我在这个项目中采用了实用主义策略——对于 WBI 签名这类标准算法，先用 AI 辅助实现，确保功能跑通，然后在代码审查和调试过程中逐步理解。这种工程化思维让我在有限时间内完成了完整项目。"**

> **"这个问题的更优方案我后续研究过，目前项目中的实现是针对小规模使用场景的简化版本，如果面临更大规模的需求，我会考虑……（提出改进方向）。"**

---

*文档生成日期：2026-05-22*
*项目：cursor_music (Bili Music)*
