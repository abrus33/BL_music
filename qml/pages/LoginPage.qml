// ============================================================================
// LoginPage.qml - 登录页面
// 功能：导入浏览器 Cookie 登录 B站账号
// 与 C++ 的交互：通过 applicationContext.authService 调用 AuthService
// ============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

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

            // 登录状态提示
            Label {
                text: applicationContext.authService.isLoggedIn
                      ? qsTr("已登录：%1").arg(applicationContext.authService.userName)
                      : qsTr("登录后可同步你的 B站收藏夹与个性化内容。")
                color: applicationContext.authService.isLoggedIn ? "#fb7299" : "#bcbcbc"
                wrapMode: Text.Wrap
                Layout.fillWidth: true
                font.pixelSize: 14
            }

            // ---- Cookie 登录卡片 ----
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: loginLayout.implicitHeight + 32
                radius: 12
                color: "#262626"

                ColumnLayout {
                    id: loginLayout
                    anchors.centerIn: parent
                    anchors.margins: 20
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
                        text: qsTr("从浏览器开发者工具复制 Cookie 字符串粘贴到下方输入框")
                        color: "#9d9d9d"
                        font.pixelSize: 13
                        wrapMode: Text.Wrap
                        Layout.maximumWidth: 500
                        horizontalAlignment: Text.AlignHCenter
                    }

                    // ---- Cookie 输入框 ----
                    // 用户在此粘贴从浏览器复制的 Cookie 字符串
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        Layout.maximumWidth: 500
                        anchors.horizontalCenter: parent.horizontalCenter
                        radius: 8
                        color: "#1a1a1a"
                        border.color: "#3a3a3a"

                        TextInput {
                            id: cookieInput
                            anchors.fill: parent
                            anchors.margins: 12
                            color: "#f5f5f5"
                            font.pixelSize: 13
                            verticalAlignment: Text.AlignVCenter
                            // 占位提示文字
                            Text {
                                anchors.fill: parent
                                text: qsTr("SESSDATA=xxx; bili_jct=xxx; ...")
                                color: "#5a5a5a"
                                font: parent.font
                                visible: !parent.text.length
                            }
                        }
                    }

                    // ---- 操作按钮 ----
                    RowLayout {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 12

                        // 导入 Cookie 按钮
                        // QML 调用 C++: applicationContext.authService.importCookie(cookieStr)
                        Button {
                            text: qsTr("导入 Cookie")
                            enabled: cookieInput.text.trim().length > 0

                            background: Rectangle {
                                radius: 8
                                color: parent.enabled ? "#fb7299" : "#3a3a3a"
                            }
                            contentItem: Label {
                                text: parent.text
                                color: parent.enabled ? "#ffffff" : "#7d7d7d"
                                font.pixelSize: 14
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            implicitWidth: 160
                            implicitHeight: 40

                            // 点击后调用 C++ AuthService::importCookie()
                            onClicked: {
                                applicationContext.authService.importCookie(cookieInput.text.trim())
                                // 导入后清除输入框
                                cookieInput.text = ""
                            }
                        }

                        // 退出登录按钮（已登录状态下显示）
                        Button {
                            text: qsTr("退出登录")
                            visible: applicationContext.authService.isLoggedIn

                            background: Rectangle {
                                radius: 8
                                color: "#3a3a3a"
                            }
                            contentItem: Label {
                                text: parent.text
                                color: "#dddddd"
                                font.pixelSize: 14
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            implicitWidth: 120
                            implicitHeight: 40

                            // 点击后调用 C++ AuthService::logout()
                            onClicked: {
                                applicationContext.authService.logout()
                            }
                        }
                    }

                    // 登录结果提示（监听 C++ 信号自动更新）
                    Label {
                        id: loginResultLabel
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("")
                        color: "#fb7299"
                        font.pixelSize: 12
                        visible: text.length > 0
                    }

                    // 监听 AuthService 的登录状态变化
                    Connections {
                        target: applicationContext.authService
                        onLoginChecked: function(success, userName) {
                            loginResultLabel.text = success
                                ? qsTr("登录成功！欢迎 %1").arg(userName)
                                : qsTr("登录失败，请检查 Cookie 是否有效")
                        }
                    }
                }
            }

            // ---- 使用说明卡片 ----
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 160
                radius: 12
                color: "#262626"

                Column {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 8

                    Label {
                        text: qsTr("如何获取 Cookie？")
                        color: "#f4f4f4"
                        font.pixelSize: 17
                        font.bold: true
                    }

                    Label {
                        text: qsTr("1. 在浏览器中打开 bilibili.com 并登录你的账号")
                        color: "#a8a8a8"
                        font.pixelSize: 13
                    }
                    Label {
                        text: qsTr("2. 按 F12 打开开发者工具 → 网络(Network) 标签")
                        color: "#a8a8a8"
                        font.pixelSize: 13
                    }
                    Label {
                        text: qsTr("3. 刷新页面，点击任意请求，在请求头中找到 Cookie 字段")
                        color: "#a8a8a8"
                        font.pixelSize: 13
                    }
                    Label {
                        text: qsTr("4. 复制完整的 Cookie 值，粘贴到上方输入框中")
                        color: "#a8a8a8"
                        font.pixelSize: 13
                    }
                    Label {
                        text: qsTr("注：Cookie 仅保存在本地，不会上传或泄露")
                        color: "#7d7d7d"
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}
