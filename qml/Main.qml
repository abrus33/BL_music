// ============================================================================
// Main.qml - 主窗口（骨架布局）
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
                    currentIndex: sidebar.currentIndex

                    HomePage {}
                    FavoritesPage {}
                    LoginPage {}
                }

                PlayerBar {
                    id: playerBar
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.sizes.playerHeight
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
