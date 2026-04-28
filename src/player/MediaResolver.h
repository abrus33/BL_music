// ============================================================================
// MediaResolver.h - 媒体链接解析器
// 功能：将收藏夹中的音频/视频条目解析为可播放的流媒体 URL
// 数据流：收藏条目(auid/bvid+cid) -> BilibiliApiClient -> 播放URL -> QMediaPlayer
// ============================================================================

#pragma once

#include <QObject>
#include <QString>

class BilibiliApiClient;

/**
 * @brief 媒体链接解析器
 *
 * 负责将收藏夹中的媒体条目解析为可播放的 URL：
 *
 * 音频（type=12）：
 *   调用 BilibiliApiClient::getAudioStreamUrl(audioId)
 *   返回 m4a 格式的音频流 URL，QMediaPlayer 可直接播放
 *
 * 视频（type=2）：
 *   调用 BilibiliApiClient::getVideoPlayUrl(bvid, cid)
 *   返回 mp4 或 DASH 格式的视频 URL
 *
 * 使用场景：
 *   用户点击收藏夹中的某个条目时 -> MediaResolver 解析出播放 URL
 *   -> 将 URL 传递给 PlayerController 开始播放
 */
class MediaResolver : public QObject
{
    Q_OBJECT

public:
    /**
     * @brief 构造函数
     * @param apiClient BilibiliApiClient 实例
     * @param parent    Qt 父对象
     */
    explicit MediaResolver(BilibiliApiClient *apiClient, QObject *parent = nullptr);

    /**
     * @brief 解析媒体为播放 URL
     * @param id      音频 auid 或视频 avid
     * @param type    内容类型（2=视频, 12=音频）
     * @param bvid    视频 BV 号（视频专用）
     * @param cid     视频分 P ID（视频专用，默认为 0 表示第一分 P）
     *
     * 结果通过 mediaResolved 信号返回
     */
    Q_INVOKABLE void resolve(qint64 id, int type, const QString &bvid = QString(), qint64 cid = 0);

signals:
    /**
     * @brief 媒体解析完成信号
     * @param success 是否成功
     * @param url     可播放的流媒体 URL
     * @param title   媒体标题
     * @param cover   封面 URL
     * @param duration 时长（秒）
     * @param error   错误信息
     */
    void mediaResolved(bool success, const QString &url, const QString &title,
                       const QString &cover, int duration, const QString &error);

private:
    /** B站 API 客户端 */
    BilibiliApiClient *m_apiClient;
};
