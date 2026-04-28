// ============================================================================
// PlayerController.cpp - 播放器控制器实现
// 功能：封装 QMediaPlayer + QAudioOutput，提供播放/暂停/seek/音量控制
// ============================================================================

#include "PlayerController.h"

#include <QMediaPlayer>
#include <QAudioOutput>
#include <QUrl>
#include <QDebug>

/**
 * @brief 构造函数
 *
 * 创建并配置 QMediaPlayer 和 QAudioOutput：
 * - QMediaPlayer: 负责媒体解码和播放控制
 * - QAudioOutput: 负责音频输出和音量控制
 *
 * 两者需要通过 setAudioOutput() 关联
 */
PlayerController::PlayerController(QObject *parent)
    : QObject(parent)
    , m_player(new QMediaPlayer(this))
    , m_audioOutput(new QAudioOutput(this))
{
    // 将音频输出关联到播放器
    m_player->setAudioOutput(m_audioOutput);

    // ---- 连接 QMediaPlayer 的信号 ----
    // 播放状态变化
    connect(m_player, &QMediaPlayer::playbackStateChanged,
            this, &PlayerController::onStateChanged);

    // 播放位置变化（约每秒更新 4 次）
    connect(m_player, &QMediaPlayer::positionChanged,
            this, &PlayerController::positionChanged);

    // 媒体总时长变化（加载完成后更新）
    connect(m_player, &QMediaPlayer::durationChanged,
            this, &PlayerController::durationChanged);

    // 播放错误
    connect(m_player, &QMediaPlayer::errorOccurred,
            this, &PlayerController::onErrorOccurred);

    // 播放源变化
    connect(m_player, &QMediaPlayer::sourceChanged,
            this, &PlayerController::sourceChanged);
}

// ==================== 属性访问方法 ====================

QString PlayerController::source() const
{
    return m_source;
}

/**
 * @brief 设置播放源
 * @param url 媒体 URL
 *
 * 自动开始加载媒体，加载完成后可通过 play() 开始播放
 * 也可以直接调用 play() 自动播放
 */
void PlayerController::setSource(const QString &url)
{
    if (m_source == url)
        return;

    m_source = url;
    m_player->setSource(QUrl(url));

    // 加载完成后自动准备播放
    emit sourceChanged();
}

int PlayerController::position() const
{
    return static_cast<int>(m_player->position());
}

int PlayerController::duration() const
{
    return static_cast<int>(m_player->duration());
}

qreal PlayerController::volume() const
{
    return m_audioOutput->volume();
}

void PlayerController::setVolume(qreal vol)
{
    vol = qBound(0.0, vol, 1.0);
    if (qFuzzyCompare(m_audioOutput->volume(), vol))
        return;

    m_audioOutput->setVolume(vol);
    emit volumeChanged();
}

/**
 * @brief 获取播放状态的字符串表示
 * @return "Playing" / "Paused" / "Stopped"
 *
 * 字符串形式便于 QML 直接显示和判断
 */
QString PlayerController::playbackState() const
{
    switch (m_player->playbackState()) {
    case QMediaPlayer::PlayingState:
        return QStringLiteral("Playing");
    case QMediaPlayer::PausedState:
        return QStringLiteral("Paused");
    default:
        return QStringLiteral("Stopped");
    }
}

QString PlayerController::mediaTitle() const
{
    return m_mediaTitle;
}

void PlayerController::setMediaTitle(const QString &title)
{
    if (m_mediaTitle == title)
        return;
    m_mediaTitle = title;
    emit mediaTitleChanged();
}

QString PlayerController::mediaCover() const
{
    return m_mediaCover;
}

void PlayerController::setMediaCover(const QString &cover)
{
    if (m_mediaCover == cover)
        return;
    m_mediaCover = cover;
    emit mediaCoverChanged();
}

// ==================== 播放控制方法（Q_INVOKABLE） ====================

void PlayerController::play()
{
    m_player->play();
}

void PlayerController::pause()
{
    m_player->pause();
}

void PlayerController::stop()
{
    m_player->stop();
}

void PlayerController::seek(int positionMs)
{
    m_player->setPosition(positionMs);
}

// ==================== 内部槽函数 ====================

/**
 * @brief 播放状态变化处理
 *
 * 将 QMediaPlayer::PlaybackState 枚举转换为 QString 后重新发射
 * 供 QML 绑定的 playbackState 属性更新
 */
void PlayerController::onStateChanged()
{
    emit stateChanged();
}

/**
 * @brief 播放错误处理
 *
 * 当播放器遇到无法播放的媒体时触发
 * 常见错误：
 * - ResourceError: 媒体资源无法访问（URL 失效、网络问题）
 * - FormatError: 媒体格式不支持
 * - NetworkError: 网络连接问题
 */
void PlayerController::onErrorOccurred()
{
    QMediaPlayer::Error err = m_player->error();
    QString errorStr = m_player->errorString();

    qWarning() << "PlayerController 错误:" << err << errorStr;
    emit playerError(static_cast<int>(err), errorStr);
}
