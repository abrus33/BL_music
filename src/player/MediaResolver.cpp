// ============================================================================
// MediaResolver.cpp - 媒体链接解析器实现
// 功能：将音频/视频条目解析为可播放的流媒体 URL
// ============================================================================

#include "MediaResolver.h"

#include <QJsonObject>
#include <QJsonArray>
#include <QDebug>

#include "bilibili/BilibiliApiClient.h"

#define DBG qDebug().noquote() << "[MediaResolver]"

MediaResolver::MediaResolver(BilibiliApiClient *apiClient, QObject *parent)
    : QObject(parent)
    , m_apiClient(apiClient)
{
}

/**
 * @brief 把收藏夹条目解析成 PlayerController 能播放的真实 URL。
 *
 * B站收藏夹里可能混有两类内容：
 * - type=12：音频内容，id 就是 auid，可以直接请求音频 URL。
 * - type=2：视频内容，需要先用 bvid 换 cid，再请求 DASH/MP4 播放地址。
 *
 * 这是异步函数：调用后不会立刻返回 URL，而是等网络请求完成后发出
 * mediaResolved(success, url, ...) 信号。QML 或 PlaylistService 监听这个信号。
 */
void MediaResolver::resolve(qint64 id, int type, const QString &bvid, qint64 cid)
{
    DBG << "resolve() 被调用 - id:" << id << "type:" << type << "bvid:" << bvid;

    if (type == 12) {
        // ===== 音频解析 =====
        DBG << "开始解析音频 auid:" << id;
        m_apiClient->getAudioStreamUrl(id,
            [this, id](bool success, QString url, QString error) {
            DBG << "音频解析完成 - success:" << success
                << "url.length:" << url.length()
                << "error:" << error;
            if (success) {
                DBG << "音频URL (前100字符):" << url.left(100);
            }
            emit mediaResolved(success, url, QString(), QString(), 0, error);
        });
    } else if (type == 2) {
        // ===== 视频解析 =====
        // 视频 API 需要 cid。收藏夹条目通常只有 bvid，所以步骤是：
        // 1. view API: bvid -> cid
        // 2. playurl API: bvid + cid -> 音频流 URL
        if (bvid.isEmpty()) {
            DBG << "视频解析失败: bvid 为空";
            emit mediaResolved(false, QString(), QString(), QString(), 0,
                               QStringLiteral("视频解析需要 bvid 参数"));
            return;
        }
        DBG << "开始解析视频 bvid:" << bvid;
        // 先通过 view API 获取 cid
        m_apiClient->getVideoCid(bvid,
            [this, bvid](bool ok, qint64 cid, QString err) {
            if (!ok) {
                DBG << "获取cid失败:" << err;
                emit mediaResolved(false, QString(), QString(), QString(), 0, err);
                return;
            }
            DBG << "获取cid成功:" << cid << "，继续获取播放URL";
            // 音乐客户端只关心声音，BilibiliApiClient 会优先取 DASH audio。
            m_apiClient->getVideoPlayUrl(bvid, cid,
                [this, bvid](bool success, QString url, QString error) {
                DBG << "视频URL解析完成 - success:" << success;
                emit mediaResolved(success, url, QString(), QString(), 0, error);
            });
        });
    } else {
        DBG << "不支持的媒体类型:" << type;
        emit mediaResolved(false, QString(), QString(), QString(), 0,
                           QStringLiteral("不支持的媒体类型: ") + QString::number(type));
    }
}
