// ============================================================================
// AppSettings.cpp - 应用配置管理器实现
// 功能：基于 QSettings 的 INI 格式配置读写
// ============================================================================

#include "AppSettings.h"

#include <QStandardPaths>   // 跨平台标准路径（获取 AppData 目录等）
#include <QDir>             // 目录操作

#ifdef Q_OS_WIN
#include <qt_windows.h>
#endif

namespace {
bool systemReduceMotionDefault()
{
#ifdef Q_OS_WIN
    BOOL animationsEnabled = TRUE;
    if (SystemParametersInfoW(SPI_GETCLIENTAREAANIMATION, 0,
                              &animationsEnabled, 0)) {
        return !animationsEnabled;
    }
#endif
    return false;
}
}

/**
 * @brief 构造函数
 * @param parent Qt 父对象
 *
 * QSettings 初始化参数：
 * - format:   QSettings::IniFormat（使用 INI 文本格式，便于阅读）
 * - scope:    QSettings::UserScope（存储在用户目录，不需要管理员权限）
 * - organization: "cursor_music"
 * - application:  "cursor_music"
 *
 * Windows 结果路径：
 *   %APPDATA%/cursor_music/cursor_music.ini
 *   即：C:/Users/<用户名>/AppData/Roaming/cursor_music/cursor_music.ini
 */
AppSettings::AppSettings(QObject *parent)
    : QObject(parent)
    , m_settings(QSettings::IniFormat, QSettings::UserScope,
                 QStringLiteral("cursor_music"), QStringLiteral("cursor_music"))
{
}

/**
 * @brief 读取配置值
 * @param key          配置键名（支持 "/" 分层，如 "player/volume"）
 * @param defaultValue 默认值（键不存在时返回此值）
 * @return 配置值
 */
QVariant AppSettings::value(const QString &key, const QVariant &defaultValue) const
{
    return m_settings.value(key, defaultValue);
}

/**
 * @brief 写入配置值
 * @param key   配置键名
 * @param value 配置值
 *
 * m_settings.setValue() 内部会：
 * 1. 将值写入内存缓存
 * 2. 异步写入磁盘（通常在程序退出时同步，也可调用 sync() 立即写入）
 */
void AppSettings::setValue(const QString &key, const QVariant &value)
{
    m_settings.setValue(key, value);
}

/**
 * @brief 读取窗口几何信息
 * @return QByteArray 格式的窗口位置和大小数据
 *
 * 与 QWidget::saveGeometry() / restoreGeometry() 配合使用
 */
QByteArray AppSettings::windowGeometry() const
{
    return m_settings.value(QStringLiteral("window/geometry")).toByteArray();
}

/**
 * @brief 保存窗口几何信息
 * @param geometry QByteArray 格式的窗口几何数据
 *
 * 通常在窗口关闭事件中调用：
 * @code
 * settings.setWindowGeometry(window->saveGeometry());
 * @endcode
 */
void AppSettings::setWindowGeometry(const QByteArray &geometry)
{
    m_settings.setValue(QStringLiteral("window/geometry"), geometry);
}

/**
 * @brief 获取应用数据目录
 * @return 目录路径（末尾不带斜杠）
 *
 * QStandardPaths::AppDataLocation：
 * - Windows: %APPDATA%/cursor_music （即 C:/Users/xxx/AppData/Roaming/cursor_music）
 * - Linux:   ~/.local/share/cursor_music
 *
 * 如果目录不存在，自动创建（mkpath）。
 */
QString AppSettings::appDataPath() const
{
    // writableLocation 返回一个可写的标准路径
    QString path = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    // mkpath 确保目录存在，如果不存在则创建所有级联目录
    QDir().mkpath(path);
    return path;
}

bool AppSettings::reduceMotion() const
{
    return m_settings.value(QStringLiteral("accessibility/reduceMotion"),
                            systemReduceMotionDefault()).toBool();
}

void AppSettings::setReduceMotion(bool reduceMotion)
{
    if (this->reduceMotion() == reduceMotion)
        return;
    m_settings.setValue(QStringLiteral("accessibility/reduceMotion"), reduceMotion);
    m_settings.sync();
    emit reduceMotionChanged();
}
