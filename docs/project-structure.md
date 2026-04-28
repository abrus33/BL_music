# 项目结构与构建基线

## 当前开发基线
- Qt: `6.10.2`
- C++ 标准: `C++17`
- CMake: 项目最低版本 `3.16`
- 目标平台: `Windows` 优先，后续可兼容 Linux

## 已启用的 Qt 模块
- `Qt6::Quick`
- `Qt6::QuickControls2`
- `Qt6::Network`
- `Qt6::Multimedia`
- `Qt6::Svg`

## 目录说明
- `src/`
  - `main.cpp`: 程序入口与 QML 引擎初始化
  - `app/`: 应用上下文、依赖装配、全局服务入口
- `qml/`
  - `Main.qml`: 主窗口
  - `components/`: 可复用界面组件
  - `pages/`: 页面级视图
- `docs/`
  - `project-structure.md`: 结构与模块说明
- `哔哩哔哩API/`
  - 仓库内置的 B站 API 资料，不直接参与构建

## 后续建议补充的模块目录
- `src/network/`: 通用 HTTP 客户端、请求头、CookieJar
- `src/auth/`: 登录态校验、Cookie 持久化、刷新流程
- `src/bilibili/`: B站 API 封装与数据模型
- `src/player/`: 播放器控制、媒体源解析、播放列表
- `tests/`: Qt Test 单元测试与 mock 数据
