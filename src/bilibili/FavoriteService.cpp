// ============================================================================
// FavoriteService.cpp - 收藏夹服务实现
// 功能：调用 BilibiliApiClient 获取收藏夹数据，通过信号返回给 QML
// ============================================================================

#include "FavoriteService.h"

#include <QTimer>
#include <QThread>
#include <QDebug>

#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>

#include "bilibili/BilibiliApiClient.h"

#define DBG qDebug().noquote() << "[FavoriteService]"

/**
 * @brief 构造函数
 * @param apiClient BilibiliApiClient 指针
 * @param parent    Qt 父对象
 */
FavoriteService::FavoriteService(BilibiliApiClient *apiClient, QObject *parent)
    : QObject(parent)
    , m_apiClient(apiClient)
{
    DBG << "FavoriteService 初始化, thread:" << QThread::currentThread();
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
    DBG << "loadFavoriteFolders() mid:" << upMid << "thread:" << QThread::currentThread();

    m_apiClient->getFavoriteFolderList(upMid,
        [this, upMid](bool success, QJsonArray folders, QString error) {
        DBG << "loadFavoriteFolders 响应: success=" << success
            << "count:" << folders.size() << "error:" << error;

        // 将 QJsonArray 序列化为字符串，通过信号传递给 QML
        // 因为 QML 不能直接处理 QJsonArray 类型
        QString jsonStr;
        if (success) {
            jsonStr = QString::fromUtf8(QJsonDocument(folders).toJson(QJsonDocument::Compact));
        }
        emit favoriteFoldersLoaded(upMid, success, jsonStr, error);
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
    DBG << "loadFavoriteResources() mediaId:" << mediaId
        << "page:" << page << "pageSize:" << pageSize
        << "thread:" << QThread::currentThread();

    m_apiClient->getFavoriteResourceList(mediaId, page, pageSize,
        [this, mediaId, page](bool success, QJsonObject info, QJsonArray medias,
                               bool hasMore, QString error) {
        DBG << "loadFavoriteResources 响应: mediaId:" << mediaId
            << "page:" << page << "success:" << success
            << "medias_count:" << medias.size() << "hasMore:" << hasMore
            << "error:" << error;

        // 序列化为字符串传递给 QML
        QString infoStr = QString::fromUtf8(QJsonDocument(info).toJson(QJsonDocument::Compact));
        QString mediasStr = QString::fromUtf8(QJsonDocument(medias).toJson(QJsonDocument::Compact));
        emit favoriteResourcesLoaded(success, infoStr, mediasStr, hasMore, error);
    });
}

/**
 * @brief 加载收藏夹全部内容（Q_INVOKABLE，QML 可调用）
 * @param mediaId  收藏夹 mlid
 *
 * QML 调用示例：
 *   applicationContext.favoriteService.loadAllFavoriteResources(mediaId)
 *
 * 内部通过 loadFavoritesPage + QTimer::singleShot 递归加载所有分页数据。
 * 在所有分页加载完成后通过 allFavoriteResourcesLoaded 信号一次性返回。
 *
 * 与 loadFavoriteResources 的区别：
 *   - loadFavoriteResources: 只加载一页，发射 favoriteResourcesLoaded 信号
 *   - loadAllFavoriteResources: 自动翻页加载全部，发射 allFavoriteResourcesLoaded 信号
 */
void FavoriteService::loadAllFavoriteResources(qint64 mediaId)
{
    DBG << "============================================================";
    DBG << "loadAllFavoriteResources() START mediaId:" << mediaId
        << "thread:" << QThread::currentThread();

    const quint64 generation = m_loadSession.begin(mediaId);

    // 从第一页开始递归加载
    loadFavoritesPage(mediaId, 1, 20, generation);
}

/**
 * @brief 逐页加载收藏夹内容
 * @param mediaId  收藏夹 mlid
 * @param page     当前页码
 * @param pageSize 每页数量
 *
 * 通过 QTimer::singleShot(0) 把下一页请求延迟到主线程事件循环，
 * 确保 getFavoriteResourceList 始终在主线程中调用。
 *
 * 使用 FavoriteLoadSession 管理状态：
 *   - loadAllFavoriteResources 开启新 generation 并清空累积数据
 *   - 回调仅在 generation 仍为当前代次时追加数据
 *   - hasMore==true 时通过 singleShot 排队递归
 *   - 全部完成或失败时 emit allFavoriteResourcesLoaded
 */
void FavoriteService::loadFavoritesPage(qint64 mediaId, int page, int pageSize,
                                        quint64 generation)
{
    if (!m_loadSession.accepts(generation))
        return;

    DBG << "loadFavoritesPage() page:" << page
        << "mediaId:" << mediaId << "thread:" << QThread::currentThread();

    m_apiClient->getFavoriteResourceList(mediaId, page, pageSize,
        [this, mediaId, page, pageSize, generation](bool success, QJsonObject /*info*/,
                                                    QJsonArray medias, bool hasMore,
                                                    QString error) {
        if (!m_loadSession.accepts(generation))
            return;

        DBG << "loadFavoritesPage 回调: page:" << page
            << "success:" << success
            << "medias_count:" << medias.size()
            << "hasMore:" << hasMore
            << "error:" << error
            << "accumulated_so_far:" << m_loadSession.items().size();

        if (!success) {
            DBG << "loadFavoritesPage: 请求失败, 终止累积. 已累积:"
                << m_loadSession.items().size();
            const QJsonArray items = m_loadSession.items();
            QString mediasStr = QString::fromUtf8(
                QJsonDocument(items).toJson(QJsonDocument::Compact));
            m_loadSession.finish(generation);
            emit allFavoriteResourcesLoaded(mediaId, false, mediasStr, error);
            return;
        }

        m_loadSession.append(generation, medias);

        DBG << "loadFavoritesPage: 已追加 page" << page
            << "共" << medias.size() << "条, 累积总数:" << m_loadSession.items().size();

        if (hasMore) {
            DBG << "loadFavoritesPage: hasMore=true, 排队加载 page" << (page + 1);
            // 通过 QTimer::singleShot(0) 把下一页请求延迟到事件循环
            // 确保始终在主线程中调用 getFavoriteResourceList，
            // 避免在 QNetworkAccessManager 回调线程中直接创建子对象
            QTimer::singleShot(0, this, [this, mediaId, page, pageSize, generation]() {
                if (!m_loadSession.accepts(generation))
                    return;

                DBG << "loadFavoritesPage: singleShot 触发, 加载 page" << (page + 1)
                    << "generation:" << generation;
                loadFavoritesPage(mediaId, page + 1, pageSize, generation);
            });
        } else {
            // 全部加载完成
            DBG << "============================================================";
            DBG << "loadFavoritesPage: ★ 全部加载完成! 总条数:" << m_loadSession.items().size();
            DBG << "============================================================";
            const QJsonArray items = m_loadSession.items();
            QString mediasStr = QString::fromUtf8(
                QJsonDocument(items).toJson(QJsonDocument::Compact));
            m_loadSession.finish(generation);
            emit allFavoriteResourcesLoaded(mediaId, true, mediasStr, QString());
        }
    });
}
