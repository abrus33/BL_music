// ============================================================================
// FavoriteService.cpp - 收藏夹服务实现
// 功能：调用 BilibiliApiClient 获取收藏夹数据，通过信号返回给 QML
// ============================================================================

#include "FavoriteService.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>

#include "bilibili/BilibiliApiClient.h"

/**
 * @brief 构造函数
 * @param apiClient BilibiliApiClient 指针
 * @param parent    Qt 父对象
 */
FavoriteService::FavoriteService(BilibiliApiClient *apiClient, QObject *parent)
    : QObject(parent)
    , m_apiClient(apiClient)
{
}

/**
 * @brief 加载收藏夹列表（Q_INVOKABLE，QML 可调用）
 * @param upMid 用户 mid
 *
 * QML 调用示例：
 *   applicationContext.favoriteService.loadFavoriteFolders(mid)
 *
 * 结果通过 favoriteFoldersLoaded 信号返回 QML
 */
void FavoriteService::loadFavoriteFolders(qint64 upMid)
{
    m_apiClient->getFavoriteFolderList(upMid,
        [this](bool success, QJsonArray folders, QString error) {
        // 将 QJsonArray 序列化为字符串，通过信号传递给 QML
        // 因为 QML 不能直接处理 QJsonArray 类型
        QString jsonStr;
        if (success) {
            jsonStr = QString::fromUtf8(QJsonDocument(folders).toJson(QJsonDocument::Compact));
        }
        emit favoriteFoldersLoaded(success, jsonStr, error);
    });
}

/**
 * @brief 加载收藏夹内容（Q_INVOKABLE，QML 可调用）
 * @param mediaId  收藏夹 mlid
 * @param page     页码
 * @param pageSize 每页数量
 *
 * QML 调用示例：
 *   applicationContext.favoriteService.loadFavoriteResources(mediaId, 1, 20)
 *
 * 结果通过 favoriteResourcesLoaded 信号返回 QML
 */
void FavoriteService::loadFavoriteResources(qint64 mediaId, int page, int pageSize)
{
    m_apiClient->getFavoriteResourceList(mediaId, page, pageSize,
        [this](bool success, QJsonObject info, QJsonArray medias, bool hasMore, QString error) {
        // 序列化为字符串传递给 QML
        QString infoStr = QString::fromUtf8(QJsonDocument(info).toJson(QJsonDocument::Compact));
        QString mediasStr = QString::fromUtf8(QJsonDocument(medias).toJson(QJsonDocument::Compact));
        emit favoriteResourcesLoaded(success, infoStr, mediasStr, hasMore, error);
    });
}
