# 项目结构速查

## 开发基线

| 项 | 值 |
|----|-----|
| Qt | 6.10.2 |
| C++ | C++17 |
| CMake | ≥ 3.16 |
| 编译器 | MinGW 13.1.0 64-bit |
| 构建 | CMake + qt_add_qml_module |

## 目录一览

```
src/
├── main.cpp                      入口 + QML引擎 + context注入
├── app/ApplicationContext        服务容器（创建/持有/初始化所有服务）
├── network/HttpClient            HTTP客户端（GET/POST/超时/Header）
├── storage/
│   ├── AppSettings               QSettings INI配置存储
│   └── PersistentCookieJar       Cookie磁盘读写
├── auth/AuthService              登录/退出/Cookie导入
├── bilibili/
│   ├── BilibiliApiClient         B站REST API（nav/收藏夹/音频视频流/WBI签名）
│   └── FavoriteService           收藏夹列表+内容加载服务
└── player/
    ├── PlayerController          QMediaPlayer+QAudioOutput封装（播放/暂停/进度/音量）
    └── MediaResolver             音频/视频URL解析

qml/
├── Main.qml                      三段式主窗口（导航+内容+播放栏）
├── components/
│   ├── Sidebar.qml               左侧导航栏（用户信息+导航项+悬停动画）
│   └── Theme.js                  主题常量（颜色/字体/间距/圆角）
└── pages/
    ├── HomePage.qml              项目概览首页
    ├── FavoritesPage.qml         收藏夹（文件夹列表→资源列表→播放）
    └── LoginPage.qml             Cookie登录（输入框+导入+状态显示）
```

## 功能状态

| 功能 | 状态 |
|------|------|
| Cookie 导入登录 + 登录态验证 | ✅ |
| 收藏夹列表 + 内容展示 | ✅ |
| 音频流解析播放（含 DASH 音频轨提取） | ✅ |
| 播放/暂停/进度拖动/音量/时间显示 | ✅ |
| 三段式网易云风格布局 | ✅ |
| 统一主题常量 | ✅ |
| 悬停动画 | ✅ |
