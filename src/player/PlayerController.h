// ============================================================================
// PlayerController.h - 播放器控制器
// 功能：封装 QMediaPlayer + QAudioOutput，使用 QNetworkAccessManager
//       发送带正确 HTTP Header 的请求，解决 B站 CDN 403 问题
// ============================================================================

#pragma once

#include <QObject>
#include <QBuffer>

class QMediaPlayer;
class QAudioOutput;
class QNetworkAccessManager;
class QNetworkReply;

class PlayerController : public QObject
{
    Q_OBJECT

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

private slots:
    void onStateChanged();
    void onErrorOccurred();

private:
    QMediaPlayer *m_player;
    QAudioOutput *m_audioOutput;
    QNetworkAccessManager *m_nam;
    QNetworkReply *m_currentReply;
    QBuffer *m_mediaBuffer;        // 缓存下载的音频数据

    QString m_source;
    QString m_mediaTitle;
    QString m_mediaCover;
    bool m_pendingPlay = false;
};
