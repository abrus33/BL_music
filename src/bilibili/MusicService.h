// ============================================================================
// MusicService.h - 音乐区服务
// 功能：获取 B站音乐热门榜单并转化为 QML 可用的 JSON
// ============================================================================

#pragma once

#include <QObject>
#include <QString>

class BilibiliApiClient;

/**
 * @brief 音乐区服务，给 QML 首页提供热门音乐列表。
 *
 * 与 FavoriteService 类似，本类不直接返回 QJsonArray 给 QML，而是把结果
 * 序列化成 JSON 字符串，通过 musicRankLoaded 信号发出去。这样 QML 侧可以
 * 用 JSON.parse() 得到普通 JavaScript 数组，直接交给 Repeater。
 */
class MusicService : public QObject
{
    Q_OBJECT
public:
    explicit MusicService(BilibiliApiClient *apiClient, QObject *parent = nullptr);

    // QML 调用入口：applicationContext.musicService.loadMusicRank(...)
    Q_INVOKABLE void loadMusicRank(int page = 1, int pageSize = 10);

signals:
    // jsonData 是扁平化后的音乐数组字符串；失败时 error 给 UI 显示或调试。
    void musicRankLoaded(bool success, const QString &jsonData, const QString &error);

private:
    // 非拥有指针，生命周期由 ApplicationContext 管理。
    BilibiliApiClient *m_apiClient;
};
