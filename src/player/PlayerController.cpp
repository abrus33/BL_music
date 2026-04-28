// ============================================================================
// PlayerController.cpp - 播放器控制器实现
// 功能：使用 QNetworkAccessManager 下载音频到 QBuffer，
//       再通过 setSourceDevice() 播放，解决 CDN 403 和流式播放问题
// ============================================================================

#include "PlayerController.h"

#include <QMediaPlayer>
#include <QAudioOutput>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QBuffer>
#include <QUrl>
#include <QDebug>

#define DBG qDebug().noquote() << "[PlayerController]"

PlayerController::PlayerController(QObject *parent)
    : QObject(parent)
    , m_player(new QMediaPlayer(this))
    , m_audioOutput(new QAudioOutput(this))
    , m_nam(new QNetworkAccessManager(this))
    , m_currentReply(nullptr)
    , m_mediaBuffer(nullptr)
{
    m_player->setAudioOutput(m_audioOutput);

    connect(m_player, &QMediaPlayer::playbackStateChanged,
            this, &PlayerController::onStateChanged);
    connect(m_player, &QMediaPlayer::positionChanged,
            this, &PlayerController::positionChanged);
    connect(m_player, &QMediaPlayer::durationChanged,
            this, &PlayerController::durationChanged);
    connect(m_player, &QMediaPlayer::errorOccurred,
            this, &PlayerController::onErrorOccurred);
    connect(m_player, &QMediaPlayer::sourceChanged,
            this, &PlayerController::sourceChanged);

    DBG << "PlayerController 初始化完成";
}

QString PlayerController::source() const { return m_source; }

/**
 * @brief 设置播放源
 *
 * 流程：
 * 1. 用 QNetworkAccessManager 发送带 User-Agent/Referer 的 GET 请求
 * 2. 等待下载完成
 * 3. 将数据写入 QBuffer（内存缓冲区）
 * 4. 通过 setSourceDevice() 传给 QMediaPlayer
 */
void PlayerController::setSource(const QString &url)
{
    if (m_source == url && !url.isEmpty())
        return;

    DBG << "setSource:" << url.left(80) << "...";

    // 清理旧资源
    if (m_currentReply) {
        m_currentReply->disconnect();
        m_currentReply->abort();
        m_currentReply->deleteLater();
        m_currentReply = nullptr;
    }
    if (m_mediaBuffer) {
        m_player->setSourceDevice(nullptr, QUrl());  // 清除设备源
        delete m_mediaBuffer;
        m_mediaBuffer = nullptr;
    }

    m_source = url;

    // 发起带正确 HTTP Header 的请求
    QUrl qurl(url);
    QNetworkRequest request(qurl);
    request.setRawHeader("User-Agent",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/120.0.0.0 Safari/537.36");
    request.setRawHeader("Referer", "https://www.bilibili.com");

    QNetworkReply *reply = m_nam->get(request);
    m_currentReply = reply;

    // 连接下载完成信号
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        m_currentReply = nullptr;  // 防止重复清理

        if (reply->error() != QNetworkReply::NoError) {
            DBG << "下载失败:" << reply->errorString();
            emit playerError(static_cast<int>(reply->error()), reply->errorString());
            reply->deleteLater();
            return;
        }

        // 读取所有下载数据
        QByteArray data = reply->readAll();
        DBG << "下载完成, 大小:" << data.size() << "字节";
        reply->deleteLater();

        if (data.isEmpty()) {
            DBG << "下载数据为空!";
            emit playerError(-1, QStringLiteral("下载数据为空"));
            return;
        }

        // 将数据写入 QBuffer 并设为播放源
        m_mediaBuffer = new QBuffer(this);
        m_mediaBuffer->setData(data);
        m_mediaBuffer->open(QIODevice::ReadOnly);

        DBG << "设置 QBuffer 为播放源设备, 大小:" << data.size();
        m_player->setSourceDevice(m_mediaBuffer, QUrl());
        emit sourceChanged();

        // 标记待播放并在媒体加载完成后自动播放
        m_pendingPlay = true;
    });

    // 网络错误处理
    connect(reply, &QNetworkReply::errorOccurred, this, [this](QNetworkReply::NetworkError err) {
        DBG << "网络错误:" << err;
    });
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
    if (qAbs(m_audioOutput->volume() - vol) < 0.0001)
        return;
    m_audioOutput->setVolume(vol);
    emit volumeChanged();
}

QString PlayerController::playbackState() const
{
    switch (m_player->playbackState()) {
    case QMediaPlayer::PlayingState: return QStringLiteral("Playing");
    case QMediaPlayer::PausedState: return QStringLiteral("Paused");
    default: return QStringLiteral("Stopped");
    }
}

QString PlayerController::mediaTitle() const { return m_mediaTitle; }
void PlayerController::setMediaTitle(const QString &title)
{
    if (m_mediaTitle == title) return;
    m_mediaTitle = title;
    emit mediaTitleChanged();
}

QString PlayerController::mediaCover() const { return m_mediaCover; }
void PlayerController::setMediaCover(const QString &cover)
{
    if (m_mediaCover == cover) return;
    m_mediaCover = cover;
    emit mediaCoverChanged();
}

// ==================== 控制方法 ====================

void PlayerController::play()
{
    DBG << "play(), playState:" << playbackState()
        << "duration:" << m_player->duration();
    m_pendingPlay = false;

    if (m_player->playbackState() != QMediaPlayer::StoppedState ||
        m_player->duration() > 0) {
        m_player->play();
    } else {
        DBG << "媒体尚未加载完成, 设置 pendingPlay";
        m_pendingPlay = true;
    }
}

void PlayerController::pause()
{
    DBG << "pause()";
    m_pendingPlay = false;
    m_player->pause();
}

void PlayerController::stop()
{
    m_pendingPlay = false;
    m_player->stop();
}

void PlayerController::seek(int positionMs)
{
    if (m_player->duration() <= 0) return;
    DBG << "seek:" << positionMs;
    m_player->setPosition(positionMs);
}

void PlayerController::onStateChanged()
{
    DBG << "playbackState:" << playbackState()
        << "pendingPlay:" << m_pendingPlay;
    emit stateChanged();
}

void PlayerController::onErrorOccurred()
{
    QMediaPlayer::Error err = m_player->error();
    QString errorStr = m_player->errorString();
    qWarning().noquote() << "[PlayerController] 错误:" << err << errorStr;
    emit playerError(static_cast<int>(err), errorStr);
}
