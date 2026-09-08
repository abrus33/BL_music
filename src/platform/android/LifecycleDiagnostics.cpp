// Android 生命周期基线观测：由 main.cpp 挂到现有 PlayerController，输出集中到 [LifecycleProbe]。
// Android Framework 管理 Activity（界面入口）的回调，Qt 平台层将相关变化转成 applicationStateChanged；
// 此处只接收 Qt 信号，不创建 Activity，也不将 Qt 状态冒充逐一对应的 Android 原生回调。
// Process 是系统调度/回收的进程；QGuiApplication 是进程内 Qt 事件循环对象；Player 是它们内部的业务对象。
// Activity 退到后台不表示后三者已销毁；进程被直接杀死时，也不保证有 C++ 析构或 aboutToQuit 日志。
// 观测器由 QGuiApplication 拥有，仅持有播放器弱引用，不改变播放、缓存、音量或后台执行策略。
#include "LifecycleDiagnostics.h"

#include "player/PlayerController.h"
#include <QAudioDevice>
#include <QAudioOutput>
#include <QCryptographicHash>
#include <QDebug>
#include <QElapsedTimer>
#include <QGuiApplication>
#include <QMediaPlayer>
#include <QPointer>
#include <QTimer>
#include <QUrl>

namespace LifecycleDiagnostics {
namespace {

class Observer final : public QObject
{
public:
    Observer(QGuiApplication &app, PlayerController &controller, QMediaPlayer &player, QAudioOutput &audio)
        : QObject(&app), m_controller(&controller), m_player(&player), m_audio(&audio)
    {
        m_elapsed.start();
        // Framework 的前台/可见性变化经 Qt 平台层触发此信号；这里只采样，不据此自动暂停/恢复。
        connect(&app, &QGuiApplication::applicationStateChanged, this,
                [this](Qt::ApplicationState) { snapshot("applicationStateChanged"); });
        connect(&app, &QCoreApplication::aboutToQuit, this, [this] { snapshot("aboutToQuit"); });
        connect(&player, &QMediaPlayer::playbackStateChanged, this, [this] { snapshot("playbackStateChanged"); });
        connect(&player, &QMediaPlayer::mediaStatusChanged, this, [this] { snapshot("mediaStatusChanged"); });
        connect(&player, &QMediaPlayer::sourceChanged, this, [this] { snapshot("mediaSourceChanged"); });
        connect(&player, &QMediaPlayer::durationChanged, this, [this] { snapshot("durationChanged"); });
        connect(&player, &QMediaPlayer::errorOccurred, this, [this] { snapshot("playerError"); });
        connect(&controller, &PlayerController::sourceChanged, this, [this] { snapshot("controllerSourceChanged"); });
        connect(&audio, &QAudioOutput::deviceChanged, this, [this] { snapshot("audioDeviceChanged"); });
        connect(&audio, &QAudioOutput::volumeChanged, this, [this] { snapshot("volumeChanged"); });
        connect(&audio, &QAudioOutput::mutedChanged, this, [this] { snapshot("mutedChanged"); });

        // destroyed 回调不能再访问被析构对象的业务成员，只记录对象名称。
        connect(&controller, &QObject::destroyed, this, [this] {
            m_controller.clear();
            m_timer.stop();
            qInfo() << "[LifecycleProbe] destroyed=PlayerController";
        });
        connect(&player, &QObject::destroyed, this, [] { qInfo() << "[LifecycleProbe] destroyed=QMediaPlayer"; });
        connect(&audio, &QObject::destroyed, this, [] { qInfo() << "[LifecycleProbe] destroyed=QAudioOutput"; });

        // 每 5 秒采样代替逐帧打印 position。后台事件循环若受限，定时器可能延迟；
        // 缺少 tick 不能单独证明播放器已销毁或声音中断，需结合 adb PID 和实际听感。
        m_timer.setInterval(5000);
        connect(&m_timer, &QTimer::timeout, this, [this] { snapshot("tick"); });
        m_timer.start();
        qInfo() << "[LifecycleProbe] attached pid=" << QCoreApplication::applicationPid()
                << "controller=" << &controller << "player=" << &player << "audio=" << &audio;
        snapshot("attached");
    }

private:
    void snapshot(const char *reason)
    {
        if (!m_controller || !m_player || !m_audio)
            return;
        // CDN URL 可能带签名/鉴权查询参数。只打印 host、是否为空和完整 URL 的指纹，
        // 用指纹关联同一 source，避免把授权参数、Cookie 或曲目详情写进观测日志。
        const QString source = m_controller->source();
        const QByteArray sourceId = source.isEmpty() ? QByteArray("none")
            : QCryptographicHash::hash(source.toUtf8(), QCryptographicHash::Sha256).toHex().left(16);
        qInfo() << "[LifecycleProbe] event=" << reason << "elapsedMs=" << m_elapsed.elapsed()
                << "app=" << QGuiApplication::applicationState()
                << "playback=" << m_player->playbackState() << "media=" << m_player->mediaStatus()
                << "position=" << m_player->position() << "duration=" << m_player->duration()
                << "sourceId=" << sourceId << "sourceHost=" << QUrl(source).host()
                << "sourceEmpty=" << source.isEmpty()
                // 本项目 setSourceDevice(QBuffer, 空URL)，底层 sourceEmpty=true 是预期，不代表丢源。
                << "mediaUrlEmpty=" << m_player->source().isEmpty()
                << "sourceDevice=" << (m_player->sourceDevice() != nullptr)
                << "audioAttached=" << (m_player->audioOutput() == m_audio.data())
                << "audioDeviceNull=" << m_audio->device().isNull()
                << "volume=" << m_audio->volume() << "muted=" << m_audio->isMuted()
                << "error=" << m_player->error();
    }

    // QPointer 不拥有对象；控制器正常销毁后弱引用归零，观测器不会延长其寿命。
    QPointer<PlayerController> m_controller;
    QPointer<QMediaPlayer> m_player;
    QPointer<QAudioOutput> m_audio;
    QElapsedTimer m_elapsed; // 单调经过时间，用于与播放 position 增量比较，不受系统时钟校正影响。
    QTimer m_timer;
};
} // namespace

void start(QGuiApplication &app, PlayerController &controller)
{
    // 已阅读的控制器构造函数明确创建一对直接子对象；诊断通过 QObject 树观察，避免增加业务 getter。
    const auto players = controller.findChildren<QMediaPlayer *>(QString(), Qt::FindDirectChildrenOnly);
    const auto outputs = controller.findChildren<QAudioOutput *>(QString(), Qt::FindDirectChildrenOnly);
    if (players.size() != 1 || outputs.size() != 1) {
        qWarning() << "[LifecycleProbe] attachment failed: expected one direct player/audio pair";
        return;
    }
    new Observer(app, controller, *players.front(), *outputs.front());
}
} // namespace LifecycleDiagnostics
