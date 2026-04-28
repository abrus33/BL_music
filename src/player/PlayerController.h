// ============================================================================
// PlayerController.h - 播放器控制器
// 功能：封装 QMediaPlayer + QAudioOutput，提供播放控制能力
//       将播放状态暴露给 QML 层
// 与 QML 的交互：
//   - Q_PROPERTY 暴露播放状态属性
//   - Q_INVOKABLE 暴露控制方法
//   - 信号通知状态变更
// ============================================================================

#pragma once

#include <QObject>

class QMediaPlayer;
class QAudioOutput;

/**
 * @brief 播放器控制器
 *
 * 封装 Qt Multimedia 模块的 QMediaPlayer 和 QAudioOutput，
 * 提供统一的播放控制接口。
 *
 * QML 访问方式：
 *   applicationContext.playerController.play()
 *   applicationContext.playerController.pause()
 *   applicationContext.playerController.source = "url"
 *   applicationContext.playerController.position
 *   applicationContext.playerController.volume
 *
 * 支持的媒体格式：
 * - 音频：m4a, mp3, flac, wav 等（QMediaPlayer 支持的后端格式）
 * - 视频：mp4 等
 *
 * 播放状态流转：
 *   Stopped -> Playing -> Paused -> Playing -> Stopped
 */
class PlayerController : public QObject
{
    Q_OBJECT

    // ---- 对外暴露给 QML 的属性 ----
    Q_PROPERTY(QString source READ source WRITE setSource NOTIFY sourceChanged)
    Q_PROPERTY(int position READ position NOTIFY positionChanged)
    Q_PROPERTY(int duration READ duration NOTIFY durationChanged)
    Q_PROPERTY(qreal volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(QString playbackState READ playbackState NOTIFY stateChanged)
    Q_PROPERTY(QString mediaTitle READ mediaTitle WRITE setMediaTitle NOTIFY mediaTitleChanged)
    Q_PROPERTY(QString mediaCover READ mediaCover WRITE setMediaCover NOTIFY mediaCoverChanged)

public:
    /**
     * @brief 构造函数
     * @param parent Qt 父对象
     *
     * 内部创建 QMediaPlayer 和 QAudioOutput 实例
     */
    explicit PlayerController(QObject *parent = nullptr);

    /** @brief 当前播放源的 URL */
    QString source() const;

    /**
     * @brief 设置播放源并开始播放
     * @param url 媒体流 URL
     *
     * 可以直接从 QML 调用：
     *   applicationContext.playerController.source = "https://...m4a"
     */
    void setSource(const QString &url);

    /** @brief 当前播放位置（毫秒） */
    int position() const;

    /** @brief 媒体总时长（毫秒） */
    int duration() const;

    /** @brief 音量（0.0 - 1.0） */
    qreal volume() const;

    /**
     * @brief 设置音量
     * @param vol 音量值（0.0 = 静音, 1.0 = 最大）
     */
    void setVolume(qreal vol);

    /** @brief 当前播放状态：Playing / Paused / Stopped */
    QString playbackState() const;

    /** @brief 当前正在播放的媒体标题 */
    QString mediaTitle() const;
    void setMediaTitle(const QString &title);

    /** @brief 当前正在播放的媒体封面 URL */
    QString mediaCover() const;
    void setMediaCover(const QString &cover);

    // ==================== Q_INVOKABLE 控制方法 ====================

    /** @brief 播放 */
    Q_INVOKABLE void play();

    /** @brief 暂停 */
    Q_INVOKABLE void pause();

    /** @brief 停止 */
    Q_INVOKABLE void stop();

    /**
     * @brief 跳转到指定位置
     * @param positionMs 目标位置（毫秒）
     */
    Q_INVOKABLE void seek(int positionMs);

signals:
    /** @brief 播放源变更信号 */
    void sourceChanged();

    /** @brief 播放位置变化信号（QML 进度条绑定此信号更新） */
    void positionChanged();

    /** @brief 媒体时长加载完成信号 */
    void durationChanged();

    /** @brief 音量变化信号 */
    void volumeChanged();

    /** @brief 播放状态变化信号 */
    void stateChanged();

    /** @brief 媒体标题变化信号 */
    void mediaTitleChanged();

    /** @brief 媒体封面变化信号 */
    void mediaCoverChanged();

    /**
     * @brief 播放错误信号
     * @param errorCode    错误代码
     * @param errorString  错误描述
     */
    void playerError(int errorCode, const QString &errorString);

private slots:
    /** @brief 处理 QMediaPlayer 状态变化 */
    void onStateChanged();

    /** @brief 处理 QMediaPlayer 错误 */
    void onErrorOccurred();

private:
    /** Qt 多媒体播放器（核心播放引擎） */
    QMediaPlayer *m_player;

    /** Qt 音频输出（控制音量、声道等） */
    QAudioOutput *m_audioOutput;

    // ---- 播放信息 ----
    QString m_source;              // 当前播放源 URL
    QString m_mediaTitle;          // 当前媒体标题
    QString m_mediaCover;          // 当前媒体封面 URL
};
