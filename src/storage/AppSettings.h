// ============================================================================
// AppSettings.h - 应用配置管理器
// 功能：基于 QSettings 的配置读写封装，提供统一的应用设置存储接口
// 存储位置：%APPDATA%/cursor_music/cursor_music.ini（INI 格式）
// 典型用途：窗口位置记忆、用户偏好设置、上次使用状态等
// ============================================================================

#pragma once

#include <QObject>
#include <QVariant>
#include <QSettings>
#include <QByteArray>

/**
 * @brief 应用配置管理器
 *
 * 封装 QSettings，提供类型安全的配置读写方法。
 * QSettings 是 Qt 自带的跨平台配置存储方案，支持 INI 文件、注册表等后端。
 *
 * 本类使用 INI 格式，存储在用户目录下，便于查看和手动修改。
 *
 * 典型用法：
 * @code
 * AppSettings settings;
 * int volume = settings.value("player/volume", 50).toInt();  // 读取音量
 * settings.setValue("player/volume", 75);                     // 保存音量
 * @endcode
 *
 * 配置文件结构示例：
 * [player]
 * volume=75
 * [window]
 * geometry=@ByteArray(\x1\xd9\xd0\xcb...)
 */
class AppSettings : public QObject
{
    Q_OBJECT
    // appDataPath 属性：暴露应用数据目录给 QML 使用（常量，只读）
    Q_PROPERTY(QString appDataPath READ appDataPath CONSTANT)
    Q_PROPERTY(bool reduceMotion READ reduceMotion WRITE setReduceMotion
               NOTIFY reduceMotionChanged)

public:
    /**
     * @brief 构造函数
     * @param parent Qt 父对象
     *
     * 初始化 QSettings，使用 INI 格式存储
     * 组织名和应用名均设为 "cursor_music"
     * 存储路径：%APPDATA%/cursor_music/cursor_music.ini
     */
    explicit AppSettings(QObject *parent = nullptr);

    /**
     * @brief 读取配置项
     * @param key          配置键名，支持分层路径，如 "player/volume"
     * @param defaultValue 键不存在时的默认值
     * @return 配置值（QVariant 类型，需要用 toInt()/toString() 等方法转换）
     *
     * 示例：
     * @code
     * int volume = settings.value("player/volume", 50).toInt();
     * QString name = settings.value("user/name", "默认用户").toString();
     * @endcode
     */
    QVariant value(const QString &key, const QVariant &defaultValue = QVariant()) const;

    /**
     * @brief 写入配置项
     * @param key   配置键名
     * @param value 配置值
     *
     * 写入后立即同步到磁盘（QSettings 默认行为）。
     * 键不存在时自动创建，键已存在时覆盖旧值。
     */
    void setValue(const QString &key, const QVariant &value);

    /**
     * @brief 读取窗口几何信息
     * @return 窗口位置和大小数据（QByteArray）
     *
     * 用于 restoreGeometry() 恢复窗口的上次位置和大小
     */
    QByteArray windowGeometry() const;

    /**
     * @brief 保存窗口几何信息
     * @param geometry 窗口位置和大小数据
     *
     * 在窗口关闭事件中调用 window->saveGeometry() 获取几何信息
     * 然后通过此方法保存到配置文件中
     */
    void setWindowGeometry(const QByteArray &geometry);

    /**
     * @brief 获取应用数据目录路径
     * @return 应用数据目录路径字符串
     *
     * Windows 上通常为：C:/Users/用户名/AppData/Local/cursor_music
     * 如果目录不存在，会自动创建。
     * 此目录用于存储：Cookie 文件、日志、缓存等数据。
     */
    QString appDataPath() const;

    bool reduceMotion() const;
    void setReduceMotion(bool reduceMotion);

signals:
    void reduceMotionChanged();

private:
    /** QSettings 实例，基于 INI 格式的应用层存储 */
    QSettings m_settings;
};
