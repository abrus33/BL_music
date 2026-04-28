// ============================================================================
// FavoritesPage.qml - 收藏夹页面
// 功能：展示用户的 B站收藏夹列表和内容（当前为占位页面）
// 阶段二实现：接入 FavoriteService 后显示真实数据
// ============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ScrollView {
    clip: true

    Rectangle {
        implicitWidth: 900
        implicitHeight: contentColumn.implicitHeight + 48
        color: "#202020"

        ColumnLayout {
            id: contentColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 24
            spacing: 20

            // 页面标题
            Label {
                text: qsTr("收藏夹")
                color: "#ffffff"
                font.pixelSize: 28
                font.bold: true
            }

            // 功能说明
            Label {
                text: qsTr("此页面将展示你的 B站收藏夹列表与内容。")
                color: "#bcbcbc"
                wrapMode: Text.Wrap
                Layout.fillWidth: true
                font.pixelSize: 14
            }

            // ---- 占位内容区域 ----
            // 在阶段二实现前显示提示信息
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 160
                radius: 12
                color: "#262626"

                Column {
                    anchors.centerIn: parent
                    spacing: 12

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("收藏夹功能将在阶段二实现")
                        color: "#9d9d9d"
                        font.pixelSize: 15
                    }

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("需要先完成登录态验证")
                        color: "#7d7d7d"
                        font.pixelSize: 13
                    }
                }
            }
        }
    }
}
