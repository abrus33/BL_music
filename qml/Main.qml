// ============================================================================
// Main.qml - 主窗口（骨架布局）
//
// 新人阅读重点：
// 1. 这里不直接处理业务，只负责把各个页面和组件摆到窗口里。
// 2. Sidebar.currentIndex 控制 StackLayout 当前显示哪个页面。
// 3. PlayerBar 常驻底部，PlaylistPopup 由 PlayerBar 的按钮打开。
// 4. applicationContext 在 main.cpp 中注入，子页面可以直接访问 C++ 服务。
// ============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components/Theme.js" as Theme

ApplicationWindow {
    id: window

    width: 1360; height: 860; visible: true
    title: qsTr("Bilibili Music Client")
    color: Theme.colors.bgApp

    RowLayout {
        anchors.fill: parent; spacing: 0

        // 左侧导航只负责切换 currentIndex，不负责创建页面。
        Sidebar {
            id: sidebar
            Layout.fillHeight: true
            Layout.preferredWidth: Theme.sizes.sidebarWidth
        }

        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true
            color: Theme.colors.bgContent

            ColumnLayout {
                anchors.fill: parent; spacing: 0

                StackLayout {
                    id: pageStack
                    Layout.fillWidth: true; Layout.fillHeight: true
                    // 关键绑定：导航栏索引变化时，内容区自动切页。
                    currentIndex: sidebar.currentIndex

                    HomePage {}
                    FavoritesPage {}
                    LoginPage {}
                }

                PlayerBar {
                    id: playerBar
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.sizes.playerHeight
                    // PlayerBar 不直接创建弹窗，只发出“想打开播放列表”的信号。
                    onPlaylistButtonClicked: playlistPopup.open()
                }
            }
        }
    }

    // ---- 播放列表弹窗 ----
    PlaylistPopup {
        id: playlistPopup
        x: (window.width - width) / 2
        y: (window.height - height) / 2
    }
}
