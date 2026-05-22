// ============================================================================
// MusicService.cpp - 音乐区服务实现
// ============================================================================

#include "MusicService.h"
#include "BilibiliApiClient.h"
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>

MusicService::MusicService(BilibiliApiClient *apiClient, QObject *parent)
    : QObject(parent), m_apiClient(apiClient) {}

void MusicService::loadMusicRank(int page, int pageSize)
{
    m_apiClient->getMusicRank(page, pageSize,
        [this](bool success, QJsonArray charts, QString error) {
        if (!success) { emit musicRankLoaded(false, QString(), error); return; }

        // 将榜单中的音频提取为扁平列表，附带榜单封面信息
        QJsonArray result;
        for (int i = 0; i < charts.size(); ++i) {
            QJsonObject chart = charts[i].toObject();
            QString chartTitle = chart.value("title").toString();
            QString chartCover = chart.value("cover").toString();
            QString chartUname = chart.value("uname").toString();
            QJsonArray audios = chart.value("audios").toArray();
            for (int j = 0; j < audios.size(); ++j) {
                QJsonObject a = audios[j].toObject();
                QJsonObject item;
                item["id"] = a["id"];
                item["title"] = a["title"];
                item["duration"] = a["duration"];
                item["cover"] = chartCover;
                item["artist"] = chartUname;
                item["chart"] = chartTitle;
                result.append(item);
            }
        }
        emit musicRankLoaded(true,
            QString::fromUtf8(QJsonDocument(result).toJson(QJsonDocument::Compact)), QString());
    });
}
