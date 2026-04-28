// ============================================================================
// LoginPage.qml - 登录页面
// 功能：提供 Cookie 登录的入口（当前为占位页面）
// 阶段二实现：接入 AuthService，实现 Cookie 导入功能
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
                text: qsTr("登录")
                color: "#ffffff"
                font.pixelSize: 28
                font.bold: true
            }

            // 功能说明
            Label {
                text: qsTr("登录后可同步你的 B站收藏夹与个性化内容。")
                color: "#bcbcbc"
                wrapMode: Text.Wrap
                Layout.fillWidth: true
                font.pixelSize: 14
            }

            // ---- Cookie 登录卡片 ----
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 200
                radius: 12
                color: "#262626"

                Column {
                    anchors.centerIn: parent
                    spacing: 16

                    // 登录方式标题
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("Cookie 登录")
                        color: "#f5f5f5"
                        font.pixelSize: 18
                        font.bold: true
                    }

                    // 引导说明
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("导入浏览器 Cookie 以登录 B站账号")
                        color: "#9d9d9d"
                        font.pixelSize: 13
                    }

                    // ---- 导入 Cookie 按钮 ----
                    // 当前 enabled: false（阶段二实现前不可用）
                    Button {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("导入 Cookie")
                        highlighted: true
                        enabled: false  // 阶段二实现后启用

                        // 自定义按钮背景
                        background: Rectangle {
                            radius: 8
                            color: parent.enabled ? "#fb7299" : "#3a3a3a"
                        }

                        // 自定义按钮文字
                        contentItem: Label {
                            text: parent.text
                            color: parent.enabled ? "#ffffff" : "#7d7d7d"
                            font.pixelSize: 14
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        implicitWidth: 160
                        implicitHeight: 40
                    }

                    // 提示：此功能尚未实现
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("登录功能将在阶段二实现")
                        color: "#7d7d7d"
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}
