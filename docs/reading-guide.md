# 新手源码阅读指南 — Bilibili Music Client

> 本文档面向 **C++/Qt 初学者**，提供推荐的项目源码阅读顺序。
> 每一个文件只需要关注 **1~2 个核心概念**，循序渐进，避免信息过载。
>
> 配套注释规范见：[项目注释规范](commenting-guide.md)。读代码时如果遇到 Qt/QML 机制类注释，
> 可以先对照这份规范理解 `Q_PROPERTY`、`Q_INVOKABLE`、信号槽、QML 绑定等基础概念。

---

## 目录

1. [架构速览：先看全景图](#1-架构速览先看全景图)
2. [第一轮：Qt 应用是怎么启动的](#2-第一轮qt-应用是怎么启动的)
3. [第二轮：C++ 和 QML 是如何对话的](#3-第二轮c-和-qml-是如何对话的)
4. [第三轮：网络请求是怎么发出的](#4-第三轮网络请求是怎么发出的)
5. [第四轮：数据是如何持久化的](#5-第四轮数据是如何持久化的)
6. [第五轮：业务层是怎么调用 B 站 API 的](#6-第五轮业务层是怎么调用-b-站-api-的)
7. [第六轮：音乐是怎样从服务器到扬声器的](#7-第六轮音乐是怎样从服务器到扬声器的)
8. [第七轮：QML 界面是怎么做的](#8-第七轮qml-界面是怎么做的)
9. [进阶：读完源码后还可以学什么](#9-进阶读完源码后还可以学什么)
10. [常见坑点速查表](#10-常见坑点速查表)

---

## 1. 架构速览：先看全景图

在读任何一行代码之前，先搞清楚 **各文件之间的依赖关系**：

```
┌────────────────────────────────────────────────────────┐
│ main.cpp                   ← 程序入口                  │
│  └─ ApplicationContext     ← "管家"，持有所有服务       │
│      ├─ AppSettings        ← 配置文件（InI）            │
│      ├─ HttpClient         ← 发送 HTTP 请求            │
│      │    └─ PersistentCookieJar ← Cookie 存硬盘        │
│      ├─ BilibiliApiClient  ← 封装 B 站 API             │
│      │    ├─ AuthService       ← 登录                  │
│      │    ├─ FavoriteService   ← 收藏夹                │
│      │    ├─ MusicService      ← 音乐热门榜            │
│      │    └─ MediaResolver     ← 解析播放地址           │
│      └─ PlayerController   ← 控制 QMediaPlayer         │
│                                                         │
│ 以上全部是 C++ 层                                        │
│ ═══════════════════════════════════════════════════════ │
│ 以下全部是 QML 层                                        │
│                                                         │
│ Main.qml                  ← 窗口框架（三栏布局）        │
│  ├─ Sidebar.qml           ← 左侧导航                    │
│  ├─ StackLayout            ← 右侧内容区                 │
│  │    ├─ HomePage.qml      ← 音乐热门卡片网格           │
│  │    ├─ FavoritesPage.qml ← 收藏夹列表                 │
│  │    └─ LoginPage.qml     ← Cookie 登录页              │
│  └─ 底部播放栏             ← 进度条 + 音量 + 播放按钮   │
│                                                         │
│ Theme.js                  ← 全局样式常量（所有 QML 共享）│
└────────────────────────────────────────────────────────┘
```

**核心洞察**：这是一个典型的 Qt Quick 应用。C++ 负责数据和逻辑，QML 负责展示和交互。两者的桥梁是 `ApplicationContext`——它通过 `setContextProperty` 注入到 QML 中。

---

## 2. 第一轮：Qt 应用是怎么启动的

这轮只读 **1 个文件**，搞清楚 Qt Quick 应用的骨架。

### 2.1 `CMakeLists.txt` — 项目的"施工图纸"

**路径**：[CMakeLists.txt](../CMakeLists.txt)

**关注重点**：
| 行号 | 关注内容 | 知识点 |
|------|----------|--------|
| 1-7 | `project(...)`, `CMAKE_CXX_STANDARD 17` | 项目命名和 C++ 标准 |
| 9-15 | `find_package(Qt6 REQUIRED ...)` | 需要哪些 Qt 模块（Quick=UI, Network=HTTP, Multimedia=播放） |
| 19-32 | `qt_add_executable(...)` | **所有 .cpp 文件都要在这里注册** |
| 34-43 | `qt_add_qml_module(...)` | **所有 .qml 和 .js 文件都要在这里注册** |
| 50-55 | `WIN32_EXECUTABLE TRUE` | Windows 下不显示控制台窗口 |

**可以跳过**：Mac 相关的 `MACOSX_BUNDLE` 配置。

### 2.2 `src/main.cpp` — 程序的"出生证明"

**路径**：[src/main.cpp](../src/main.cpp)

**关注重点**：
| 行号 | 关注内容 | 知识点 |
|------|----------|--------|
| 30-33 | `QGuiApplication app(argc, argv)` | 创建 Qt 应用实例 —— 这是所有 Qt 程序的起点 |
| 36-38 | `setApplicationName(...)` | 设置应用元信息（QSettings 用它确定配置文件路径） |
| 42 | `QQuickStyle::setStyle("Fusion")` | 使用 Fusion 风格而非原生风格，这样才能自定义按钮外观 |
| 44-46 | `QQmlApplicationEngine` + `ApplicationContext` | 创建 QML 引擎和服务容器 |
| 49 | `applicationContext.initialize()` | **关键调用**：必须在 QML 加载前初始化所有服务 |
| 52 | `setContextProperty("applicationContext", &appCtx)` | **最核心的一行代码**：将 C++ 对象注入 QML |
| 63 | `engine.loadFromModule("cursor_music", "Main")` | 加载 QML 模块，启动 UI |
| 66 | `return app.exec()` | 进入事件循环（程序不会立刻退出，等待用户操作） |

**读完这一轮你应该理解**：
- Qt Quick 应用由 `main.cpp` 创建 C++ 对象，然后加载 QML 文件
- `setContextProperty` 是 C++ 和 QML 之间的唯一通道
- `app.exec()` 进入事件循环（事件=鼠标点击/网络响应/定时器等）

---

## 3. 第二轮：C++ 和 QML 是如何对话的

这一轮阅读 **ApplicationContext.h**，它是最重要的文件之一。所有 C++↔QML 通信都通过它。

### 3.1 `src/app/ApplicationContext.h` — C++ 和 QML 的"翻译官"

**路径**：[src/app/ApplicationContext.h](../src/app/ApplicationContext.h)

**关注重点**：
| 行号 | 关注内容 | 知识点 |
|------|----------|--------|
| 13-23 | `#include` 所有服务头文件 | **为什么.h 里要 include 这么多？** 因为 `Q_PROPERTY` 中提到的类型必须完整定义，MOC 才能生成正确的代码。这就是"前向声明"和"完整包含"的区别 |
| 43 | `class ApplicationContext : public QObject` | **必须继承 QObject**，否则 QML 无法访问 |
| 44 | `Q_OBJECT` | **注意大小写**，漏写会导致信号/Q_PROPERTY 全部失效 |
| 49-55 | `Q_PROPERTY(Type name READ getter ...)` | 把 C++ 成员暴露给 QML 的核心机制。`READ` 指定 getter，`CONSTANT` 表示值不会变 |
| 72-110 | 各种服务指针方法 | 依赖注入模式：ApplicationContext 是"管家"，不干具体的活，只是把各个服务连接起来 |
| 120 | `void initialize()` | 初始化顺序很重要：先加载 Cookie → 后挂载到网络管理器 |

**核心模式 — Q_PROPERTY 如何工作**：

```cpp
// 在 C++ 中声明
Q_PROPERTY(QString appName READ appName CONSTANT)
QString appName() const;

// 在 QML 中访问
Label { text: applicationContext.appName }
```

**读完这一轮你应该理解**：
- `Q_PROPERTY` = 把 C++ 变量变成 QML 可以直接读取的属性
- `Q_INVOKABLE` = 把 C++ 函数变成 QML 可以直接调用的方法
- `Q_OBJECT` 宏是 Qt 对象系统的基石

---

## 4. 第三轮：网络请求是怎么发出的

这一轮是 **网络层的基石**。推荐顺序：**HttpClient.h → HttpClient.cpp**。

### 4.1 `src/network/HttpClient.h` — HTTP 客户端的"说明书"

**路径**：[src/network/HttpClient.h](../src/network/HttpClient.h)

**关注重点**：
| 行号 | 关注内容 | 知识点 |
|------|----------|--------|
| 20-22 | 前向声明 `class QNetworkAccessManager` | **只在 .h 中用到指针/引用类型时**才用前向声明，减少编译依赖 |
| 51 | `class HttpClient : public QObject` | 继承 QObject 才能使用信号槽 |
| 66-77 | `struct Response` | 封装 HTTP 响应的所有信息（状态码 + 数据 + 错误信息） |
| 103 | `void get(const QUrl &url, int timeoutMs)` | 公开 API，只暴露必要参数 |
| 156 | `signal requestFinished(Response)` | **信号**：网络请求结束时对外通知。QML 端可以通过 `.connect()` 监听 |
| 175-177 | `sendRequest(...)` | **私有方法**：内部实现细节，外部不可见 |
| 206 | `QMap<QString, QString> m_defaultHeaders` | 默认请求头（UA, Referer），每次请求自动携带 |

### 4.2 `src/network/HttpClient.cpp` — HTTP 客户端的"实现"

**核心步骤**（按函数追踪即可）：

1. **构造函数**（~第15行）：创建 `QNetworkAccessManager` + 设置默认 UA 和 Referer
2. **`get()`**（~第40行）：调用 `sendRequest("GET")` → `handleReply`
3. **`sendRequest()`**（~第85行）：创建 `QNetworkRequest`，设置 URL + Headers，调用 `manager->get()` 或 `post()`
4. **`handleReply()`**（~第115行）：创建定时器控制超时，连接 `reply->finished` 信号，收到响应后构造 `Response` 并 emit

**关键知识点**：
- **超时控制**：`QTimer::singleShot` 在超时时 `reply->abort()`，因为 `QNetworkAccessManager` 本身不支持超时
- **生命周期管理**：`reply->deleteLater()` 和 `timer->deleteLater()` 依赖 Qt 的事件循环自动回收内存
- **B 站防爬**：必须设置 Chrome 的 User-Agent 和 `Referer: https://www.bilibili.com`

**读完这一轮你应该理解**：
- Qt 网络编程 = `QNetworkAccessManager` + `QNetworkRequest` + `QNetworkReply`
- 异步操作用**信号槽**通知结果，不用回调地狱
- `deleteLater()` 是 Qt 管理堆上对象的标准方式

---

## 5. 第四轮：数据是如何持久化的

**AppSettings**：用 QSettings 存配置（写 InI 文件）。**PersistentCookieJar**：继承 `QNetworkCookieJar`，把 Cookie 序列化到磁盘。

### 5.1 `src/storage/AppSettings.h` + `.cpp` — 应用配置

**路径**：[src/storage/AppSettings.h](../src/storage/AppSettings.h) | [src/storage/AppSettings.cpp](../src/storage/AppSettings.cpp)

**关注重点**：
- `QSettings("cursor_music", "cursor_music")` 会在 `%APPDATA%/cursor_music/` 下创建 InI 文件
- `setValue(key, value)` → 写磁盘，`value(key, default)` → 读磁盘
- `appDataPath()` 用 `QStandardPaths::writableLocation` 获取系统标准数据目录

### 5.2 `src/storage/PersistentCookieJar.h` + `.cpp` — Cookie 持久化

**路径**：[src/storage/PersistentCookieJar.h](../src/storage/PersistentCookieJar.h) | [src/storage/PersistentCookieJar.cpp](../src/storage/PersistentCookieJar.cpp)

**这是本项目中第一个使用 Qt 继承模式的类**，值得仔细阅读。

| 关注点 | 说明 |
|--------|------|
| 继承 `QNetworkCookieJar` | 重写父类的 Cookie 存取方法 |
| `load()` / `save()` | 用 `QDataStream` 读写二进制文件 |
| `QList<QByteArray>` | 替代 `QList<QNetworkCookie>` 序列化（因为 Qt 6.10 没有为 `QNetworkCookie` 实现流操作符） |
| `toRawForm()` / `parseCookies()` | Cookie 与字节数组互转 |
| `setCookieString()` | 解析浏览器导出的 `key=value; key2=value2` 格式（注意：如果用 `QNetworkCookie::parseCookies()` 会失败，因为那是 Set-Cookie 格式） |
| `clearCookies()` | 用 `setAllCookies(QList<QNetworkCookie>())` 清空所有 Cookie |
| `isLoggedIn()` | 检查是否包含 `SESSDATA` Cookie |

**读完这一轮你应该理解**：
- `QSettings` = Qt 内置的跨平台配置文件方案
- `QDataStream` 可以序列化任意 Qt 数据类型
- 继承 `QNetworkCookieJar` 并挂载到 `QNetworkAccessManager::setCookieJar()`，后续所有请求自动携带 Cookie

---

## 6. 第五轮：业务层是怎么调用 B 站 API 的

这一轮是业务的**核心链路**，推荐顺序：**BilibiliApiClient → AuthService → FavoriteService → MusicService → MediaResolver**。

### 6.1 `src/bilibili/BilibiliApiClient.h` + `.cpp` — B 站 API 封装

**路径**：[src/bilibili/BilibiliApiClient.h](../src/bilibili/BilibiliApiClient.h) | [src/bilibili/BilibiliApiClient.cpp](../src/bilibili/BilibiliApiClient.cpp)

**核心模式**：每个 API 方法接受一个 callback lambda，内部调用 `HttpClient::get/post()`。

```
getNavInfo() → httpClient.get(url) → replyFinished(Response) → callback(success, json, error)
```

**重点关注**：
- **WBI 签名**（`signWbi()`）：B 站的防爬机制，用 `mixinkey` + MD5 对请求参数签名
- **getMusicRank()**：先获取热门榜单列表，再逐个获取每个榜单的内容
- **getVideoPlayUrl()**：只取 `dash.audio[0].baseUrl`（音频流），因为本项目是音乐客户端
- **信号命名**：用 callback lambda 而不是信号，因为同一个方法会被多个页面调用

### 6.2 `src/auth/AuthService.h` + `.cpp` — 登录认证

**路径**：[src/auth/AuthService.h](../src/auth/AuthService.h) | [src/auth/AuthService.cpp](../src/auth/AuthService.cpp)

**关注重点**：
| 行/概念 | 知识点 |
|---------|--------|
| `Q_PROPERTY(bool isLoggedIn ...)` | 登录状态变化通过 `NOTIFY loginStateChanged` 通知 QML |
| `importCookie(cookieString)` | 解析 Cookie 字符串 → 写入 CookieJar → 调用 `getNavInfo()` 验证 → 根据返回的 `uname` 是否为空判断登录成功 |
| `logout()` | 清空 CookieJar → 立即保存 → emit `loginStateChanged` |
| `Q_INVOKABLE` | 标记为 Q_INVOKABLE 的方法可从 QML 中直接调用 |

### 6.3 `src/bilibili/FavoriteService.h` + `.cpp` — 收藏夹

**路径**：[src/bilibili/FavoriteService.h](../src/bilibili/FavoriteService.h) | [src/bilibili/FavoriteService.cpp](../src/bilibili/FavoriteService.cpp)

**关注重点**：
- 数据以 **JSON 字符串** 形式传给 QML（因为 QML 能直接 `JSON.parse`）
- 分页加载：`loadFavoriteResources(mediaId, page, pageSize)` 支持翻页
- 返回三个信号参数：`infoJson`（收藏夹信息）、`mediasJson`（资源列表）、`hasMore`（是否有更多页）

### 6.4 `src/bilibili/MusicService.h` + `.cpp` — 音乐热门榜

**路径**：[src/bilibili/MusicService.h](../src/bilibili/MusicService.h) | [src/bilibili/MusicService.cpp](../src/bilibili/MusicService.cpp)

**关注重点**：
- 数据结构扁平化：将 API 返回的"榜单→音频"层级结构压扁为单个列表
- 每个音频项附加榜单封面和 UP 主信息（`chartCover`, `chartUname`）作为卡片展示
- 用 `QJsonDocument::toJson(Compact)` 序列化为紧凑字符串

### 6.5 `src/player/MediaResolver.h` + `.cpp` — 媒体地址解析

**路径**：[src/player/MediaResolver.h](../src/player/MediaResolver.h) | [src/player/MediaResolver.cpp](../src/player/MediaResolver.cpp)

**关注重点**：
- `resolve(id, type)`：根据 type 决定调用哪个 API（12=音频流, 2=视频）
- 视频流程：`getVideoCid(bvid)` → `getVideoPlayUrl(bvid, cid)` → 取 `dash.audio[0].baseUrl`
- 解析完成后 emit `mediaResolved(success, url, ...)` 信号

**读完这一轮你应该理解**：
- 业务服务层 = 调用 API 客户端 + 处理返回数据 + 发射信号给 UI
- JSON 是 C++ 和 QML 之间传递复杂数据的通用格式
- 分层职责清晰：ApiClient 只管发请求，Service 处理业务逻辑

---

## 7. 第六轮：音乐是怎样从服务器到扬声器的

这可能是**平台最显的部分**，也是技术含量最高的一轮。

### 7.1 `src/player/PlayerController.h` + `.cpp` — 音频播放器

**路径**：[src/player/PlayerController.h](../src/player/PlayerController.h) | [src/player/PlayerController.cpp](../src/player/PlayerController.cpp)

**核心架构**：
```
setSource(url)
  → QNetworkAccessManager 下载音频（带 UA + Referer）   ← 解决 403！
  → 数据写入 QBuffer（内存中）                           ← 解决 QMediaPlayer 无法直接设置请求头
  → QMediaPlayer.setSourceDevice(buffer)                 ← 从内存播放
  → QAudioOutput 输出到扬声器
```

**为什么这么复杂？**

| 问题 | 为什么 | 解决方案 |
|------|--------|----------|
| 403 Forbidden | B 站 CDN 要求正确的 HTTP Header，但 `QMediaPlayer` 通过 FFmpeg 后端发送的请求不包含这些 Header | 先用 `QNetworkAccessManager`（可设 Header）下载到内存 |
| `setSourceDevice(QNetworkReply*)` 不可用 | `QNetworkReply` 是增量读取的，不支持 seek | 等待全部下载完成后写入 `QBuffer`，再设置 sourceDevice |

**重点关注**：
- `Q_PROPERTY` 驱动的 UI 更新：position/duration 变化时通过 `NOTIFY` 信号自动更新 QML 进度条
- `setVolume(qreal vol)`：QML 的 Slider 值 (0-100) → 音量 (0.0-1.0)
- `seek(int positionMs)`：拖动进度条时调用
- `onStateChanged()` / `onErrorOccurred()`：监听 QMediaPlayer 状态变化

**核心模式 — Q_PROPERTY 驱动的数据绑定**：
```
C++ position 变化 → emit positionChanged → QML 自动重新计算进度条宽度
```

**读完这一轮你应该理解**：
- `QMediaPlayer` + `QAudioOutput` = Qt 6 的标准音频播放方案
- HTTP 音频流不能直接给 QMediaPlayer，需要先下载（因为有鉴权 Header）
- `QBuffer` 是内存中的"文件"，可以让 QMediaPlayer 像读本地文件一样播放
- 音量、进度、播放状态的 QML 绑定都是通过 `Q_PROPERTY` + `NOTIFY` 实现的

---

## 8. 第七轮：QML 界面是怎么做的

这一轮读 QML 文件，顺序：**Theme.js → Main.qml → Sidebar.qml → 各页面**。

### 8.1 `qml/components/Theme.js` — 全局样式系统

**路径**：[qml/components/Theme.js](../qml/components/Theme.js)

**关注重点**：
- `.pragma library`：确保 JS 文件在全局只加载一次（类似单例模式）
- 色板、字号、间距、圆角等全部集中定义
- 任何 QML 文件通过 `import "components/Theme.js" as Theme` 引入，然后用 `Theme.colors.accent`

**为什么用 .js 而不是 .qml 单例？**
> Qt 6.10 的 `pragma Singleton` 在某些构建配置下不工作，而 `.pragma library` 是 JavaScript 标准语法，始终有效。

### 8.2 `qml/Main.qml` — 窗口框架（三栏布局）

**路径**：[qml/Main.qml](../qml/Main.qml)

**关注重点**：
| 行号 | 关注内容 | 知识点 |
|------|----------|--------|
| 8 | `import "components/Theme.js" as Theme` | 引入样式常量 |
| 10 | `ApplicationWindow { ... }` | 顶层窗口容器 |
| 17 | `property var _pc: null` | 定义本地变量，稍后绑定到 C++ 对象 |
| 19-21 | `Component.onCompleted: Qt.callLater(...)` | **关键模式**：用 `Qt.callLater` 延迟执行，等 `applicationContext` 准备好后再绑定 |
| 23-30 | `RowLayout` → `Sidebar` + 内容区 | 左右分栏布局 |
| 39-46 | `StackLayout { currentIndex: sidebar.currentIndex }` | 根据侧栏选中项切换页面 |
| 48-160 | 底部播放栏 | 封面 + 标题 + 播放按钮 + 进度条（含时间标签） + 音量滑块 |
| 110-120 | 进度条时间计算 | `Math.floor(position/1000)` 转为秒，手动格式化为 `MM:SS` |
| 131-134 | 进度条填充 | `parent.width * (position / duration)` 实时计算蓝色条宽度 |

### 8.3 `qml/components/Sidebar.qml` — 左侧导航栏

**路径**：[qml/components/Sidebar.qml](../qml/components/Sidebar.qml)

**关注重点**：
- `Repeater + model: [...]` 动态生成导航项
- `sidebar.currentIndex === index` 高亮当前选中项
- `MouseArea { hoverEnabled: true }` + `Behavior on color` 实现悬停动画
- `applicationContext.authService.isLoggedIn` 控制用户信息区域的显示

### 8.4 `qml/pages/HomePage.qml` — 首页音乐热门卡片

**路径**：[qml/pages/HomePage.qml](../qml/pages/HomePage.qml)

**关注重点**：
- `musicRankLoaded` 信号连接：`svc.musicRankLoaded.connect(function(success, json, error) { ... })`
- `JSON.parse(json)` 将 C++ 传来的 JSON 字符串转为 JS 数组
- 3 列 `GridLayout` 自动换行
- 卡片点击 → 调用 `mediaResolver.resolve(id, type)` → `setMediaTitle/MediaCover` → 播放

### 8.5 `qml/pages/FavoritesPage.qml` — 收藏夹

**核心模式**：两状态页面。
- 状态 1：显示收藏夹列表（folder list）
- 状态 2：点击某个收藏夹后，显示该收藏夹内的资源列表
- `favoriteResourcesLoaded` 信号包含 `hasMore` 参数，支持加载更多

### 8.6 `qml/pages/LoginPage.qml` — Cookie 登录

最简单的页面。一个文本框输入 Cookie → 点击登录按钮 → 调用 `authService.importCookie(text)`。

**读完这一轮你应该理解**：
- `Qt.callLater()` 是 QML 中最干净的异步延迟执行方式
- `signal.connect(function(){})` 替代了旧的 `Connections {}` 写法
- `Repeater.model[index]` 是 Qt 6.10 中访问委托模型数据的标准模式
- `.pragma library` JS 文件是跨 QML 共享常量的推荐方式
- 深色主题的定义：所有颜色/字号/间距集中在一处

---

## 9. 进阶：读完源码后还可以学什么

### 9.1 可以进一步改造的点（练习建议）

| 改造方向 | 难度 | 涉及哪些文件 |
|----------|------|-------------|
| 支持 `.m3u8` 直播流播放 | 中 | PlayerController, MediaResolver |
| 增加搜索功能（调用 B 站搜索 API） | 中 | 新增 SearchPage.qml, SearchService |
| 播放列表 / 播放队列 | 低 | PlayerController（加 QList<QUrl> 队列）|
| 本地收藏（不依赖 B 站账号）| 中 | AppSettings（存本地 SQLite）|
| 歌词显示（解析 LRC/调用 B 站歌词 API）| 高 | 新增 LyricService, LyricPage.qml |
| 暗/亮主题切换 | 低 | Theme.js（加一份亮色色板）|

### 9.2 该项目体现的通用模式（可迁移到其他 Qt 项目）

1. **依赖注入容器**（ApplicationContext）：管理对象生命周期和依赖关系
2. **网络层封装**（HttpClient）：所有 HTTP 请求的单一入口，便于统一设置 Header/日志/重试
3. **C++↔QML 通信**：Q_PROPERTY + Q_INVOKABLE + signal + JSON 字符串
4. **持久化**：QSettings（配置）+ QDataStream（Cookie 二进制）+ SQLite（可扩展方式）
5. **多媒体**：下载到内存 → QBuffer → QMediaPlayer（绕过 Header 鉴权）

### 9.3 推荐阅读的 Qt 官方文档

| 主题 | 文档链接 |
|------|----------|
| Q_PROPERTY 详解 | Qt 文档 → The Property System |
| 信号与槽 | Qt 文档 → Signals & Slots |
| QML 与 C++ 集成 | Qt 文档 → Overview - QML and C++ Integration |
| QNetworkAccessManager | Qt 文档 → Network Programming with Qt |
| QMediaPlayer | Qt 文档 → Multimedia |
| QML Repeater | Qt 文档 → QML Repeater |

---

## 10. 常见坑点速查表

| 症状 | 原因 | 解决方案 | 相关文件 |
|------|------|----------|----------|
| QML 中 `applicationContext.xxx` 为 undefined | 时间序：QML 加载太快，C++ 还没 setContextProperty | 用 `Qt.callLater()` 延迟访问 | Main.qml:19 |
| QML 中 `modelData is not defined` | Qt 6.10 不再自动注入 modelData 到 Repeater 代理作用域 | 用 `repeater.model[index]` 模式 | Sidebar.qml, FavoritesPage.qml |
| 播放音频时返回 403 | QMediaPlayer(FFmpeg) 不发送自定义 HTTP Header | 先用 QNetworkAccessManager 下载到 QBuffer | PlayerController.cpp |
| Cookie 登录后显示"未登录" | Cookie 字符串格式不匹配（浏览器导出的是 Cookie header，非 Set-Cookie） | 手动解析 `key=value;` 格式 | PersistentCookieJar.cpp |
| 视频播放没有声音 | `dash.video[0].baseUrl` 是纯视频流（DASH 格式音视频分离） | 改为取 `dash.audio[0].baseUrl` | BilibiliApiClient.cpp |
| GridLayout 卡片重叠 | ScrollView 内 GridLayout 初始宽度计算为 0 | 用固定像素值计算列宽 `(900 - padding - gap) / 3` | HomePage.qml:37 |
| Theme.js 在 QML 中无法访问 | JS 文件未加入 `qt_add_qml_module(QML_FILES ...)` | 在 CMakeLists.txt 中添加 Theme.js | CMakeLists.txt:39 |
| Button 自定义背景不生效 | 需要 Fusion 风格覆盖原生控件样式 | `QQuickStyle::setStyle("Fusion")` | main.cpp:42 |
| `setVolume not a function` | C++ 方法未标记 Q_INVOKABLE | 添加 Q_INVOKABLE 宏 | PlayerController.h:48 |
| 编译错误 "incomplete type QNetworkAccessManager" | .cpp 文件中未包含完整头文件 | `#include <QNetworkAccessManager>` | ApplicationContext.cpp |

---

## 附录：完整源码阅读顺序一览

```
第 0 步：看全景
  └─ 阅读本文档的"架构速览"图表

第 1 步：启动流程（2 文件）
  ├─ CMakeLists.txt          ← 先搞清楚怎么编译
  └─ src/main.cpp             ← 看看 main() 里发生了什么

第 2 步：C++ ↔ QML 桥梁（2 文件）
  ├─ src/app/ApplicationContext.h  ← 核心！理解 Q_PROPERTY / setContextProperty
  └─ src/app/ApplicationContext.cpp

第 3 步：网络层（4 文件）
  ├─ src/network/HttpClient.h       ← 理解 Response 结构和请求流程
  ├─ src/network/HttpClient.cpp
  ├─ src/storage/PersistentCookieJar.h  ← 理解 Cookie 持久化
  └─ src/storage/PersistentCookieJar.cpp

第 4 步：持久化（2 文件，简单）
  ├─ src/storage/AppSettings.h
  └─ src/storage/AppSettings.cpp

第 5 步：B 站 API 业务层（10 文件）
  ├─ src/bilibili/BilibiliApiClient.h     ← 先看 API 客户端怎么工作的
  ├─ src/bilibili/BilibiliApiClient.cpp
  ├─ src/auth/AuthService.h               ← 登录是怎么实现的
  ├─ src/auth/AuthService.cpp
  ├─ src/bilibili/FavoriteService.h       ← 收藏夹数据怎么获取
  ├─ src/bilibili/FavoriteService.cpp
  ├─ src/bilibili/MusicService.h          ← 音乐热门榜
  ├─ src/bilibili/MusicService.cpp
  ├─ src/player/MediaResolver.h           ← 播放地址怎么解析
  └─ src/player/MediaResolver.cpp

第 6 步：播放器（2 文件，最复杂）
  ├─ src/player/PlayerController.h        ← 理解 403 问题的解决方案
  └─ src/player/PlayerController.cpp

第 7 步：QML 界面（7 文件）
  ├─ qml/components/Theme.js              ← 样式常量
  ├─ qml/Main.qml                         ← 窗口框架、播放栏
  ├─ qml/components/Sidebar.qml           ← 导航栏
  ├─ qml/pages/HomePage.qml               ← 首页卡片
  ├─ qml/pages/FavoritesPage.qml          ← 收藏夹（两状态页面）
  └─ qml/pages/LoginPage.qml              ← 登录页
```

---

**祝阅读愉快！** 有任何不理解的代码，可以配合 [project-architecture.md](project-architecture.md) 一起看，后者有每个文件的详细中文注释。
