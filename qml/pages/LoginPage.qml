// ============================================================================
// LoginPage.qml - 登录页面（Cookie 登录 + 扫码登录）
//
// 新人阅读重点：
// 1. 本页不自己访问网络，所有登录动作都调用 AuthService。
// 2. Cookie 登录：importCookie() -> C++ 保存 Cookie -> checkLogin() -> loginChecked。
// 3. 扫码登录：startQrLogin() -> C++ 生成二维码并轮询 -> qrStatus/qrImageUrl 绑定刷新。
// 4. Connections 用来接收 C++ signal；普通属性绑定用来显示 C++ Q_PROPERTY。
// ============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components/Theme.js" as Theme

ScrollView {
    clip: true

    Rectangle {
        implicitWidth: 900
        implicitHeight: contentColumn.implicitHeight + 48
        color: Theme.colors.bgContent

        ColumnLayout {
            id: contentColumn
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            anchors.margins: Theme.spacing.page; spacing: Theme.spacing.card

            // ---- 标题 ----
            Label {
                text: qsTr("登录")
                color: Theme.colors.textPrimary
                font.pixelSize: Theme.fontSizes.h1; font.bold: true
            }

            // ---- 登录状态 ----
            Label {
                // isLoggedIn 和 userName 是 C++ AuthService 暴露的 Q_PROPERTY。
                text: applicationContext.authService.isLoggedIn
                      ? qsTr("已登录：%1").arg(applicationContext.authService.userName)
                      : qsTr("登录后可同步你的 B站收藏夹与个性化内容。")
                color: applicationContext.authService.isLoggedIn ? Theme.colors.accent : Theme.colors.textTertiary
                wrapMode: Text.Wrap; Layout.fillWidth: true
                font.pixelSize: Theme.fontSizes.bodySmall
            }

            // ---- Tab 切换按钮 ----
            RowLayout {
                Layout.alignment: Qt.AlignHCenter; spacing: 0

                AppButton {
                    text: qsTr("Cookie 登录")
                    bgColor: loginModeSwitch.currentIndex === 0 ? Theme.colors.accent : Theme.colors.bgPlaceholder
                    textColor: loginModeSwitch.currentIndex === 0 ? Theme.colors.textPrimary : Theme.colors.textMuted
                    btnWidth: 140; btnHeight: 40
                    onClicked: loginModeSwitch.currentIndex = 0
                }
                Item { width: Theme.spacing.compact; height: 1 }
                AppButton {
                    text: qsTr("扫码登录")
                    bgColor: loginModeSwitch.currentIndex === 1 ? Theme.colors.accent : Theme.colors.bgPlaceholder
                    textColor: loginModeSwitch.currentIndex === 1 ? Theme.colors.textPrimary : Theme.colors.textMuted
                    btnWidth: 140; btnHeight: 40
                    onClicked: loginModeSwitch.currentIndex = 1
                }
            }

            // ---- SwipeView ----
            SwipeView {
                id: loginModeSwitch
                Layout.fillWidth: true
                Layout.preferredHeight: currentItem ? currentItem.implicitHeight : 300
                interactive: false

                // ========== 0: Cookie 登录 ==========
                Item {
                    implicitHeight: cookieCard.height

                    Rectangle {
                        id: cookieCard
                        width: parent.width
                        height: cookieLayout.implicitHeight + 40
                        radius: Theme.radius.card; color: Theme.colors.bgCard

                        ColumnLayout {
                            id: cookieLayout
                            anchors.centerIn: parent
                            width: parent.width - 40; spacing: Theme.spacing.section

                            Label {
                                Layout.alignment: Qt.AlignHCenter
                                text: qsTr("从浏览器开发者工具复制 Cookie")
                                color: Theme.colors.textMuted
                                font.pixelSize: Theme.fontSizes.caption
                                wrapMode: Text.Wrap
                            }

                            // ---- Cookie 输入框 ----
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 40
                                Layout.maximumWidth: 500; Layout.alignment: Qt.AlignHCenter
                                radius: Theme.radius.input; color: Theme.colors.bgInput
                                border.color: Theme.colors.borderInput

                                TextInput {
                                    id: cookieInput
                                    anchors.fill: parent; anchors.margins: Theme.spacing.item
                                    color: Theme.colors.textSecondary; font.pixelSize: Theme.fontSizes.caption
                                    verticalAlignment: Text.AlignVCenter
                                    Text {
                                        anchors.fill: parent
                                        text: qsTr("SESSDATA=xxx; bili_jct=xxx; ...")
                                        color: Theme.colors.textDim
                                        font: parent.font
                                        visible: !parent.text.length
                                    }
                                }
                            }

                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter; spacing: Theme.spacing.item

                                AppButton {
                                    text: qsTr("导入 Cookie")
                                    enabled: cookieInput.text.trim().length > 0
                                    btnWidth: 160
                                    onClicked: {
                                        // QML 只把字符串传给 C++，解析、保存、验证都在 AuthService 完成。
                                        applicationContext.authService.importCookie(cookieInput.text.trim())
                                        cookieInput.text = ""
                                    }
                                }
                                AppButton {
                                    text: qsTr("退出登录")
                                    visible: applicationContext.authService.isLoggedIn
                                    bgColor: Theme.colors.borderInput
                                    btnWidth: 120
                                    onClicked: applicationContext.authService.logout()
                                }
                            }

                            Label {
                                id: loginResultLabel
                                Layout.alignment: Qt.AlignHCenter; text: ""
                                color: Theme.colors.accent; font.pixelSize: Theme.fontSizes.small
                                visible: text.length > 0
                            }

                            Connections {
                                target: applicationContext.authService
                                // AuthService::checkLogin 完成后发出 loginChecked。
                                // 导入 Cookie 和扫码登录成功最终都会走到这条通知链。
                                function onLoginChecked(success, userName) {
                                    loginResultLabel.text = success
                                        ? qsTr("登录成功！欢迎 %1").arg(userName)
                                        : qsTr("登录失败，请检查 Cookie 是否有效")
                                }
                            }
                        }
                    }
                }

                // ========== 1: 扫码登录 ==========
                Item {
                    implicitHeight: qrCard.height

                    Rectangle {
                        id: qrCard
                        width: parent.width
                        height: qrLayout.implicitHeight + 40
                        radius: Theme.radius.card; color: Theme.colors.bgCard

                        ColumnLayout {
                            id: qrLayout
                            anchors.centerIn: parent
                            width: parent.width - 40; spacing: Theme.spacing.section

                            Label {
                                Layout.alignment: Qt.AlignHCenter
                                text: qsTr("使用B站APP扫描二维码登录")
                                color: Theme.colors.textMuted
                                font.pixelSize: Theme.fontSizes.caption
                            }

                            // ---- 二维码容器 ----
                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                width: 236; height: 236
                                radius: Theme.radius.card; color: "#ffffff"

                                // 占位状态
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 220; height: 220
                                    color: "#f5f5f5"; visible: !qrImage.visible
                                    Label {
                                        anchors.centerIn: parent
                                        text: applicationContext.authService.qrLoginActive
                                              ? qsTr("二维码加载中...")
                                              : qsTr("点击下方按钮生成二维码")
                                        color: Theme.colors.textMuted
                                        font.pixelSize: Theme.fontSizes.caption
                                    }
                                }

                                Image {
                                    id: qrImage
                                    anchors.centerIn: parent; width: 220; height: 220
                                    // qrImageUrl 是 C++ 生成的二维码图片地址；为空时显示占位状态。
                                    source: applicationContext.authService.qrImageUrl
                                    visible: applicationContext.authService.qrImageUrl.length > 0
                                    fillMode: Image.PreserveAspectFit; smooth: true; cache: false
                                    onStatusChanged: {
                                        if (status === Image.Error)
                                            console.warn("QR code image failed to load:", source)
                                    }
                                }
                            }

                            // ---- 状态文字 ----
                            Label {
                                Layout.alignment: Qt.AlignHCenter
                                // qrStatus 由 C++ 轮询二维码状态时更新。
                                text: applicationContext.authService.qrStatus
                                color: {
                                    var s = applicationContext.authService.qrStatus
                                    if (s.includes("成功")) return "#4caf50"
                                    if (s.includes("过期") || s.includes("失败")) return "#f44336"
                                    if (s.includes("确认")) return "#ff9800"
                                    return Theme.colors.textMuted
                                }
                                font.pixelSize: Theme.fontSizes.caption
                                visible: text.length > 0
                            }

                            // ---- 操作按钮 ----
                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter; spacing: Theme.spacing.item

                                AppButton {
                                    text: applicationContext.authService.qrLoginActive
                                          ? qsTr("加载中...") : qsTr("获取二维码")
                                    enabled: !applicationContext.authService.qrLoginActive
                                    btnWidth: 160
                                    // 开始扫码登录后，C++ 会生成二维码并启动 QTimer 轮询。
                                    onClicked: applicationContext.authService.startQrLogin()
                                }
                                AppButton {
                                    text: qsTr("取消")
                                    visible: applicationContext.authService.qrLoginActive
                                    bgColor: Theme.colors.borderInput
                                    btnWidth: 100
                                    // 取消只停止本地轮询，不需要调用 B站取消接口。
                                    onClicked: applicationContext.authService.stopQrLogin()
                                }
                            }
                        }
                    }
                }
            }

            // ---- 使用说明卡片 ----
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 160
                radius: Theme.radius.card; color: Theme.colors.bgCard

                Column {
                    anchors.fill: parent; anchors.margins: Theme.spacing.section; spacing: Theme.spacing.compact

                    Label {
                        text: loginModeSwitch.currentIndex === 0
                              ? qsTr("如何获取 Cookie？") : qsTr("扫码登录说明")
                        color: Theme.colors.textSecondary
                        font.pixelSize: Theme.fontSizes.h3; font.bold: true
                    }

                    Column {
                        visible: loginModeSwitch.currentIndex === 0; spacing: 6
                        Repeater {
                            model: [
                                qsTr("1. 在浏览器中打开 bilibili.com 并登录你的账号"),
                                qsTr("2. 按 F12 打开开发者工具 → 网络(Network) 标签"),
                                qsTr("3. 刷新页面，点击任意请求，在请求头中找到 Cookie 字段"),
                                qsTr("4. 复制完整的 Cookie 值，粘贴到上方输入框中"),
                                qsTr("注：Cookie 仅保存在本地，不会上传或泄露")
                            ]
                            delegate: Label {
                                required property var modelData
                                text: modelData
                                color: index < 4 ? Theme.colors.textTertiary : Theme.colors.textDim
                                font.pixelSize: Theme.fontSizes.caption
                            }
                        }
                    }
                    Column {
                        visible: loginModeSwitch.currentIndex === 1; spacing: 6
                        Repeater {
                            model: [
                                qsTr("1. 点击「获取二维码」按钮生成登录二维码"),
                                qsTr("2. 打开B站手机APP，点击右上角扫码图标"),
                                qsTr("3. 扫描屏幕上的二维码"),
                                qsTr("4. 在手机上确认登录"),
                                qsTr("注：二维码有效期为3分钟，过期后需刷新")
                            ]
                            delegate: Label {
                                required property var modelData
                                text: modelData
                                color: index < 4 ? Theme.colors.textTertiary : Theme.colors.textDim
                                font.pixelSize: Theme.fontSizes.caption
                            }
                        }
                    }
                }
            }
        }
    }
}
