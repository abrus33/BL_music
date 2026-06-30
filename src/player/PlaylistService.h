// ============================================================================
// PlaylistService.h - 播放列表服务
// 功能：管理播放列表（创建/切换/持久化）、播放模式（顺序/随机）、自动切歌
//
// 数据流：
//   用户点击收藏夹视频 → createPlaylist(itemsJson, startId)
//     → 解析 JSON 数组 → 设置 m_items
//     → 找到 startId 对应索引 → set m_currentIndex
//     → resolveAndPlayCurrentItem() → MediaResolver::resolve()
//     → onMediaResolved() → PlayerController::setSource() + play()
//
//   当前曲目结束 → PlayerController::trackFinished
//     → onTrackFinished() → next() → resolveAndPlayCurrentItem()
//
// 持久化：
//   通过 AppSettings (QSettings INI) 保存/恢复
//   Schema: playlist/items, playlist/currentIndex, playlist/playMode, playlist/position
// ============================================================================

#pragma once

#include <QObject>
#include <QJsonArray>
#include <QTimer>

class AppSettings;
class MediaResolver;
class PlayerController;

class PlaylistService : public QObject
{
    Q_OBJECT

    // ---- 暴露给 QML 的属性 ----
    Q_PROPERTY(int currentIndex READ currentIndex NOTIFY currentIndexChanged)
    Q_PROPERTY(int playlistSize READ playlistSize NOTIFY playlistChanged)
    Q_PROPERTY(int playMode READ playMode NOTIFY playModeChanged)
    Q_PROPERTY(QString currentItemJson READ currentItemJson NOTIFY currentItemChanged)
    Q_PROPERTY(QString playlistItems READ playlistItems NOTIFY playlistChanged)
    Q_PROPERTY(bool isEmpty READ isEmpty NOTIFY playlistChanged)

public:
    enum PlayMode {
        Sequential = 0,  // 顺序播放: 0 → 1 → 2 → ... → n-1 → 0 → ...
        Random     = 1   // 随机播放: Fisher-Yates 洗牌, 不重复直到所有播完
    };
    Q_ENUM(PlayMode)

    /**
     * @brief 构造函数
     * @param settings AppSettings 指针（持久化）
     * @param resolver MediaResolver 指针（解析媒体 URL）
     * @param player   PlayerController 指针（播放控制）
     * @param parent   Qt 父对象
     *
     * 构造函数中会自动调用 restoreFromSettings() 恢复上次的播放列表
     */
    explicit PlaylistService(AppSettings *settings,
                             MediaResolver *resolver,
                             PlayerController *player,
                             QObject *parent = nullptr);

    // ---- Accessors ----
    int currentIndex() const;
    int playlistSize() const;
    int playMode() const;
    QString currentItemJson() const;  // 当前播放项的 JSON 字符串
    QString playlistItems() const;    // 完整播放列表 JSON 数组（供 QML 列表显示）
    bool isEmpty() const;

    // ---- QML 可调用方法 ----

    /**
     * @brief 创建/替换播放列表
     * @param itemsJson   JSON 数组字符串，每项含 id/type/bvid/title/cover/duration
     * @param startItemId 起始播放项的 id
     *
     * 清空旧列表，解析新列表，找到 startItemId 对应索引并开始播放
     */
    Q_INVOKABLE void createPlaylist(const QString &itemsJson, qint64 startItemId);

    /**
     * @brief 播放下一首（根据播放模式自动计算）
     */
    Q_INVOKABLE void next();

    /**
     * @brief 播放上一首
     */
    Q_INVOKABLE void previous();

    /**
     * @brief 设置播放模式
     * @param mode 0=顺序, 1=随机
     */
    Q_INVOKABLE void setPlayMode(int mode);

    /**
     * @brief 跳转到指定索引并播放
     * @param index 播放列表中的目标索引
     */
    Q_INVOKABLE void playAt(int index);

    /**
     * @brief 清空播放列表
     */
    Q_INVOKABLE void clear();

    // ---- 持久化 ----
    void saveToSettings();
    void restoreFromSettings();

signals:
    void playlistChanged();       // 列表内容变更
    void currentIndexChanged();   // 当前播放项变更
    void currentItemChanged();    // 当前项内容变更
    void playModeChanged();       // 播放模式变更

private slots:
    /**
     * @brief 当前曲目自然播放结束时自动切下一首
     */
    void onTrackFinished();

    /**
     * @brief 媒体 URL 解析完成时的回调
     */
    void onMediaResolved(bool success, const QString &url, const QString &title,
                         const QString &cover, int duration, const QString &error);

private:
    /**
     * @brief 解析并播放当前项
     *
     * 从 m_items[m_currentIndex] 提取 id/type/bvid，
     * 设置 mediaTitle/mediaCover，调用 MediaResolver::resolve()
     */
    void resolveAndPlayCurrentItem();

    /**
     * @brief 计算下一首的索引（根据播放模式）
     */
    int computeNextIndex();

    /**
     * @brief 计算上一首的索引
     */
    int computePreviousIndex();

    /**
     * @brief Fisher-Yates 洗牌，生成新的随机播放顺序
     */
    void shuffleOrder();

    /**
     * @brief 保存当前播放位置到 AppSettings
     */
    void savePosition();

    // ---- 依赖对象（由 ApplicationContext 管理生命周期） ----
    AppSettings      *m_settings;
    MediaResolver    *m_mediaResolver;
    PlayerController *m_playerController;

    // ---- 播放列表状态 ----
    QJsonArray  m_items;               // [{id, type, bvid, title, cover, duration}, ...]
    int         m_currentIndex = -1;   // 当前播放项索引, -1=无
    PlayMode    m_playMode = Sequential;
    QList<int>  m_shuffleOrder;        // 随机播放索引映射
    int         m_shufflePointer = 0;  // 当前在 shuffleOrder 中的位置

    // ---- 门控标志 ----
    bool m_isRestoring = false;        // 正在恢复中, 不自动播放
    bool m_isResolving = false;        // 正在解析 URL, 防止重入
    int  m_resolveGen   = 0;           // 解析请求编号；当前主要用于调试，后续可扩展为旧回调丢弃

    // ---- 位置保存定时器 ----
    QTimer *m_positionSaveTimer;
};
