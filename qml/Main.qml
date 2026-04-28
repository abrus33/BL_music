// ============================================================================
// Main.qml - 主窗口
// 功能：三段式布局——左侧导航栏 + 中间内容区 + 底部播放栏
// 与 C++ 的交互：通过 applicationContext（ApplicationContext 对象）读取属性
// ============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// ApplicationWindow: Qt Quick 提供的顶层窗口控件
// 对应 C++ 的 QGuiApplication + QQmlApplicationEngine 启动的窗口
ApplicationWindow {
    id: window

    // ---- 窗口基础属性 ----
    width: 1360                          // 窗口宽度（像素）
    height: 860                          // 窗口高度（像素）
    visible: true                        // 窗口可见
    title: qsTr("Bilibili Music Client") // 窗口标题（qsTr 支持多语言翻译）
    color: "#181818"                     // 窗口背景色（深色主题）

    // ---- 主体布局：RowLayout（水平排列） ----
    // 三栏结构：Sidebar（240px） | 内容区（弹性） | （底部播放栏在内容区内）
    RowLayout {
        anchors.fill: parent              // 占满整个父容器
        spacing: 0                        // 子元素之间无间距

        // ========== 左侧导航栏 ==========
        // Sidebar: 自定义 QML 组件（qml/components/Sidebar.qml）
        // 通过 currentIndex 属性控制页面切换
        Sidebar {
            id: sidebar

            Layout.fillHeight: true       // 高度填满
            Layout.preferredWidth: 240    // 宽度固定 240px
        }

        // ========== 中间内容区（含底部播放栏） ==========
        Rectangle {
            Layout.fillWidth: true        // 宽度弹性扩展
            Layout.fillHeight: true
            color: "#202020"              // 内容区背景色（深色）

            // 内容区的垂直布局：页面内容 | 底部播放栏
            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // ---- StackLayout: 页面容器 ----
                // 通过 currentIndex 控制显示哪个页面
                // currentIndex 绑定到 sidebar.currentIndex
                // 索引映射：
                //   0 -> HomePage（首页）
                //   1 -> FavoritesPage（收藏夹）
                //   2 -> LoginPage（登录）
                StackLayout {
                    id: pageStack

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: sidebar.currentIndex

                    // StackLayout 的子项按索引顺序排列
                    // 只有 currentIndex 对应的子项可见
                    HomePage {}        // 索引 0：首页
                    FavoritesPage {}   // 索引 1：收藏夹
                    LoginPage {}       // 索引 2：登录
                }

                // ---- 底部播放栏（占位） ----
                // 当前为静态占位，阶段二将接入 PlayerController
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 92   // 播放栏高度固定 92px
                    color: "#141414"
                    border.color: "#292929"
                    border.width: 1

                    // 播放栏内容布局
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 20       // 内边距
                        spacing: 16

                        // 封面占位（后续替换为专辑封面图片）
                        Rectangle {
                            Layout.preferredWidth: 52
                            Layout.preferredHeight: 52
                            radius: 8
                            color: "#2a2a2a"
                        }

                        // 歌曲信息
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            // applicationContext: 由 main.cpp 注入的 C++ ApplicationContext 对象
                            // 通过 qsTr() 声明的字符串支持国际化
                            Label {
                                text: qsTr("播放栏占位")
                                color: "#f5f5f5"
                                font.pixelSize: 16
                                font.bold: true
                            }

                            Label {
                                // 通过 applicationContext.qtVersion 读取 Qt 版本号
                                // 这是 C++ Q_PROPERTY 暴露给 QML 的属性
                                text: qsTr("Qt %1 / 后续接入播放器控制").arg(applicationContext.qtVersion)
                                color: "#9d9d9d"
                                font.pixelSize: 12
                            }
                        }

                        // 音量/进度占位滑动条
                        Slider {
                            Layout.preferredWidth: 200
                            from: 0
                            to: 100
                            value: 30
                        }
                    }
                }
            }
        }
    }
}
