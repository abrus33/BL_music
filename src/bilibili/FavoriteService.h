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

    /**
     * @brief 获取收藏夹全部内容（自动翻页直到 hasMore==false）
     * @param mediaId 收藏夹 mlid
     *
     * 内部递归调用 getFavoriteResourceList，逐页累积所有数据。
     * 结果通过 allFavoriteResourcesLoaded 信号一次性返回完整的 JSON 数组。
     *
     * 用于创建完整播放列表（而不是仅加载第一页 20 条）
     */
    Q_INVOKABLE void loadAllFavoriteResources(qint64 mediaId);

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

    /**
     * @brief 收藏夹全部内容加载完成信号（loadAllFavoriteResources 专用）
     * @param success    是否成功
     * @param mediasJson 全部内容的 JSON 数组字符串
     * @param error      错误信息（仅在 success==false 时有意义）
     *
     * 与 favoriteResourcesLoaded 的区别：
     *   此信号在所有分页加载完成后一次性发射，mediasJson 包含全部数据，
     *   而不是逐页返回。
     */
    void allFavoriteResourcesLoaded(bool success, const QString &mediasJson,
                                    const QString &error);

private:
    /** B站 API 客户端 */
    BilibiliApiClient *m_apiClient;

    /**
     * @brief 逐页递归加载收藏夹内容
     * @param mediaId  收藏夹 mlid
     * @param page     当前页码
     * @param pageSize 每页数量
     *
     * 内部由 loadAllFavoriteResources 启动，通过网络回调 + QMetaObject::invokeMethod
     * 递归调用自身直到 hasMore==false，然后发射 allFavoriteResourcesLoaded 信号。
     * 使用 QMetaObject::invokeMethod 确保每次递归调用都回到主线程，避免跨线程创建 QObject 子对象。
     */
    void loadFavoritesPage(qint64 mediaId, int page, int pageSize);

    /** 全量加载的累积数据（由 loadAllFavoriteResources 初始化，loadFavoritesPage 追加） */
    QJsonArray m_accumulatedMedias;
    /** 全量加载是否正在进行中（用于丢弃过期的异步回调） */
    bool m_accumulating = false;
};
