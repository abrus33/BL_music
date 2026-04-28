# 项目架构说明文档

## 一、项目概述

**项目名称**：Bilibili Music Client（哔哩哔哩音乐客户端）

**开发目标**：基于 Qt Quick + C++17 的桌面音乐播放器，主要功能包括：
- B站账号 Cookie 登录
- 收藏夹列表读取与内容展示
- 音频/视频流播放
- 网易云风格三段式 UI

**当前阶段**：阶段一（基础框架搭建）已完成

---

## 二、技术栈

| 技术 | 版本 | 说明 |
|------|------|------|
| Qt | 6.10.2 | GUI 框架 |
| C++ 标准 | C++17 | 主开发语言 |
| CMake | 3.16+ | 构建系统 |
| 编译器 | MinGW 13.1.0 64-bit | Windows 平台 |

### 启用的 Qt 模块

| 模块 | 用途 |
|------|------|
| `Qt6::Quick` | QML 界面引擎 |
| `Qt6::QuickControls2` | QML 控件库（按钮、滑块等） |
| `Qt6::Network` | HTTP 网络请求（QNetworkAccessManager） |
| `Qt6::Multimedia` | 音视频播放（QMediaPlayer）【阶段二使用】 |
| `Qt6::Svg` | SVG 图标渲染【阶段三使用】 |

---

## 三、目录结构

```
d:\C++\cursor_music/
├── CMakeLists.txt              # 构建配置文件
├── .gitignore                  # Git 忽略规则
├── b站音乐客户端开发计划_137d6eaa.plan.md  # 开发计划文档
│
├── src/                        # C++ 源代码根目录
│   ├── main.cpp                # 程序入口（QML 引擎初始化 + 注入 C++ 对象）
│   │
│   ├── app/                    # 应用层（服务容器）
│   │   ├── ApplicationContext.h    # 全局服务上下文头文件
│   │   └── ApplicationContext.cpp  # 服务实例创建与初始化
│   │
│   ├── network/                # 网络层
│   │   ├── HttpClient.h            # HTTP 客户端头文件
│   │   └── HttpClient.cpp          # HTTP 请求实现（GET/POST/超时）
│   │
│   ├── storage/                # 存储层
│   │   ├── AppSettings.h           # 应用配置头文件
│   │   ├── AppSettings.cpp         # QSettings 封装
│   │   ├── PersistentCookieJar.h   # 持久化 Cookie 头文件
│   │   └── PersistentCookieJar.cpp # Cookie 磁盘读写实现
│   │
│   ├── auth/                   # 【阶段二】登录认证模块
│   ├── player/                 # 【阶段二】播放器模块
│   └── .gitkeep                # 空目录占位（Git 不跟踪空目录）
│
├── qml/                        # QML 界面文件
│   ├── Main.qml                    # 主窗口（三段式布局）
│   ├── components/                 # 可复用组件
│   │   └── Sidebar.qml             # 侧边导航栏
│   └── pages/                      # 页面视图
│       ├── HomePage.qml            # 首页（项目概览）
│       ├── FavoritesPage.qml       # 收藏夹（占位页）
│       └── LoginPage.qml           # 登录（占位页）
│
├── docs/                       # 文档
│   ├── project-structure.md        # 项目结构简版
│   └── project-architecture.md     # 本架构说明文档
│
├── tests/                      # 【阶段四】单元测试
│   └── .gitkeep
│
└── 哔哩哔哩API/                # B站接口文档仓库（参考资料，不参与构建）
    └── bili-apis/
        ├── docs/login/             # 登录相关 API
        ├── docs/fav/               # 收藏夹相关 API
        ├── docs/audio/             # 音频播放 API
        ├── docs/video/             # 视频播放 API
        └── grpc_api/               # gRPC 接口定义（Protobuf）
```

---

## 四、核心架构设计

### 4.1 整体架构分层

```
┌─────────────────────────────────────────────────┐
│  QML 表示层（qml/）                              │
│  Main.qml / Sidebar.qml / HomePage.qml / ...    │
│  通过 applicationContext 访问 C++ 服务            │
├─────────────────────────────────────────────────┤
│  C++ 服务容器层（src/app/）                       │
│  ApplicationContext - 全局单例，持有所有服务实例    │
├──────────────────┬──────────────────────────────┤
│  网络层           │  存储层                       │
│  HttpClient      │  AppSettings                  │
│  (GET/POST/超时)  │  (QSettings INI 封装)         │
│  BilibiliApiClient│  PersistentCookieJar          │
│  【阶段二】        │  (Cookie 磁盘持久化)            │
├──────────────────┴──────────────────────────────┤
│  【阶段二】业务服务层                              │
│  AuthService / FavoriteService / MediaResolver   │
│  PlayerController                                │
└─────────────────────────────────────────────────┘
```

### 4.2 C++ 与 QML 的交互机制

本项目的核心交互模式是 **C++ 驱动数据，QML 负责展示**。

#### 交互方式 1：上下文属性注入（main.cpp:54）

```cpp
// main.cpp
engine.rootContext()->setContextProperty("applicationContext", &applicationContext);
```

- 将 C++ `ApplicationContext` 对象注册为 QML 全局属性
- QML 中通过 `applicationContext.xxx` 直接访问
- 使用场景：读取应用信息（如 `applicationContext.qtVersion`）

#### 交互方式 2：Q_PROPERTY 暴露属性

```cpp
// ApplicationContext.h
Q_PROPERTY(QString appName READ appName CONSTANT)
Q_PROPERTY(QString qtVersion READ qtVersion CONSTANT)
```

- `Q_PROPERTY` 将 C++ 成员变量/方法暴露给 QML
- `CONSTANT` 修饰符告诉 QML 该属性不会变化，可缓存
- 使用场景：QML 只读显示 C++ 数据

#### 交互方式 3（后续阶段）：信号与槽

```cpp
// 后续阶段通过 Q_INVOKABLE 暴露方法给 QML 调用
// 通过信号将 C++ 异步结果通知 QML 更新界面
```

### 4.3 数据流

```
用户操作 -> QML 界面
  -> 调用 C++ Q_INVOKABLE 方法（后续阶段）
  -> AuthService / FavoriteService 等业务服务
  -> HttpClient 发送 HTTP 请求（自动携带 Cookie）
  -> B站 API 服务器
  -> HTTP 响应返回
  -> 解析 JSON -> 更新 C++ 数据模型
  -> 通过信号通知 QML 更新 UI
```

---

## 五、核心模块详解

### 5.1 ApplicationContext（应用上下文）

**文件**：`src/app/ApplicationContext.h/.cpp`

**职责**：
- 全局单例，管理所有核心服务的生命周期
- 将 C++ 服务暴露给 QML 层
- 初始化各服务的关联关系

**成员变量**：

| 变量名 | 类型 | 说明 |
|--------|------|------|
| `m_settings` | `AppSettings*` | 应用配置管理器 |
| `m_cookieJar` | `PersistentCookieJar*` | Cookie 持久化管理器 |
| `m_httpClient` | `HttpClient*` | HTTP 网络客户端 |

**初始化顺序**：
1. 构造函数中创建所有服务实例（`new Service(this)`）
2. `initialize()` 中按依赖顺序初始化：
   - 先 `m_cookieJar->load()` 加载磁盘 Cookie
   - 后 `m_httpClient->networkManager()->setCookieJar(m_cookieJar)` 关联 Cookie

---

### 5.2 HttpClient（HTTP 客户端）

**文件**：`src/network/HttpClient.h/.cpp`

**职责**：
- 封装 QNetworkAccessManager 提供统一 HTTP 请求接口
- 自动设置 B站 API 必需的请求头（User-Agent、Referer）
- 支持超时控制（QTimer 实现）

**核心数据结构**：

```cpp
struct Response {
    int statusCode;    // HTTP 状态码（200/403/500 等）
    QByteArray body;   // 原始响应体
    bool success;      // 网络层是否成功（不代表业务成功）
    QString errorString; // 错误描述
};
```

**使用流程**：
1. 调用 `get(url)` 或 `post(url, data)`
2. 监听 `requestFinished` 信号
3. 在信号回调中解析 `Response`

**B站 API 特殊处理**：
- `User-Agent`: 模拟 Chrome 120 浏览器
- `Referer`: 设置为 `https://www.bilibili.com`
- Cookie：通过 `PersistentCookieJar` 自动携带

---

### 5.3 PersistentCookieJar（Cookie 持久化）

**文件**：`src/storage/PersistentCookieJar.h/.cpp`

**职责**：
- 继承 QNetworkCookieJar，增加磁盘持久化能力
- 实现 Cookie 的自动保存（setCookiesFromUrl 自动触发 save）
- 登录态快速判断（isLoggedIn）

**文件存储**：
- 路径：`%APPDATA%/cursor_music/cookies.dat`
- 格式：QDataStream 序列化的 `QList<QByteArray>`
- Cookie 序列化：`toRawForm()` / `parseCookies()`

**关键方法**：

| 方法 | 说明 |
|------|------|
| `load()` | 从磁盘加载 Cookie |
| `save()` | 保存 Cookie 到磁盘 |
| `getCookie(name)` | 按名称查找 Cookie |
| `setCookieString(str)` | 导入浏览器 Cookie 字符串 |
| `isLoggedIn()` | 判断 SESSDATA 是否存在 |
| `setCookiesFromUrl()` | 重写父类方法，自动 save |

---

### 5.4 AppSettings（应用配置）

**文件**：`src/storage/AppSettings.h/.cpp`

**职责**：
- 封装 QSettings，提供统一的配置读写接口
- 存储位置：`%APPDATA%/cursor_music/cursor_music.ini`
- 使用 INI 格式，便于查看和手动修改

**典型用法**：
- 窗口几何位置记忆
- 用户偏好设置（音量、播放模式等）
- 上次使用状态恢复

---

## 六、编译与运行

### 6.1 在 Qt Creator 中

1. 打开 `CMakeLists.txt`
2. 选择 Kit：`Qt 6.10.2 MinGW 64-bit`
3. 点击 Build → Run

### 6.2 命令行构建

```powershell
$env:Path = "E:\LenovoSoftstore\Install\Qt\Tools\CMake_64\bin;" +
           "E:\LenovoSoftstore\Install\Qt\Tools\mingw1310_64\bin;" +
           "E:\LenovoSoftstore\Install\Qt\6.10.2\mingw_64\bin;" +
           $env:Path

cd "D:\C++\cursor_music\build\Desktop_Qt_6_10_2_MinGW_64_bit-Debug"
cmake --build .
```

---

## 七、开发约定

### 7.1 代码注释规范

- 所有 `.h` 头文件：类说明 + 方法说明 + 成员变量说明
- 所有 `.cpp` 实现文件：函数实现说明 + 关键逻辑注释
- 所有 `.qml` 文件：组件说明 + C++ 交互点标注
- 语言：中文（便于团队阅读）

### 7.2 Git 提交规范

- 使用 `feat: ` / `fix: ` / `docs: ` 等前缀
- 提交信息简明扼要，说明修改目的
- 构建产物不提交（参考 `.gitignore`）

### 7.3 命名规范

- C++ 类名：大驼峰（`HttpClient`, `AppSettings`）
- C++ 成员变量：`m_` 前缀 + 小驼峰（`m_httpClient`, `m_cookieJar`）
- QML 组件：大驼峰（`Sidebar`, `HomePage`）
- QML id：全小写蛇形（`pageStack`, `contentColumn`）
- 文件命名：大驼峰 + 与类名一致（`HttpClient.h`）

---

## 八、后续阶段规划

| 阶段 | 内容 | 预计 |
|------|------|------|
| **阶段一**（当前） | 基础框架搭建（HttpClient、CookieJar、AppSettings、三段式 UI） | 已完成 |
| **阶段二** | 核心功能（AuthService、FavoriteService、PlayerController） | 进行中 |
| **阶段三** | UI 美化（网易云风格、主题统一、卡片列表） | 待开始 |
| **阶段四** | 测试与联调（单元测试、Mock 测试、手工回归） | 待开始 |
