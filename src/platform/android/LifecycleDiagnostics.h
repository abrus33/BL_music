// Android 生命周期行为基线的观测入口，属于可选诊断层。
// main.cpp 在 ApplicationContext 创建后调用；实现只监听 Qt Application 与现有播放器。
// 不接管 PlayerController 的所有权，不调用播放控制，也不创建 Android Service。
#pragma once

class QGuiApplication;
class PlayerController;

namespace LifecycleDiagnostics {
void start(QGuiApplication &app, PlayerController &controller);
}
