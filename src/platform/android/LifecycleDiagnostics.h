// Android 生命周期行为基线的观测入口，属于可选诊断层。
// main.cpp 在 ApplicationContext 创建后调用；实现只监听 Qt Application 与现有播放器。
// 不接管 PlayerController 的所有权，不调用播放控制，也不创建 Android Service。
#pragma once

class QGuiApplication;
class PlayerController;
class PlaylistService;

namespace LifecycleDiagnostics {
void start(QGuiApplication &app, PlayerController &controller, PlaylistService &playlist);
}

// 业务边界只调用这些观测宏；默认关闭及非 Android Debug 构建完全不求值参数。
// 实现集中于诊断层，不引入 JNI，不控制 Android 后台策略。
#ifdef BL_ANDROID_LIFECYCLE_DIAGNOSTICS
#include <QVariantMap>
class QNetworkReply;
namespace LifecycleDiagnostics {
void event(const char *name, const QVariantMap &fields = {});
QString sourceId(const QString &source);
void watchRequest(QNetworkReply *reply, const char *kind);
}
#define BL_LIFECYCLE_EVENT(name, ...) \
    LifecycleDiagnostics::event(name, QVariantMap{__VA_ARGS__})
#define BL_LIFECYCLE_REQUEST(reply, kind) LifecycleDiagnostics::watchRequest(reply, kind)
#else
#define BL_LIFECYCLE_EVENT(...) do {} while (false)
#define BL_LIFECYCLE_REQUEST(...) do {} while (false)
#endif
