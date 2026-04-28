// ============================================================================
// FavoriteService.h - 收藏夹服务
// 功能：读取用户的 B站收藏夹列表和收藏内容
// 数据流：QML请求 -> FavoriteService -> BilibiliApiClient -> HTTP -> JSON -> QML
// ============================================================================

#pragma once

#include <QObject>
#include <QJsonObject>
#include <QJsonArray>

class BilibiliApiClient;

/**
 * @brief 收藏夹服务
 *
 * 封装收藏夹相关的业务逻辑：
 * - 获取用户创建的所有收藏夹列表
 * - 获取指定收藏夹中的内容（支持分页）
 * - 区分音频（type=12）和视频（type=2）内容
 *
 * 数据模型：
 * 收藏夹列表项：{ id, title, media_count, cover, ... }
 * 收藏内容项：  { id, type, title, cover, duration, upper.name, bvid, ... }
 *    type=2  -> 视频稿件
 *    type=12 -> 音频
 *    type=21 -> 视频合集
 */
class FavoriteService : public QObject
{
    Q_OBJECT

public:
    /**
     * @brief 构造函数
     * @param apiClient BilibiliApiClient 实例
     * @param parent    Qt 父对象
     */
    explicit FavoriteService(BilibiliApiClient *apiClient, QObject *parent = nullptr);

    /**
     * @brief 获取收藏夹列表
     * @param upMid 用户 mid
     *
     * 结果通过 favoriteFoldersLoaded 信号返回
     */
    Q_INVOKABLE void loadFavoriteFolders(qint64 upMid);

    /**
     * @brief 获取收藏夹内容
     * @param mediaId  收藏夹 mlid
     * @param page     页码
     * @param pageSize 每页数量
     *
     * 结果通过 favoriteResourcesLoaded 信号返回
     */
    Q_INVOKABLE void loadFavoriteResources(qint64 mediaId, int page, int pageSize);

signals:
    /**
     * @brief 收藏夹列表加载完成信号
     * @param success 是否成功
     * @param folders JSON 数组字符串（可直接在 QML 中 parse）
     * @param error   错误信息
     */
    void favoriteFoldersLoaded(bool success, const QString &foldersJson, const QString &error);

    /**
     * @brief 收藏夹内容加载完成信号
     * @param success   是否成功
     * @param infoJson  收藏夹元数据 JSON
     * @param mediasJson 内容列表 JSON 数组
     * @param hasMore   是否有下一页
     * @param error     错误信息
     */
    void favoriteResourcesLoaded(bool success, const QString &infoJson,
                                  const QString &mediasJson, bool hasMore,
                                  const QString &error);

private:
    /** B站 API 客户端 */
    BilibiliApiClient *m_apiClient;
};
