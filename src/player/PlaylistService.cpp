// ============================================================================
// PlaylistService.cpp - 播放列表服务实现
// 功能：播放列表管理、顺序/随机模式、自动切歌、持久化恢复
// ============================================================================

#include "PlaylistService.h"
#include "platform/android/LifecycleDiagnostics.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QDebug>
#include <QRandomGenerator>
#include <algorithm>

#include "storage/AppSettings.h"
#include "player/MediaResolver.h"
#include "player/PlayerController.h"

#define DBG qDebug().noquote() << "[Playlist]"

// ============================================================================
// 构造函数
// ============================================================================

PlaylistService::PlaylistService(AppSettings *settings,
                                 MediaResolver *resolver,
                                 PlayerController *player,
                                 QObject *parent)
    : QObject(parent)
    , m_settings(settings)
    , m_mediaResolver(resolver)
    , m_playerController(player)
{
    // ---- 自动切歌：监听 PlayerController::trackFinished ----
    connect(m_playerController, &PlayerController::trackFinished,
            this, &PlaylistService::onTrackFinished);

    // ---- URL 解析结果：监听 MediaResolver::mediaResolved ----
    connect(m_mediaResolver, &MediaResolver::mediaResolved,
            this, &PlaylistService::onMediaResolved);

    // ---- 位置保存定时器：每 10 秒保存一次播放进度 ----
    m_positionSaveTimer = new QTimer(this);
    m_positionSaveTimer->setInterval(10000);
    connect(m_positionSaveTimer, &QTimer::timeout, this, &PlaylistService::savePosition);

    // ---- 恢复上次的播放列表 ----
    restoreFromSettings();

    DBG << "PlaylistService 初始化完成, items:" << m_items.size()
        << "index:" << m_currentIndex << "mode:" << m_playMode;
}

// ============================================================================
// Accessors
// ============================================================================

int PlaylistService::currentIndex() const { return m_currentIndex; }
int PlaylistService::playlistSize() const { return m_items.size(); }
int PlaylistService::playMode() const { return static_cast<int>(m_playMode); }
bool PlaylistService::isEmpty() const { return m_items.isEmpty(); }

QString PlaylistService::playlistItems() const
{
    QJsonDocument doc(m_items);
    return QString::fromUtf8(doc.toJson(QJsonDocument::Compact));
}

QString PlaylistService::currentItemJson() const
{
    if (m_currentIndex < 0 || m_currentIndex >= m_items.size())
        return QString();
    QJsonObject obj = m_items[m_currentIndex].toObject();
    return QString::fromUtf8(QJsonDocument(obj).toJson(QJsonDocument::Compact));
}

// ============================================================================
// 创建/替换播放列表
// ============================================================================

void PlaylistService::createPlaylist(const QString &itemsJson, qint64 startItemId)
{
    DBG << "createPlaylist startItemId:" << startItemId;

    // 1. 解析 JSON 数组
    QJsonDocument doc = QJsonDocument::fromJson(itemsJson.toUtf8());
    if (!doc.isArray()) {
        qWarning() << "[Playlist] createPlaylist: 无效的 JSON 数组";
        return;
    }
    m_items = doc.array();
    if (m_items.isEmpty()) {
        qWarning() << "[Playlist] createPlaylist: 空数组";
        return;
    }

    // 2. 找到 startItemId 对应的索引
    m_currentIndex = -1;
    for (int i = 0; i < m_items.size(); ++i) {
        qint64 id = static_cast<qint64>(m_items[i].toObject().value(QStringLiteral("id")).toDouble(0));
        if (id == startItemId) {
            m_currentIndex = i;
            break;
        }
    }
    if (m_currentIndex < 0) {
        qWarning() << "[Playlist] createPlaylist: 未找到 startItemId, 从第一项开始";
        m_currentIndex = 0;
    }

    // 3. 重置随机顺序
    m_shuffleOrder.clear();
    m_shufflePointer = 0;
    if (m_playMode == Random) {
        shuffleOrder();
    }

    // 4. 通知 QML
    emit playlistChanged();
    emit currentIndexChanged();
    emit currentItemChanged();

    // 5. 开始解析并播放
    m_isRestoring = false;
    resolveAndPlayCurrentItem();

    // 6. 持久化
    saveToSettings();

    DBG << "createPlaylist done, size:" << m_items.size() << "startIndex:" << m_currentIndex;
}

// ============================================================================
// 播放控制
// ============================================================================

void PlaylistService::next()
{
    BL_LIFECYCLE_EVENT("NEXT_TRACK_REQUEST", {"index", m_currentIndex}, {"size", m_items.size()});
    if (m_items.isEmpty()) return;

    m_currentIndex = computeNextIndex();
    BL_LIFECYCLE_EVENT("NEXT_INDEX", {"index", m_currentIndex});

    emit currentIndexChanged();
    emit currentItemChanged();

    resolveAndPlayCurrentItem();
    saveToSettings();

    DBG << "next() → index:" << m_currentIndex;
}

void PlaylistService::previous()
{
    if (m_items.isEmpty()) return;

    m_currentIndex = computePreviousIndex();

    emit currentIndexChanged();
    emit currentItemChanged();

    resolveAndPlayCurrentItem();
    saveToSettings();

    DBG << "previous() → index:" << m_currentIndex;
}

void PlaylistService::setPlayMode(int mode)
{
    PlayMode newMode = static_cast<PlayMode>(mode);
    if (m_playMode == newMode) return;

    m_playMode = newMode;

    if (m_playMode == Random && !m_items.isEmpty()) {
        // 切换到随机模式: 生成洗牌顺序, 保证当前项在第一位
        shuffleOrder();
    } else {
        m_shuffleOrder.clear();
        m_shufflePointer = 0;
    }

    emit playModeChanged();
    saveToSettings();

    DBG << "setPlayMode:" << mode;
}

void PlaylistService::playAt(int index)
{
    if (m_items.isEmpty()) return;
    if (index < 0 || index >= m_items.size()) {
        qWarning() << "[Playlist] playAt: 索引越界" << index;
        return;
    }

    m_currentIndex = index;

    // 重置随机顺序，当前项排到 shuffleOrder 第一位
    if (m_playMode == Random) {
        shuffleOrder();
    }

    emit currentIndexChanged();
    emit currentItemChanged();

    resolveAndPlayCurrentItem();
    saveToSettings();

    DBG << "playAt() → index:" << index;
}

void PlaylistService::clear()
{
    DBG << "clear()";
    m_items = QJsonArray();
    m_currentIndex = -1;
    m_shuffleOrder.clear();
    m_shufflePointer = 0;
    m_isResolving = false;
    m_positionSaveTimer->stop();

    emit playlistChanged();
    emit currentIndexChanged();
    emit currentItemChanged();

    saveToSettings();
}

// ============================================================================
// 内部方法
// ============================================================================

/**
 * @brief 解析并播放当前项
 *
 * 从 m_items[m_currentIndex] 提取媒体信息，
 * 设置 PlayerController 的标题/封面，调用 MediaResolver 解析播放 URL。
 *
 * 当前用 m_isResolving 防止重复解析；m_resolveGen 作为请求编号递增，
 * 方便后续扩展为“回调携带编号并丢弃旧响应”的更严格防竞态方案。
 */
void PlaylistService::resolveAndPlayCurrentItem()
{
    if (m_currentIndex < 0 || m_currentIndex >= m_items.size()) {
        qWarning() << "[Playlist] resolveAndPlayCurrentItem: 索引越界" << m_currentIndex;
        return;
    }

    QJsonObject item = m_items[m_currentIndex].toObject();
    qint64 id   = static_cast<qint64>(item.value(QStringLiteral("id")).toDouble(0));
    int type    = item.value(QStringLiteral("type")).toInt(12);
    QString bvid = item.value(QStringLiteral("bvid")).toString();
    QString title = item.value(QStringLiteral("title")).toString();
    QString cover = item.value(QStringLiteral("cover")).toString();

    DBG << "解析当前项: id=" << id << "type=" << type << "bvid=" << bvid << "title=" << title;

    // 设置播放器元数据（封面和标题显示在播放栏）
    m_playerController->setMediaTitle(title);
    m_playerController->setMediaCover(cover);

    // 标记正在解析，递增生成 ID
    m_isResolving = true;
    ++m_resolveGen;

    // 异步解析
    BL_LIFECYCLE_EVENT("PLAYLIST_RESOLVE_START", {"index", m_currentIndex}, {"generation", m_resolveGen},
                       {"itemId", id}, {"type", type});
    m_mediaResolver->resolve(id, type, bvid, 0);

    // 启动位置保存定时器
    if (!m_positionSaveTimer->isActive())
        m_positionSaveTimer->start();
}

/**
 * @brief 计算下一首索引
 *
 * 顺序模式： (currentIndex + 1) % size
 * 随机模式： 按 shuffleOrder 前进，到末尾时重新洗牌
 */
int PlaylistService::computeNextIndex()
{
    int size = m_items.size();
    if (size == 0) return -1;

    if (m_playMode == Sequential) {
        return (m_currentIndex + 1) % size;
    }

    // 随机模式
    if (m_shuffleOrder.isEmpty()) {
        shuffleOrder();
    }

    m_shufflePointer++;
    if (m_shufflePointer >= m_shuffleOrder.size()) {
        // 一轮结束，重新洗牌
        shuffleOrder();
        m_shufflePointer = 0;
    }

    int idx = m_shuffleOrder[m_shufflePointer];
    // 防御：确保索引有效
    if (idx < 0 || idx >= size) {
        return (m_currentIndex + 1) % size;  // 回退到顺序
    }
    return idx;
}

/**
 * @brief 计算上一首索引
 *
 * 顺序模式： (currentIndex - 1 + size) % size
 * 随机模式： 回退到 shuffleOrder 中的上一项
 */
int PlaylistService::computePreviousIndex()
{
    int size = m_items.size();
    if (size == 0) return -1;

    if (m_playMode == Sequential) {
        return (m_currentIndex - 1 + size) % size;
    }

    // 随机模式：回退到上一项或直接取有意义的项目
    m_shufflePointer--;
    if (m_shufflePointer < 0) {
        m_shufflePointer = m_shuffleOrder.size() - 1;
    }

    int idx = m_shuffleOrder[m_shufflePointer];
    if (idx < 0 || idx >= size) {
        return (m_currentIndex - 1 + size) % size;
    }
    return idx;
}

/**
 * @brief Fisher-Yates 洗牌
 *
 * 生成包含 [0, size-1] 的随机排列存储在 m_shuffleOrder 中。
 * 如果当前有播放项且不是刚进入随机模式，确保新顺序的第一项不是刚刚播完的那一项
 * （避免"随机到同一首"的糟糕体验）。
 */
void PlaylistService::shuffleOrder()
{
    int size = m_items.size();
    m_shuffleOrder.clear();
    m_shuffleOrder.reserve(size);
    for (int i = 0; i < size; ++i)
        m_shuffleOrder.append(i);

    // Fisher-Yates 洗牌
    for (int i = size - 1; i > 0; --i) {
        int j = QRandomGenerator::global()->bounded(i + 1);
        std::swap(m_shuffleOrder[i], m_shuffleOrder[j]);
    }

    m_shufflePointer = 0;

    // 确保当前项在洗牌后是第一项（这样按"下一首"时不会跳到一个奇怪的位置）
    if (m_currentIndex >= 0 && m_currentIndex < size) {
        int pos = -1;
        for (int i = 0; i < size; ++i) {
            if (m_shuffleOrder[i] == m_currentIndex) {
                pos = i;
                break;
            }
        }
        if (pos > 0) {
            // 把当前项移到位置 0
            std::swap(m_shuffleOrder[0], m_shuffleOrder[pos]);
        }
    }
}

// ============================================================================
// 槽函数
// ============================================================================

/**
 * @brief 当前曲目自然播放结束时触发
 *
 * 门控检查 m_isResolving：如果正在解析 URL（例如用户刚点了 next），
 * 跳过自动切歌,因为 resolveAndPlayCurrentItem 的结果会处理后续播放。
 */
void PlaylistService::onTrackFinished()
{
    BL_LIFECYCLE_EVENT("TRACK_FINISHED_RECEIVED", {"index", m_currentIndex}, {"resolving", m_isResolving});
    if (m_isResolving) {
        DBG << "onTrackFinished: 正在解析中, 跳过自动切歌";
        return;
    }
    if (m_items.isEmpty()) return;

    // 保存位置（归零，因为已经播完了）
    saveToSettings();

    DBG << "onTrackFinished: 自动切到下一首";
    next();
}

/**
 * @brief 媒体 URL 解析完成的回调
 *
 * 检查 genId 匹配性（防竞态），确认后设置 PlayerController 的 source 并播放。
 * 如果正在恢复状态，不自动播放，只 seek 到保存的位置。
 */
void PlaylistService::onMediaResolved(bool success, const QString &url,
                                       const QString &, const QString &, int, const QString &error)
{
    // generation 只是当前值，不代表已校验响应归属；本轮保留原有门控，不修复未复现的竞态。
    BL_LIFECYCLE_EVENT("PLAYLIST_RESOLVE_FINISH", {"index", m_currentIndex}, {"currentGeneration", m_resolveGen},
                       {"resolving", m_isResolving}, {"success", success}, {"sourceId", LifecycleDiagnostics::sourceId(url)});
    if (!m_isResolving) {
        // 此 resolve 不是由 PlaylistService 发起的，忽略
        return;
    }

    m_isResolving = false;

    if (!success || url.isEmpty()) {
        qWarning() << "[Playlist] 解析失败:" << error;
        // 失败时不自动跳过，避免网络问题导致整个列表被跳过
        return;
    }

    DBG << "解析成功, 设置 source URL 长度:" << url.length();

    // 设置播放源
    m_playerController->setSource(url);

    if (!m_isRestoring) {
        // 正常播放流程：自动开始播放
        m_playerController->play();
    } else {
        // 恢复流程：不自动播放，但 seek 到保存的位置
        int savedPos = m_settings->value(QStringLiteral("playlist/position"), 0).toInt();
        if (savedPos > 0) {
            // seek 需要在媒体加载完成后执行
            // 使用单次定时器延迟 seek
            QTimer::singleShot(500, this, [this, savedPos]() {
                if (m_playerController->duration() > 0) {
                    DBG << "恢复到保存位置:" << savedPos;
                    m_playerController->seek(savedPos);
                }
            });
        }
        m_isRestoring = false;
    }
}

// ============================================================================
// 持久化
// ============================================================================

/**
 * @brief 保存完整状态到 AppSettings
 *
 * Schema:
 *   [playlist]
 *   items        = JSON 数组字符串
 *   currentIndex = 当前索引
 *   playMode     = 0 (顺序) / 1 (随机)
 *   position     = 当前播放位置 (ms)
 */
void PlaylistService::saveToSettings()
{
    if (m_items.isEmpty()) {
        // 清空持久化数据
        m_settings->setValue(QStringLiteral("playlist/items"), QString());
        m_settings->setValue(QStringLiteral("playlist/currentIndex"), -1);
        m_settings->setValue(QStringLiteral("playlist/playMode"), 0);
        m_settings->setValue(QStringLiteral("playlist/position"), 0);
        return;
    }

    QJsonDocument doc(m_items);
    QString itemsStr = QString::fromUtf8(doc.toJson(QJsonDocument::Compact));

    m_settings->setValue(QStringLiteral("playlist/items"), itemsStr);
    m_settings->setValue(QStringLiteral("playlist/currentIndex"), m_currentIndex);
    m_settings->setValue(QStringLiteral("playlist/playMode"), static_cast<int>(m_playMode));
}

/**
 * @brief 保存当前播放位置
 *
 * 由 QTimer 每 10 秒触发一次，也由 onTrackFinished 触发
 */
void PlaylistService::savePosition()
{
    if (m_items.isEmpty() || m_playerController->duration() <= 0) return;
    int pos = m_playerController->position();
    if (pos <= 0) return;
    m_settings->setValue(QStringLiteral("playlist/position"), pos);
}

/**
 * @brief 从 AppSettings 恢复播放列表
 *
 * 在构造函数中调用。恢复 items / currentIndex / playMode / position。
 * 设置 m_isRestoring = true 防止自动播放。
 */
void PlaylistService::restoreFromSettings()
{
    QString itemsStr = m_settings->value(QStringLiteral("playlist/items")).toString();
    if (itemsStr.isEmpty()) return;

    QJsonDocument doc = QJsonDocument::fromJson(itemsStr.toUtf8());
    if (!doc.isArray() || doc.array().isEmpty()) return;

    m_items = doc.array();
    m_currentIndex = m_settings->value(QStringLiteral("playlist/currentIndex"), 0).toInt();
    m_playMode = static_cast<PlayMode>(
        m_settings->value(QStringLiteral("playlist/playMode"), 0).toInt());

    // 边界检查
    if (m_currentIndex < 0 || m_currentIndex >= m_items.size())
        m_currentIndex = 0;
    if (m_playMode != Sequential && m_playMode != Random)
        m_playMode = Sequential;

    // 随机模式：重建洗牌顺序
    if (m_playMode == Random && !m_items.isEmpty()) {
        shuffleOrder();
    }

    DBG << "恢复播放列表: size:" << m_items.size()
        << "index:" << m_currentIndex << "mode:" << m_playMode;

    emit playlistChanged();
    emit currentIndexChanged();
    emit currentItemChanged();
    emit playModeChanged();

    // 设置恢复标志并开始解析当前项（不自动播放）
    m_isRestoring = true;
    resolveAndPlayCurrentItem();
}
