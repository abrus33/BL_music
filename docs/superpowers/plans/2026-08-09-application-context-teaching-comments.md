# ApplicationContext Teaching Comments Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 `ApplicationContext.h/.cpp` 改造成准确解释应用装配、QML 注入、QObject 所有权和启动异步流程的教学型源码。

**Architecture:** `ApplicationContext` 保持现有服务容器实现，不修改任何声明、表达式或调用顺序。本计划只重写和补充注释，并以 `main.cpp`、`Main.qml`、依赖类构造函数及 Qt 官方所有权契约为事实来源。

**Tech Stack:** C++17、Qt 6.8+、QObject、Qt Meta-Object System、QML、Qt Network、CMake/CTest

## Global Constraints

- 只修改注释和配套阅读文档，不改变接口、业务逻辑、对象所有权、信号槽连接、线程模型或运行行为。
- 普通 C++ 类以一对 `.h + .cpp` 为一个工作单元；本计划只修改 `ApplicationContext.h/.cpp`。
- 必须先完整核对头文件，再处理实现文件。
- 无法从项目确认的关系不得根据名称编造。
- 保持源文件 UTF-8 编码。
- 简单 getter 不做低价值逐行翻译。

---

### Task 1: 教学化 `ApplicationContext` 类声明

**Files:**
- Modify: `src/app/ApplicationContext.h`
- Reference only: `src/main.cpp`
- Reference only: `qml/Main.qml`
- Reference only: `src/auth/AuthService.h`
- Reference only: `src/bilibili/FavoriteService.h`
- Reference only: `src/bilibili/MusicService.h`
- Reference only: `src/player/MediaResolver.h`
- Reference only: `src/player/PlayerController.h`
- Reference only: `src/player/PlaylistService.h`

**Interfaces:**
- Consumes: `QQmlApplicationEngine::setInitialProperties()`, `Main.qml` 的 `required property var appContext`，现有服务 getter。
- Produces: 不产生新接口；保留全部 `Q_PROPERTY`、函数签名和成员类型。

- [ ] **Step 1: 记录头文件事实基线**

运行：

```powershell
Select-String -Path src\app\ApplicationContext.h -Pattern 'Q_OBJECT|Q_PROPERTY|signals:|slots:|Q_INVOKABLE|^[ ]*[A-Za-z].*\*m_' 
Get-ChildItem qml -File -Recurse | Select-String -Pattern 'appContext\.(settings|authService|favoriteService|mediaResolver|playerController|musicService|playlistService)'
```

预期：类含 `Q_OBJECT` 和八个 `Q_PROPERTY`，自身没有 signals、slots 或 `Q_INVOKABLE`；QML 通过 `appContext` 使用七个已暴露服务属性。

- [ ] **Step 2: 用真实装配关系替换过时的类职责说明**

在 `class ApplicationContext` 前写入以下等价信息，允许只调整排版，不改变事实：

```cpp
/**
 * @brief 应用级服务容器：集中创建 C++ 服务，并把 QML 需要的服务组织成只读属性
 *
 * 继承关系：QObject -> ApplicationContext
 * `Q_OBJECT` 让本类进入 Qt 元对象系统，下面的 Q_PROPERTY 才能被 QML 识别。
 * 本类不是“单例模式”：当前程序只在 main() 栈上创建了一个实例。
 *
 * 装配链路：
 * main() 创建 ApplicationContext
 *      -> engine.setInitialProperties({ "appContext", &applicationContext })
 *      -> Main.qml.required property var appContext
 *      -> 各页面取得 settings / authService / playerController 等服务
 *
 * 所有权：构造函数把服务创建为当前对象的 QObject 子对象；服务之间传入的依赖指针
 * 默认只表示“使用”，不表示再次拥有。ApplicationContext 离开 main() 作用域时，
 * QObject 父子机制会沿对象树销毁这些服务。
 */
```

同时删除或改写两条已过时说法：

- 不再称其为“全局单例”；
- 不再声称通过 `rootContext()->setContextProperty("applicationContext", ...)` 注入；当前实现使用 `setInitialProperties()`，QML 属性名是 `appContext`。

- [ ] **Step 3: 完整解释 `Q_PROPERTY` 数据链路**

在属性组前加入以下教学说明：

```cpp
// 【Qt 属性系统 / C++ -> QML】
// Q_PROPERTY(Type name READ getter CONSTANT) 表示：
// QML 读取 appContext.name 时，Qt 调用对应 getter()。
// CONSTANT 保证的是这个属性值在 ApplicationContext 生命周期内不更换，
// 不是说返回的服务对象内部状态永远不变；服务自己的 Q_PROPERTY/NOTIFY
// 仍然可以驱动 QML 刷新。
//
// 这里没有 WRITE 和 NOTIFY，因此 QML 不能替换这些服务指针，
// ApplicationContext 自身也不会发送“服务对象已更换”的通知。
```

对八个属性按用途分成“应用信息”和“QML 服务入口”，并写明 `PersistentCookieJar`、`HttpClient`、`BilibiliApiClient` 没有暴露为 `Q_PROPERTY`，只供 C++ 装配与内部协作。

- [ ] **Step 4: 标注成员变量的来源、用途和所有权**

在 private 成员组前加入一次性说明，不在每个 getter 重复：

```cpp
// 以下 m_* 均为【当前类成员变量】。
// 它们在构造函数初始化列表中用 new 创建；创建时 parent 都是 this，
// 因而初始所有者是当前 ApplicationContext。传给其他服务构造函数的裸指针
// 是依赖引用：被调用方使用它们，但项目当前的所有权仍由 QObject 对象树表达。
```

按依赖顺序分组：基础设施、API/业务服务、播放服务。每个成员只写一行职责与主要依赖，避免重复 getter 名称。

- [ ] **Step 5: 检查头文件只发生注释变化**

运行：

```powershell
git diff -- src/app/ApplicationContext.h
git diff --check
```

预期：所有 `Q_PROPERTY`、函数声明、访问级别、成员顺序和类型与修改前一致；`git diff --check` 无输出。

### Task 2: 教学化对象装配与初始化控制流

**Files:**
- Modify: `src/app/ApplicationContext.cpp`
- Reference only: `src/network/HttpClient.cpp`
- Reference only: `src/storage/PersistentCookieJar.cpp`
- Reference only: `src/bilibili/BilibiliApiClient.cpp`
- Reference only: `src/auth/AuthService.cpp`

**Interfaces:**
- Consumes: `HttpClient::networkManager() -> QNetworkAccessManager*`、`PersistentCookieJar::load()`、`BilibiliApiClient::warmUp()`、`AuthService::checkLogin()`。
- Produces: 不产生新接口；保留构造初始化顺序和 `initialize()` 函数体。

- [ ] **Step 1: 核对构造依赖和异步边界**

运行：

```powershell
Get-ChildItem src -File -Recurse -Include *.h | Select-String -Pattern 'explicit (AppSettings|PersistentCookieJar|HttpClient|BilibiliApiClient|AuthService|FavoriteService|MediaResolver|PlayerController|MusicService|PlaylistService)\b'
Select-String -Path src\bilibili\BilibiliApiClient.cpp,src\auth\AuthService.cpp -Pattern 'void BilibiliApiClient::warmUp|void AuthService::checkLogin|QNetworkReply::finished|getNavInfo'
```

预期：构造函数参数与 `ApplicationContext` 初始化列表一致；`warmUp()` 和 `checkLogin()` 都会发起网络请求并在后续回调继续，而 `initialize()` 不等待结果。

- [ ] **Step 2: 为构造函数加入对象图和初始化顺序说明**

在构造函数前写入以下流程图：

```cpp
/*
 * 对象装配图（箭头表示“构造时依赖”，不是所有权转移）
 *
 * ApplicationContext
 *   |-- owns AppSettings
 *   |-- owns PersistentCookieJar
 *   |-- owns HttpClient
 *   |      `-- owns QNetworkAccessManager
 *   |-- owns BilibiliApiClient <- HttpClient
 *   |-- owns AuthService <- PersistentCookieJar + BilibiliApiClient
 *   |-- owns FavoriteService <- BilibiliApiClient
 *   |-- owns MediaResolver <- BilibiliApiClient
 *   |-- owns PlayerController
 *   |-- owns MusicService <- BilibiliApiClient
 *   `-- owns PlaylistService <- AppSettings + MediaResolver + PlayerController
 */
```

在初始化列表首次出现每个 `m_*` 时说明它是当前类成员，`new Type(..., this)` 将 `this` 设为 QObject parent；不要重复解释普通 C++ 语法。

- [ ] **Step 3: 移除 getter 上的低价值重复注释**

保留 getter 函数体不变，删除仅复述函数名的 `/** @return ... */`。在 getter 组前只保留一段说明：

```cpp
// 这些 getter 是上方 Q_PROPERTY 的 READ 入口或 C++ 内部依赖访问入口。
// 它们只返回现有对象，不创建对象，也不转移所有权。
```

- [ ] **Step 4: 重写 `initialize()` 的同步/异步流程地图**

在函数前加入以下等价流程说明：

```cpp
/*
 * 启动初始化流程
 *
 * initialize()
 *   |-- [同步] m_cookieJar->load()：当前线程读取磁盘，完成后才继续
 *   |-- [同步] setCookieJar()：把 CookieJar 安装到网络管理器
 *   |-- [异步] warmUp()：发起首页请求，结果稍后在 finished Lambda 中处理
 *   `-- 若已有登录 Cookie
 *          `-- [异步] checkLogin()：发起 nav 请求，结果稍后更新登录状态
 *
 * initialize() 不等待两个网络请求完成；main() 随后加载 QML 并进入 app.exec()。
 * 网络完成事件到达 Qt 事件循环后，相应 Lambda/回调才继续执行。
 */
```

在每个成员首次出现处标明来源，并特别写清 `isLoggedIn()` 只根据本地 Cookie 判断“值得验证”，真正登录有效性由异步 `checkLogin()` 确认。

- [ ] **Step 5: 纠正 CookieJar 所有权说明**

依据 Qt 官方 `QNetworkAccessManager::setCookieJar()` 文档，把现有“不接管所有权”改为：

```cpp
// 【Qt 对象生命周期】
// setCookieJar() 会让 QNetworkAccessManager 接管 CookieJar。
// 当前二者处于同一线程，因此 Qt 会把 m_cookieJar 的 parent 从
// ApplicationContext 改为该 QNetworkAccessManager。
//
// initialize() 之后的实际销毁链：
// ApplicationContext -> HttpClient -> QNetworkAccessManager -> PersistentCookieJar
// m_cookieJar 仍可作为非拥有成员指针访问同一个对象，但直接 QObject parent 已改变。
```

事实依据：`https://doc.qt.io/qt-6/qnetworkaccessmanager.html#setCookieJar`。

- [ ] **Step 6: 标记历史遗留 include，保持代码不变**

`QUrl`、`QStandardPaths`、`QDir` 当前未在本文件直接使用。保留 include，并用一条注意说明这是历史遗留且本轮不擅自清理；删除“URL 处理”“目录操作”等会误导读者认为本文件使用它们的行尾注释。

- [ ] **Step 7: 检查实现文件只发生注释变化**

运行：

```powershell
git diff -- src/app/ApplicationContext.cpp
git diff --check
```

预期：初始化列表、getter 返回表达式、`initialize()` 中四个操作及其顺序完全不变；`git diff --check` 无输出。

### Task 3: 构建验证与阅读地图交付

**Files:**
- Verify: `src/app/ApplicationContext.h`
- Verify: `src/app/ApplicationContext.cpp`
- Reference only: `build-codex-mingw/`

**Interfaces:**
- Consumes: Task 1 和 Task 2 的纯注释差异。
- Produces: 可构建的源码和本批九部分阅读地图。

- [ ] **Step 1: 执行差异审计**

运行：

```powershell
git diff --check
git diff --stat
git diff -- src/app/ApplicationContext.h src/app/ApplicationContext.cpp
```

预期：只有两个目标源码文件发生修改，且所有增删行均为注释或空白排版；没有声明、表达式、调用或 include 指令变化。

- [ ] **Step 2: 构建项目**

运行：

```powershell
cmake --build build-codex-mingw
```

预期：退出码为 0，`appcursor_music`、MOC 和 QML 相关目标成功生成。

- [ ] **Step 3: 运行现有测试**

运行：

```powershell
ctest --test-dir build-codex-mingw --output-on-failure
```

预期：CTest 退出码为 0；若环境中已有与本次注释无关的失败，记录准确测试名和输出，不修改业务代码掩盖失败。

- [ ] **Step 4: 提交本批注释**

运行：

```powershell
git add src/app/ApplicationContext.h src/app/ApplicationContext.cpp
git commit -m "docs: teach application context wiring"
```

预期：提交仅包含两个目标文件。

- [ ] **Step 5: 向用户交付阅读地图**

最终答复依次包含：文件职责、类关系、核心成员变量、Signal/Slot 关系、QML/C++ 数据流、对象生命周期、异步流程、优先阅读函数、所需 Qt 知识，以及修改文件和验证结果。明确指出本类自身没有 signals/slots，异步延续发生在 `BilibiliApiClient::warmUp()` 与 `AuthService::checkLogin()` 内部。
