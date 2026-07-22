#include "MediaResolver.h"

#include <QDebug>
#include <QPointer>

#include "bilibili/BilibiliApiClient.h"

#define DBG qDebug().noquote() << "[MediaResolver]"

MediaResolver::MediaResolver(BilibiliApiClient *apiClient, QObject *parent)
    : QObject(parent)
    , m_apiClient(apiClient)
{
}

void MediaResolver::resolve(qint64 id, int type, const QString &bvid, qint64 cid)
{
    const QPointer<MediaResolver> self(this);
    resolveInternal(id, type, bvid, cid,
                    [self](bool success, const QString &url, const QString &error) {
        if (!self)
            return;
        emit self->mediaResolved(success, url, QString(), QString(), 0, error);
    });
}

void MediaResolver::resolveForOwner(const QString &ownerToken, qint64 id, int type,
                                    const QString &bvid, qint64 cid)
{
    const QPointer<MediaResolver> self(this);
    resolveInternal(id, type, bvid, cid,
                    [self, ownerToken](bool success, const QString &url,
                                       const QString &error) {
        if (!self)
            return;
        emit self->mediaResolvedForOwner(ownerToken, success, url, QString(),
                                         QString(), 0, error);
    });
}

void MediaResolver::resolveInternal(qint64 id, int type, const QString &bvid,
                                    qint64 cid, ResultHandler handler)
{
    DBG << "resolve - id:" << id << "type:" << type << "bvid:" << bvid;

    if (!m_apiClient) {
        handler(false, QString(), QStringLiteral("Media API is unavailable"));
        return;
    }

    const QPointer<MediaResolver> self(this);

    if (type == 12) {
        m_apiClient->getAudioStreamUrl(
            id, [self, handler](bool success, QString url, QString error) {
                if (!self)
                    return;
                handler(success, url, error);
            });
        return;
    }

    if (type == 2) {
        if (bvid.isEmpty()) {
            handler(false, QString(), QStringLiteral("视频解析需要 bvid 参数"));
            return;
        }

        const auto resolvePlayUrl = [self, bvid, handler](qint64 videoCid) {
            if (!self)
                return;
            self->m_apiClient->getVideoPlayUrl(
                bvid, videoCid,
                [self, handler](bool playSuccess, QString url,
                                QString playError) {
                    if (!self)
                        return;
                    handler(playSuccess, url, playError);
                });
        };

        if (cid > 0) {
            resolvePlayUrl(cid);
            return;
        }

        m_apiClient->getVideoCid(
            bvid, [self, resolvePlayUrl, handler](bool success, qint64 resolvedCid,
                                                  QString error) {
                if (!self)
                    return;
                if (!success) {
                    handler(false, QString(), error);
                    return;
                }

                resolvePlayUrl(resolvedCid);
            });
        return;
    }

    handler(false, QString(),
            QStringLiteral("不支持的媒体类型: ") + QString::number(type));
}
