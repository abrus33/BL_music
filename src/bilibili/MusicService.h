// ============================================================================
// MusicService.h - 音乐区服务
// 功能：获取 B站音乐热门榜单并转化为 QML 可用的 JSON
// ============================================================================

#pragma once

#include <QObject>
#include <QString>

class BilibiliApiClient;

class MusicService : public QObject
{
    Q_OBJECT
public:
    explicit MusicService(BilibiliApiClient *apiClient, QObject *parent = nullptr);

    Q_INVOKABLE void loadMusicRank(int page = 1, int pageSize = 10);

signals:
    void musicRankLoaded(bool success, const QString &jsonData, const QString &error);

private:
    BilibiliApiClient *m_apiClient;
};
