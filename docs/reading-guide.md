# 项目阅读指南：Bili Music Qt 客户端

这份文档只解决一个问题：第一次打开这个项目时，应该按什么顺序看代码，才能最快理解它。

项目当前的定位是一个基于 Qt 6、C++17 和 QML 的桌面音乐客户端。C++ 负责网络、登录、收藏夹、媒体解析、播放控制和本地配置；QML 负责界面、响应式布局、状态展示和用户交互。

## 1. 先看全局结构

建议先把项目分成四层理解：

```text
qml/                         界面层
  Main.qml                   应用窗口入口
  components/                通用界面组件和设计系统组件
  pages/                     首页、收藏夹、登录页

src/app/                     应用装配层
  ApplicationContext.*       创建并暴露所有服务

src/auth src/bilibili        业务和接口层
  AuthService.*              登录状态、Cookie 导入、扫码登录
  BilibiliApiClient.*        B 站 API 封装
  FavoriteService.*          收藏夹列表和收藏夹内容加载
  MusicService.*             首页音乐内容

src/player src/storage       播放和持久化
  MediaResolver.*            把收藏条目解析为可播放地址
  PlayerController.*         Qt Multimedia 播放控制
  PlaylistService.*          播放队列、切歌、播放模式
  AppSettings.*              本地设置，例如降低动态效果
```

最重要的桥是 `ApplicationContext`。它在 C++ 中持有所有服务，再通过 QML context property 暴露给界面。你看到 QML 里调用 `appContext.favoriteService`、`appContext.playerController` 这类对象，本质上就是在调用 C++ 服务。

## 2. 推荐阅读顺序

第一轮只看入口和装配：

1. `src/main.cpp`：程序启动、创建 `ApplicationContext`、加载 QML。
2. `src/app/ApplicationContext.h` 和 `.cpp`：理解服务对象如何被创建、依赖关系如何组织。
3. `CMakeLists.txt`：确认哪些 C++、QML、测试文件参与构建。

第二轮看界面框架：

1. `qml/Main.qml`：窗口入口和全局服务注入。
2. `qml/components/AppShell.qml`：主界面外壳，负责导航区、内容区、播放栏和播放队列。
3. `qml/components/NavigationRail.qml`：窗口变窄时侧栏如何收起。
4. `qml/components/ResponsivePlayerBar.qml`：播放器控件如何在窄窗口下压缩。
5. `qml/components/Theme.js`：颜色、间距、字号、圆角、动效等设计令牌。

第三轮看核心页面：

1. `qml/pages/HomePage.qml`：首页列表如何加载、展示和播放。
2. `qml/pages/FavoritesPage.qml`：收藏夹页的关键逻辑。现在它是“概览”和“详情”两种互斥状态：点击某个收藏夹后，只显示该收藏夹内的视频列表。
3. `qml/pages/LoginPage.qml`：Cookie 登录和扫码登录入口。

第四轮看播放链路：

1. `src/player/PlaylistService.*`：播放队列、当前项、上一首、下一首、播放模式。
2. `src/player/MediaResolver.*`：根据条目类型、BVID、CID 等信息解析媒体地址。
3. `src/player/PlayerController.*`：封装 `QMediaPlayer`、进度、音量和播放状态。

第五轮看网络和 B 站数据：

1. `src/network/HttpClient.*`：统一请求头、超时、响应处理。
2. `src/storage/PersistentCookieJar.*`：Cookie 的导入、保存和恢复。
3. `src/bilibili/BilibiliApiClient.*`：B 站 API 的底层封装。
4. `src/bilibili/FavoriteService.*`：收藏夹请求、分页加载、异步结果防串扰。

## 3. 三条关键数据流

启动流程：

```text
main.cpp
  -> 创建 ApplicationContext
  -> 初始化 Cookie、设置、服务
  -> 注入到 QML
  -> 加载 Main.qml
  -> AppShell 显示页面和播放器
```

收藏夹流程：

```text
FavoritesPage.qml
  -> favoriteService.loadFavoriteFolders(userMid)
  -> 显示收藏夹卡片
  -> 点击收藏夹
  -> favoriteService.loadAllFavoriteResources(mediaId)
  -> 切到详情状态，只显示当前收藏夹内容
```

播放流程：

```text
用户点击媒体条目
  -> QML 把条目交给 PlaylistService
  -> MediaResolver 解析真实播放地址
  -> PlayerController 设置媒体源并播放
  -> ResponsivePlayerBar 根据播放状态刷新进度和控件
```

## 4. 当前界面系统怎么理解

新版界面按“沉浸式个人音乐库”的方向设计。重点不是堆装饰，而是让首页、收藏夹、登录、播放器和播放队列看起来属于同一个产品。

几个关键组件：

- `AppShell.qml`：全局布局框架。
- `PageHeader.qml`：页面标题区。
- `FolderCard.qml`：收藏夹卡片。
- `MediaList.qml` 和 `MediaListItem.qml`：媒体列表。
- `EmptyState.qml` 和 `ErrorState.qml`：空状态和错误状态。
- `IconButton.qml`、`AppButton.qml`、`AppIcon.qml`：统一按钮和图标使用方式。
- `QueueDrawer.qml`：播放队列抽屉，支持键盘焦点和长列表。

响应式规则：

- 小于 `860px`：侧栏收起为底部导航，播放器控件压缩。
- `860px` 到 `1179px`：使用窄图标导航栏。
- 大于等于 `1180px`：使用完整侧栏和完整播放器布局。

## 5. 构建、测试和检查

如果使用 Qt Creator，打开根目录的 `CMakeLists.txt`，选择 Qt 6 MinGW Kit 后构建运行即可。

命令行可以参考本机已有构建目录执行：

```powershell
cmake --build build\Desktop_Qt_6_10_2_MinGW_64_bit-Debug
ctest --test-dir build\Desktop_Qt_6_10_2_MinGW_64_bit-Debug --output-on-failure
```

项目里已有的重点测试包括：

- `tst_favoriteloadsession`
- `tst_mediaresolver`
- `tst_appsettings`
- `cursor_music_qml_tests`

如果你改的是 QML 组件，优先跑 QML 测试和 `qmllint`；如果你改的是收藏夹、媒体解析、设置持久化，优先跑对应 C++ 单元测试。

## 6. 面向以后迭代的建议

以后加新页面时，尽量沿用这条路径：

1. 先判断是否需要新的 C++ 服务；如果只是展示已有数据，不要新建服务。
2. 页面放在 `qml/pages/`，可复用控件放在 `qml/components/`。
3. 颜色、间距、字号、动效统一从 `Theme.js` 取，不在页面里写散落样式。
4. 涉及异步请求时，给请求加 owner、generation 或 session id，避免旧响应覆盖新状态。
5. 重要业务逻辑放 C++ 测试，重要界面状态放 QML 测试。

这份文档是项目入口。简历怎么写、面试怎么讲，请看 `docs/resume-project-guide.md`。
