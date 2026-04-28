// ============================================================================
// MediaResolver.cpp - 媒体链接解析器实现
// 功能：将音频/视频条目解析为可播放的流媒体 URL
// ============================================================================

#include "MediaResolver.h"

#include <QJsonObject>
#include <QJsonArray>

#include "bilibili/BilibiliApiClient.h"

/**
 * @brief 构造函数
 * @param apiClient BilibiliApiClient 指针
 * @param parent    Qt 父对象
 */
MediaResolver::MediaResolver(BilibiliApiClient *apiClient, QObject *parent)
    : QObject(parent)
    , m_apiClient(apiClient)
{
}

/**
 * @brief 解析媒体（Q_INVOKABLE，QML 可调用）
 * @param id    音频 auid 或视频 avid
 * @param type  内容类型：2=视频，12=音频
 * @param bvid  视频 BV 号（仅视频需要）
 * @param cid   视频分 P ID（仅视频需要）
 *
 * QML 调用示例：
 *   // 解析音频
 *   applicationContext.mediaResolver.resolve(15664, 12)
 *   // 解析视频
 *   applicationContext.mediaResolver.resolve(0, 2, "BV1CZ4y1T7gC", 123456)
 *
 * 根据 type 分流到不同的 API：
 * - type=12（音频）：调用 getAudioStreamUrl(id)
 * - type=2（视频）：调用 getVideoPlayUrl(bvid, cid)
 */
void MediaResolver::resolve(qint64 id, int type, const QString &bvid, qint64 cid)
{
    if (type == 12) {
        // ===== 音频解析 =====
        m_apiClient->getAudioStreamUrl(id,
            [this](bool success, QString url, QString error) {
            emit mediaResolved(success, url, QString(), QString(), 0, error);
        });
    } else if (type == 2) {
        // ===== 视频解析 =====
        if (bvid.isEmpty()) {
            emit mediaResolved(false, QString(), QString(), QString(), 0,
                               QStringLiteral("视频解析需要 bvid 参数"));
            return;
        }
        m_apiClient->getVideoPlayUrl(bvid, cid,
            [this](bool success, QString url, QString error) {
            emit mediaResolved(success, url, QString(), QString(), 0, error);
        });
    } else {
        // 不支持的媒体类型
        emit mediaResolved(false, QString(), QString(), QString(), 0,
                           QStringLiteral("不支持的媒体类型: ") + QString::number(type));
    }
}
