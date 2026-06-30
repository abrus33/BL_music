// ============================================================================
// PlayerController.h - 播放器控制器
// 功能：封装 QMediaPlayer + QAudioOutput，使用 QNetworkAccessManager
//       发送带正确 HTTP Header 的请求，解决 B站 CDN 403 问题
// ============================================================================

#pragma once

#include <QObject>
#include <QBuffer>
#include <QMediaPlayer>

class QAudioOutput;
class QNetworkAccessManager;
class QNetworkReply;

/**
 * @brief 播放器控制器，负责“把一个真实媒体 URL 播放出来”。
 *
 * 新人阅读边界：
 * - 本类不负责调用 B站 API，也不负责判断收藏夹条目是音频还是视频。
 * - MediaResolver 解析出可播放 URL 后，才把 URL 交给 PlayerController。
 * - QML 通过 Q_PROPERTY 读取播放状态，通过 Q_INVOKABLE 调用播放/暂停/seek。
 *
 * 为什么这里有 QNetworkAccessManager 和 QBuffer？
 * B站 CDN 资源通常要求请求里带 User-Agent / Referer。Qt Multimedia 的
 * QMediaPlayer::setSource(url) 不方便给底层 HTTP 请求补这些 Header，
 * 所以这里先用 QNetworkAccessManager 下载到内存，再用 QBuffer 包装成
 * QIODevice 交给 QMediaPlayer 播放。
 */
class PlayerController : public QObject
{
    Q_OBJECT

    // Q_PROPERTY 会把 C++ 属性暴露给 QML。QML 绑定这些属性后，
    // 对应的 NOTIFY 信号发出时界面会自动刷新。
    Q_PROPERTY(QString source READ source WRITE setSource NOTIFY sourceChanged)
    Q_PROPERTY(int position READ position NOTIFY positionChanged)
    Q_PROPERTY(int duration READ duration NOTIFY durationChanged)
    Q_PROPERTY(qreal volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(QString playbackState READ playbackState NOTIFY stateChanged)
    Q_PROPERTY(QString mediaTitle READ mediaTitle WRITE setMediaTitle NOTIFY mediaTitleChanged)
    Q_PROPERTY(QString mediaCover READ mediaCover WRITE setMediaCover NOTIFY mediaCoverChanged)

public:
    explicit PlayerController(QObject *parent = nullptr);

    QString source() const;
    void setSource(const QString &url);
    int position() const;
    int duration() const;
    qreal volume() const;
    QString playbackState() const;

    QString mediaTitle() const;
    void setMediaTitle(const QString &title);
    QString mediaCover() const;
    void setMediaCover(const QString &cover);

    // Q_INVOKABLE 表示这些 C++ 方法可以直接在 QML 中调用，
    // 例如: applicationContext.playerController.pause()
    Q_INVOKABLE void play();
    Q_INVOKABLE void pause();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void seek(int positionMs);
    Q_INVOKABLE void setVolume(qreal vol);

signals:
    void sourceChanged();
    void positionChanged();
    void durationChanged();
    void volumeChanged();
    void stateChanged();
    void mediaTitleChanged();
    void mediaCoverChanged();
    void playerError(int errorCode, const QString &errorString);
    void trackFinished();  // 当前音轨自然播放到结尾时发射

private slots:
    // 这些槽函数只处理 QMediaPlayer 发出的状态变化，再转成项目自己的信号。
    void onStateChanged();
    void onErrorOccurred();
    void onMediaStatusChanged(QMediaPlayer::MediaStatus status);

private:
    // QObject 子对象都以 this 为 parent，PlayerController 析构时会自动释放。
    QMediaPlayer *m_player;
    QAudioOutput *m_audioOutput;
    QNetworkAccessManager *m_nam;
    QNetworkReply *m_currentReply; // 当前正在下载的媒体请求，切歌时需要中止旧请求
    QBuffer *m_mediaBuffer;        // 缓存下载后的媒体数据，作为 QMediaPlayer 的输入设备

    QString m_source;
    QString m_mediaTitle;
    QString m_mediaCover;
    // play() 可能早于媒体加载完成被调用；这个标志表示“加载完后立刻播放”。
    bool m_pendingPlay = false;
};
