# Bilibili Music Client — 项目架构与开发文档

> **适合读者**：任何有一定 C++ 基础的开发者，即使从未用过 Qt/QML，也能通过本文档理解整个项目。

---

## 一、项目概述

### 1.1 这是什么？

一个基于 **Qt 6 + C++17 + QML** 的桌面端 B站（Bilibili）音乐客户端。可以：
- 通过 Cookie 登录 B站账号
- 浏览自己的收藏夹和收藏内容
- 播放收藏夹中的音频和视频的音频轨

### 1.2 为什么要做这个？

B站有丰富的音乐和音频内容（翻唱、原创音乐、播客等），但官方没有专门的桌面音乐客户端。这个项目填补了这个空白。

### 1.3 技术亮点（简历可写）

| 亮点 | 体现的能力 |
|------|-----------|
| C++17 + Qt 6 跨平台桌面应用 | 现代 C++、大型框架使用 |
| QML 声明式 UI（网易云风格三段式布局） | 前端/UI 开发能力 |
| 自定义持久化 Cookie 存储 | 数据序列化、文件 I/O |
| QNetworkAccessManager HTTP 客户端封装 | 网络编程 |
| B站 REST API 对接（含 WBI 签名） | 第三方 API 集成 |
| QMediaPlayer + FFmpeg 音频播放 | 多媒体编程 |
| 异步信号槽架构全链路 | 异步编程、事件驱动 |
| DASH 音频流提取播放 | 协议/格式理解 |
| CMake 构建系统 | 构建工具链 |
| Q_INVOKABLE + Q_PROPERTY C++/QML 互操作 | 跨语言调用 |

---

## 二、技术栈

| 层级 | 技术 | 说明 |
|------|------|------|
| **语言** | C++17 + QML | 业务逻辑用 C++，UI 用声明式 QML |
| **框架** | Qt 6.10.2 | 包含 Quick、Network、Multimedia 等模块 |
| **构建** | CMake 3.21+ | 现代 CMake，`qt_add_qml_module` |
| **编译器** | MinGW 13.1.0 64-bit | Windows 优先 |
| **多媒体** | Qt Multimedia (FFmpeg 7.1.2) | 音视频解码播放 |
| **版本控制** | Git | 当前分支 `master` |

### 启用的 Qt 模块

| 模块 | 作用 |
|------|------|
| `Qt6::Quick` | QML 引擎，解析和运行 .qml 文件 |
| `Qt6::QuickControls2` | 按钮(Button)、滑块(Slider)、布局(Layout)等标准控件 |
| `Qt6::Network` | QNetworkAccessManager — 发送 HTTP 请求 |
| `Qt6::Multimedia` | QMediaPlayer/QAudioOutput — 播放音频 |
| `Qt6::Svg` | SVG 图标（预留） |

---

## 三、目录结构

```
cursor_music/
├── CMakeLists.txt                  # 构建配置：源文件列表 + Qt 模块 + 链接库
├── .gitignore                      # 忽略 build/、*.exe、缓存等
│
├── src/                            # ===== C++ 源码 =====
│   ├── main.cpp                    # 程序入口：初始化 QML 引擎 + 注入 context
│   ├── app/                        # 应用层：服务容器
│   │   ├── ApplicationContext.h    # 全局上下文：持有所有服务对象
│   │   └── ApplicationContext.cpp  # 服务创建 + 初始化
│   ├── network/                    # 网络层
│   │   ├── HttpClient.h            # 通用 HTTP 客户端
│   │   └── HttpClient.cpp          # GET/POST/超时/Header
│   ├── storage/                    # 存储层
│   │   ├── AppSettings.h/.cpp      # 应用配置（QSettings INI 格式）
│   │   └── PersistentCookieJar.h/.cpp  # Cookie 磁盘持久化
│   ├── bilibili/                   # B站 API 层
│   │   ├── BilibiliApiClient.h/.cpp    # B站 REST API 封装
│   │   └── FavoriteService.h/.cpp      # 收藏夹业务逻辑
│   ├── auth/                       # 认证层
│   │   └── AuthService.h/.cpp      # 登录/退出/Cookie导入
│   └── player/                     # 播放器层
│       ├── PlayerController.h/.cpp     # 封装 QMediaPlayer+QAudioOutput
│       └── MediaResolver.h/.cpp        # 音频/视频 URL 解析
│
├── qml/                            # ===== QML 界面 =====
│   ├── Main.qml                    # 主窗口（三段式布局）
│   ├── components/
│   │   ├── Sidebar.qml             # 左侧导航栏
│   │   └── Theme.js                # 主题常量（颜色/字体/间距）
│   └── pages/
│       ├── HomePage.qml            # 首页概览
│       ├── FavoritesPage.qml       # 收藏夹页面
│       └── LoginPage.qml           # 登录页面
│
├── docs/                           # ===== 文档 =====
│   ├── project-architecture.md     # 本架构文档
│   └── project-structure.md        # 简洁版结构说明
│
└── 哔哩哔哩API/bili-apis/          # B站 API 参考资料（不参与构建）
    └── docs/login/, fav/, audio/, video/  # 各接口文档
```

---

## 四、整体架构

### 4.1 分层设计

```
┌──────────────────────────────────────────────────────────┐
│  QML 界面层（qml/）                                       │
│  Main.qml / Sidebar.qml / LoginPage.qml / FavoritesPage  │
│  通过 applicationContext 访问所有 C++ 服务                 │
├──────────────────────────────────────────────────────────┤
│  C++ 服务层（src/app/ApplicationContext）                 │
│  依赖注入容器，持有并管理所有服务的生命周期                   │
├──────────────┬──────────────┬──────────────┬─────────────┤
│  auth/       │  bilibili/   │  player/     │  storage/   │
│  AuthService │  ApiClient   │  PlayerCtrl  │  AppSettings│
│  登录/退出    │  收藏夹API   │ 音频播放     │  CookieJar │
│  Cookie导入   │  FavoriteSvc│  MediaResolv │ 配置存储    │
├──────────────┴──────────────┴──────────────┴─────────────┤
│  network/HttpClient                                       │
│  QNetworkAccessManager 封装（GET/POST/超时/Header）       │
└──────────────────────────────────────────────────────────┘
```

### 4.2 数据流（用户点击播放一首歌的完整过程）

```
用户点击收藏夹中的音频条目
  │
  ├─→ FavoritesPage.qml (onClicked)
  │     ├─ playerController.mediaTitle  = "歌曲名"
  │     ├─ playerController.mediaCover  = "封面URL"
  │     └─ mediaResolver.resolve(id, type=12)
  │           │
  │           └─→ MediaResolver::resolve()
  │                 └─→ BilibiliApiClient::getAudioStreamUrl(id)
  │                       │
  │                       ├─→ HttpClient::get("https://.../web/url?sid=xxx")
  │                       │   自动携带 PersistedCookieJar 中的 Cookie
  │                       │   自动设置 User-Agent 和 Referer
  │                       │
  │                       ├─→ B站 CDN 返回音频 URL
  │                       │
  │                       └─→ mediaResolved 信号
  │
  └─→ FavoritesPage.qml (onMediaResolved 回调)
        └─→ playerController.source = url
              │
              ├─→ QNetworkAccessManager::get(url)
              │   User-Agent: Chrome/120
              │   Referer: https://www.bilibili.com
              │
              ├─→ 数据下载完成 → QBuffer(内存)
              │
              ├─→ m_player->setSourceDevice(buffer)
              │
              ├─→ FFmpeg 解码 → 音频输出
              │
              └─→ positionChanged 信号 → 进度条走动
                  VolumeControl → 音量调节
                  Play/Pause → 播放控制
```

---

## 五、C++ 与 QML 交互详解

### 5.1 四种交互方式

#### 方式一：上下文属性注入

在 `main.cpp` 中把 C++ 对象注册为 QML 全局变量：

```cpp
// main.cpp
ApplicationContext applicationContext;
engine.rootContext()->setContextProperty("applicationContext", &applicationContext);
engine.loadFromModule("cursor_music", "Main");
```

QML 中直接使用：
```qml
Label { text: applicationContext.qtVersion }  // 显示 Qt 版本号
```

#### 方式二：Q_PROPERTY 暴露属性

```cpp
// ApplicationContext.h
Q_PROPERTY(AuthService *authService READ authService CONSTANT)
Q_PROPERTY(PlayerController *playerController READ playerController CONSTANT)
```

CONSTANT 表示属性值不变（对象指针不变），QML 引擎会缓存结果。

#### 方式三：Q_INVOKABLE 暴露方法

```cpp
// AuthService.h
Q_INVOKABLE void importCookie(const QString &cookieString);
// PlayerController.h
Q_INVOKABLE void play();
Q_INVOKABLE void pause();
```

QML 中调用：
```qml
Button {
    onClicked: applicationContext.authService.importCookie(cookieText)
}
```

#### 方式四：信号连接（Signal → QML 回调）

```cpp
// C++ 定义信号
signals:
    void favoriteFoldersLoaded(bool success, QString json, QString error);
```

QML 中连接（使用 Component.onCompleted + Qt.callLater 确保初始化时序正确）：
```qml
Component.onCompleted: Qt.callLater(function() {
    applicationContext.favoriteService.favoriteFoldersLoaded.connect(
        function(success, json, error) {
            folderModel = JSON.parse(json)
        }
    )
})
```

### 5.2 为什么用 Qt.callLater？

QML 组件初始化时，`applicationContext` 上下文属性可能尚未就绪。`Qt.callLater` 将回调推迟到事件循环的下一次迭代，确保 `applicationContext` 已可用。

---

## 六、核心模块详解

### 6.1 ApplicationContext（服务容器）

**位置**：`src/app/ApplicationContext.h/.cpp`

**设计思想**：依赖注入容器。所有服务对象在构造函数中创建，ApplicationContext 作为它们的 Qt 父对象管理生命周期。当 ApplicationContext 被销毁时（程序退出），所有子对象自动释放。

```cpp
ApplicationContext::ApplicationContext(QObject *parent) : QObject(parent)
    , m_settings(new AppSettings(this))      // 阶段一
    , m_cookieJar(new PersistentCookieJar(this))
    , m_httpClient(new HttpClient(this))
    , m_bilibiliApiClient(new BilibiliApiClient(m_httpClient, this))  // 阶段二
    , m_authService(new AuthService(m_cookieJar, m_bilibiliApiClient, this))
    , m_favoriteService(new FavoriteService(m_bilibiliApiClient, this))
    , m_mediaResolver(new MediaResolver(m_bilibiliApiClient, this))
    , m_playerController(new PlayerController(this))
{}
```

初始化顺序至关重要：
1. `load()` Cookie（如果先请求 API 后加载 Cookie，会导致首次请求不带 Cookie）
2. `setCookieJar()` 关联到网络管理器（使所有 HTTP 请求自动携带 Cookie）
3. `checkLogin()` 验证已有 Cookie 是否仍然有效

### 6.2 HttpClient（HTTP 客户端）

**位置**：`src/network/HttpClient.h/.cpp`

**为什么需要封装？**
- 统一超时控制（QTimer，默认 15 秒）
- 自动设置 B站 API 必需的 Header（User-Agent、Referer）
- 统一错误处理和 JSON 解析

**核心结构体**：
```cpp
struct Response {
    int statusCode;      // HTTP 状态码（200/403/404/500）
    QByteArray body;     // 原始响应体
    bool success;        // 网络层是否成功
    QString errorString; // 网络错误描述
    QJsonObject json();  // 便捷 JSON 解析
    bool isHttpOk();     // 状态码是否 2xx
};
```

**超时机制**：
```cpp
QTimer *timer = new QTimer(reply);        // 定时器挂到 reply 上
timer->setSingleShot(true);               // 只触发一次
timer->setInterval(timeoutMs);            // 超时时间
connect(timer, &QTimer::timeout, reply, [reply]() {
    reply->abort();                       // 超时后取消请求
});
```

### 6.3 PersistentCookieJar（Cookie 持久化）

**位置**：`src/storage/PersistentCookieJar.h/.cpp`

**为什么需要？** Qt 的 `QNetworkCookieJar` 只在内存中保存 Cookie，程序退出即丢失。需要持久化到磁盘，下次启动自动恢复登录态。

**存储路径**：`%APPDATA%/cursor_music/cookies.dat`

**序列化方案**：
```
保存：Cookie → toRawForm() → QByteArray → QList<QByteArray> → QDataStream → 文件
加载：文件 → QDataStream >> QList<QByteArray> → parseCookies() → Cookie
```

为什么不直接用 QDataStream 序列化 QNetworkCookie？
- Qt 6.10 中 QNetworkCookie 没有流操作符，需要用中间格式 QByteArray 桥接

**浏览器 Cookie 导入**：用户从 Chrome 开发者工具复制的 Cookie 格式是 `key=value; key2=value2`（请求头格式），而非 `Set-Cookie` 格式。需要手动按分号分割并逐对创建 QNetworkCookie：
```cpp
void PersistentCookieJar::setCookieString(const QString &cookieString) {
    const auto parts = cookieString.split(';');
    for (const auto &part : parts) {
        int eqPos = part.indexOf('=');
        if (eqPos > 0) {
            QString name = part.left(eqPos).trimmed();
            QString value = part.mid(eqPos + 1).trimmed();
            QNetworkCookie cookie(name.toUtf8(), value.toUtf8());
            cookie.setDomain(".bilibili.com");  // 匹配 api.bilibili.com
            cookie.setPath("/");
            insertCookie(cookie);
        }
    }
    save();
}
```

### 6.4 AuthService（登录认证）

**位置**：`src/auth/AuthService.h/.cpp`

**暴露给 QML 的属性**：`isLoggedIn`、`userName`、`userAvatar`、`userMid`

**登录验证**：调用 `BilibiliApiClient::getNavInfo()` → B站 `/x/web-interface/nav` 接口。如果返回 `code=0` 且 `data.isLogin=true`，说明 Cookie 有效。

```cpp
void AuthService::checkLogin() {
    m_apiClient->getNavInfo([this](bool success, QJsonObject data, QString) {
        if (success && data.value("isLogin").toBool()) {
            m_isLoggedIn = true;
            m_userName = data.value("uname").toString();
            m_userAvatar = data.value("face").toString();
        } else {
            m_isLoggedIn = false;
        }
        emit loginStateChanged();
    });
}
```

### 6.5 BilibiliApiClient（B站 API 封装）

**位置**：`src/bilibili/BilibiliApiClient.h/.cpp`

**封装的接口**：

| 方法 | B站接口 | 用途 |
|------|---------|------|
| `getNavInfo()` | `x/web-interface/nav` | 登录态验证 |
| `getFavoriteFolderList(mid)` | `v3/fav/folder/created/list-all` | 收藏夹列表 |
| `getFavoriteResourceList(id, page, size)` | `v3/fav/resource/list` | 收藏夹内容 |
| `getAudioStreamUrl(audioId)` | `audio/music-service-c/web/url` | 音频播放地址 |
| `getVideoPlayUrl(bvid, cid)` | `player/wbi/playurl` | 视频播放地址 |
| `getVideoCid(bvid)` | `x/web-interface/view` | 获取视频 cid |

**WBI 签名算法**：B站 `player/wbi/playurl` 接口需要 WBI 签名。算法步骤：
1. 从 nav 接口的 `wbi_img` 中提取 `img_key` 和 `sub_key`
2. 按固定映射表 `MIXIN_KEY_ENC_TAB` 重排得到 `mixin_key`（前 32 位）
3. 对请求参数按键排序，拼接 `key=value&...` 字符串
4. 追加 `mixin_key`，计算 MD5 得到 `w_rid`
5. 在请求中携带 `w_rid` + `wts`（时间戳）

### 6.6 FavoriteService（收藏夹服务）

**位置**：`src/bilibili/FavoriteService.h/.cpp`

**职责**：将 B站 API 返回的 JSON 数据通过信号传递给 QML。

```cpp
// QML 可调用的方法
Q_INVOKABLE void loadFavoriteFolders(qint64 upMid);
Q_INVOKABLE void loadFavoriteResources(qint64 mediaId, int page, int pageSize);

// 给 QML 的信号（携带 JSON 字符串）
signals:
    void favoriteFoldersLoaded(bool success, QString json, QString error);
    void favoriteResourcesLoaded(bool success, QString infoJson,
                                  QString mediasJson, bool hasMore, QString error);
```

为什么要传 JSON 字符串而不是直接传 C++ 对象？
- QML 的 JavaScript 引擎可以原生解析 JSON
- 避免 C++ 与 QML 之间的复杂类型转换

### 6.7 PlayerController（播放器）

**位置**：`src/player/PlayerController.h/.cpp`

**核心组件**：
- `QMediaPlayer` — 解码和播放控制
- `QAudioOutput` — 音量控制
- `QNetworkAccessManager` — 发送带 Header 的 HTTP 请求
- `QBuffer` — 内存缓冲区，存储下载的音频数据

**为什么不能直接用 `setSource(url)`？**

B站 CDN 的音频/视频 URL 需要携带 `User-Agent` 和 `Referer` 请求头。Qt 6.10 的 QMediaPlayer（FFmpeg 后端）不支持设置自定义 HTTP Header。直接用 `setSource(url)` 会收到 HTTP 403 Forbidden。

**解决方案**：
1. 用 `QNetworkAccessManager` 发送带正确 Header 的 GET 请求
2. 将返回的音频数据读入 `QByteArray`
3. 创建 `QBuffer` 包装数据（内存缓冲区，支持 seek）
4. 用 `m_player->setSourceDevice(buffer)` 播放

```cpp
void PlayerController::setSource(const QString &url) {
    QNetworkRequest request(QUrl(url));
    request.setRawHeader("User-Agent", "Mozilla/5.0 ... Chrome/120 ...");
    request.setRawHeader("Referer", "https://www.bilibili.com");

    QNetworkReply *reply = m_nam->get(request);
    connect(reply, &QNetworkReply::finished, [this, reply]() {
        QByteArray data = reply->readAll();
        m_mediaBuffer = new QBuffer(this);
        m_mediaBuffer->setData(data);
        m_mediaBuffer->open(QIODevice::ReadOnly);
        m_player->setSourceDevice(m_mediaBuffer, QUrl());
    });
}
```

**DASH 音频流提取**：B站视频使用 DASH 格式，视频流和音频流是分开的 URL。作为音乐客户端，我们只需要音频流：
```
dash.video[0].baseUrl  →  只有画面，没声音  ✗
dash.audio[0].baseUrl  →  纯音频轨         ✓
```

### 6.8 AppSettings（配置存储）

**位置**：`src/storage/AppSettings.h/.cpp`

使用 Qt 的 `QSettings`，以 INI 格式存储在 `%APPDATA%/cursor_music/cursor_music.ini`。支持分层键名（如 `"player/volume"`）。

### 6.9 Theme.js（主题常量）

**位置**：`qml/components/Theme.js`

`.pragma library` JavaScript 文件，确保全局只加载一次。集中管理所有视觉常量：
- `Theme.colors.xxx`：18 个主题色（accent/bgCard/textPrimary 等）
- `Theme.fontSizes.xxx`：7 级字号（h1=28/caption=13 等）
- `Theme.spacing.xxx`：6 级间距（page=24/tight=4 等）
- `Theme.radius.xxx`：圆角（card=12/pill=20 等）

---

## 七、遇到的坑和解决方案

| 问题 | 原因 | 解决方案 |
|------|------|---------|
| 程序启动时 `applicationContext` 为 null | QML 绑定在 C++ context property 设置前求值 | `Qt.callLater()` 延迟初始化 |
| `Connections` 属性弃用警告 | Qt 6.10 要求新语法 | 改用 `signal.connect(function(){})` |
| QML Repeater 模型数据不注入 | Qt 6.10 数组模型不自动注入 `modelData` | 用 `repeater.model[index]` 直接访问 |
| `Q_PROPERTY` 前向声明编译错误 | MOC 需要完整类型定义 | 在头文件中 include 完整头文件 |
| `setAllCookies` 是 protected 方法 | QNetworkCookieJar 设计限制 | 添加 `clearCookies()` 公开包装方法 |
| 音频播放 403 Forbidden | QMediaPlayer 不发送自定义 HTTP Header | QNetworkAccessManager 下载后 Buffer 播放 |
| DASH 视频播放只有画面没声音 | 取了视频流没取音频流 | 改为取 `dash.audio[0].baseUrl` |
| `setSourceDevice(QNetworkReply*)` 不工作 | QNetworkReply 非 seekable | 全量下载到 QBuffer 后再播放 |
| Theme.qml 单例不被识别 | `pragma Singleton` 构建系统未处理 | 改用 `.js` pragma library |
| `font.monospace` 属性不存在 | QML Font 类型无此属性 | 改用 `font.family: "Consolas"` |

---

## 八、构建与运行

### 系统要求

- Windows 10/11
- Qt 6.10.2（MinGW 64-bit）
- CMake 3.16+
- 编译器：MinGW 13.1.0+

### 在 Qt Creator 中

1. 文件 → 打开文件或项目 → 选择 `CMakeLists.txt`
2. Kit 选择：`Qt 6.10.2 MinGW 64-bit`
3. 左下角锤子图标 → Build
4. 绿色三角 → Run

### 命令行构建

```powershell
# 添加工具路径到 PATH
$env:Path = "E:\LenovoSoftstore\Install\Qt\Tools\CMake_64\bin;" +
           "E:\LenovoSoftstore\Install\Qt\Tools\mingw1310_64\bin;" +
           "E:\LenovoSoftstore\Install\Qt\6.10.2\mingw_64\bin;" +
           $env:Path

# 配置
cd D:\C++\cursor_music\build\Desktop_Qt_6_10_2_MinGW_64_bit-Debug
cmake -DCMAKE_BUILD_TYPE=Debug "D:\C++\cursor_music"

# 编译
mingw32-make -j4

# 运行
.\appcursor_music.exe
```

---

## 九、开发约定

| 规范 | 示例 |
|------|------|
| C++ 类名 | 大驼峰 `HttpClient` `PlayerController` |
| C++ 成员变量 | `m_` 前缀 + 小驼峰 `m_httpClient` |
| QML 组件名 | 大驼峰 `Sidebar.qml` `FavoritesPage.qml` |
| QML id | 全小写蛇形 `pageStack` `contentColumn` |
| Git 提交 | `feat: xxx` / `fix: xxx` / `docs: xxx` |
| 注释语言 | 中文 Doxygen 风格 |

---

## 十、后续可扩展方向

| 方向 | 说明 |
|------|------|
| 音乐区首页 | 调用 B站音乐区推荐接口，展示热门音频 |
| 播放列表/队列 | 支持连续播放、随机、循环 |
| 扫码登录 | 生成二维码扫码登录（比 Cookie 导入更便捷） |
| 歌词显示 | 解析 LRC 歌词文件并同步显示 |
| 下载管理 | 将音频下载到本地文件 |
| Linux/macOS 支持 | 跨平台编译和适配 |
| 单元测试 | Qt Test 框架覆盖核心逻辑 |

---

## 十一、提交历史

```
68f4d0c feat: 完成阶段三 UI 美化与交互优化
a7401a5 fix: 修复播放器 403/DASH 无声/信号时序等多个问题
d8a4460 feat: 完成阶段二核心功能开发
f8b8539 添加中文注释
3fc596b feat: 完成项目阶段一基础框架搭建
```
