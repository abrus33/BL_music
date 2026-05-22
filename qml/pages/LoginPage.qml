// ============================================================================
// LoginPage.qml - 登录页面
// 功能：Cookie 登录 + 扫码登录
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

            // ---- 登录方式切换按钮 ----
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 0

                Rectangle {
                    implicitWidth: 140; implicitHeight: 40
                    radius: 8
                    color: loginModeSwitch.currentIndex === 0 ? "#fb7299" : "#2a2a2a"

                    Label {
                        anchors.centerIn: parent
                        text: qsTr("Cookie 登录")
                        color: loginModeSwitch.currentIndex === 0 ? "#ffffff" : "#9d9d9d"
                        font.pixelSize: 14
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: loginModeSwitch.currentIndex = 0
                    }
                }

                Item { width: 8; height: 1 }

                Rectangle {
                    implicitWidth: 140; implicitHeight: 40
                    radius: 8
                    color: loginModeSwitch.currentIndex === 1 ? "#fb7299" : "#2a2a2a"

                    Label {
                        anchors.centerIn: parent
                        text: qsTr("扫码登录")
                        color: loginModeSwitch.currentIndex === 1 ? "#ffffff" : "#9d9d9d"
                        font.pixelSize: 14
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: loginModeSwitch.currentIndex = 1
                    }
                }
            }

            // ---- 使用 SwipeView 切换登录方式 ----
            // SwipeView 包含两个页面：Cookie 登录（索引0）和 扫码登录（索引1）
            // interactive: false 禁止手指滑动切换，只能通过顶部按钮控制
            // 这样可以避免用户在输入 Cookie 时误触切换
            SwipeView {
                id: loginModeSwitch
                Layout.fillWidth: true
                Layout.preferredHeight: currentItem ? currentItem.implicitHeight : 300
                interactive: false  // 不允许滑动切换，只能用按钮

                // ---- 0: Cookie 登录 ----
                Item {
                    implicitHeight: cookieCard.height

                    Rectangle {
                        id: cookieCard
                        width: parent.width
                        height: cookieLayout.implicitHeight + 40
                        radius: 12
                        color: "#262626"

                        ColumnLayout {
                            id: cookieLayout
                            anchors.centerIn: parent
                            width: parent.width - 40
                            spacing: 16

                            Label {
                                Layout.alignment: Qt.AlignHCenter
                                text: qsTr("从浏览器开发者工具复制 Cookie")
                                color: "#9d9d9d"
                                font.pixelSize: 13
                                wrapMode: Text.Wrap
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 40
                                Layout.maximumWidth: 500
                                Layout.alignment: Qt.AlignHCenter
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
                                    Text {
                                        anchors.fill: parent
                                        text: qsTr("SESSDATA=xxx; bili_jct=xxx; ...")
                                        color: "#5a5a5a"
                                        font: parent.font
                                        visible: !parent.text.length
                                    }
                                }
                            }

                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 12

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
                                    implicitWidth: 160; implicitHeight: 40

                                    onClicked: {
                                        applicationContext.authService.importCookie(cookieInput.text.trim())
                                        cookieInput.text = ""
                                    }
                                }

                                Button {
                                    text: qsTr("退出登录")
                                    visible: applicationContext.authService.isLoggedIn

                                    background: Rectangle { radius: 8; color: "#3a3a3a" }
                                    contentItem: Label {
                                        text: parent.text; color: "#dddddd"; font.pixelSize: 14
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    implicitWidth: 120; implicitHeight: 40
                                    onClicked: applicationContext.authService.logout()
                                }
                            }

                            Label {
                                id: loginResultLabel
                                Layout.alignment: Qt.AlignHCenter
                                text: ""
                                color: "#fb7299"
                                font.pixelSize: 12
                                visible: text.length > 0
                            }

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
                }

                // ---- 1: 扫码登录 ----
                // 扫码登录页面布局：
                //   [标题] 使用B站APP扫描二维码登录
                //   [二维码容器 236x236] 白色背景 + 220x220 二维码图片
                //     - 占位状态：灰色方块 + 提示文字（"二维码加载中..." / "点击下方按钮生成二维码"）
                //     - 显示状态：Image 组件绑定 qrImageUrl 属性
                //   [状态文字] 动态颜色（绿色=成功 / 红色=过期或失败 / 橙色=待确认 / 灰色=等待）
                //   [操作按钮] 获取二维码（json=genActive禁用） / 取消（仅活跃时可见）
                Item {
                    implicitHeight: qrCard.height

                    Rectangle {
                        id: qrCard
                        width: parent.width
                        height: qrLayout.implicitHeight + 40
                        radius: 12
                        color: "#262626"

                        ColumnLayout {
                            id: qrLayout
                            anchors.centerIn: parent
                            width: parent.width - 40
                            spacing: 16

                            Label {
                                Layout.alignment: Qt.AlignHCenter
                                text: qsTr("使用B站APP扫描二维码登录")
                                color: "#9d9d9d"
                                font.pixelSize: 13
                            }

                            // ---- 二维码图片容器 ----
                            // 外框 236x236 白色圆角矩形，内嵌 220x220 二维码图片
                            // 使用 online QR API: api.qrserver.com
                            // 当 qrImageUrl 为空时显示占位符（灰色方块 + 提示文字）
                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                width: 236; height: 236
                                radius: 12
                                color: "#ffffff"

                                // 占位状态：qrImageUrl 为空时显示
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 220; height: 220
                                    color: "#f5f5f5"
                                    visible: !qrImage.visible

                                    Label {
                                        anchors.centerIn: parent
                                        text: applicationContext.authService.qrLoginActive
                                              ? qsTr("二维码加载中...")
                                              : qsTr("点击下方按钮生成二维码")
                                        color: "#9d9d9d"
                                        font.pixelSize: 13
                                    }
                                }

                                // 二维码图片：绑定 C++ 属性 applicationContext.authService.qrImageUrl
                                // cache: false — 每次二维码都是新链接，不应缓存
                                Image {
                                    id: qrImage
                                    anchors.centerIn: parent
                                    width: 220; height: 220
                                    source: applicationContext.authService.qrImageUrl
                                    visible: applicationContext.authService.qrImageUrl.length > 0
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    cache: false  // 二维码每次都是新的链接

                                    onStatusChanged: {
                                        if (status === Image.Error) {
                                            console.warn("QR code image failed to load:", source)
                                        }
                                    }
                                }
                            }

                            // ---- 扫码状态文字 ----
                            // 直接绑定 qrStatus 属性，颜色根据文字内容动态切换：
                            //   包含"成功" → 绿色 (#4caf50)
                            //   包含"过期"或"失败" → 红色 (#f44336)
                            //   包含"确认" → 橙色 (#ff9800)
                            //   其他 → 灰色 (#9d9d9d)
                            Label {
                                id: qrStatusLabel
                                Layout.alignment: Qt.AlignHCenter
                                text: applicationContext.authService.qrStatus
                                color: {
                                    var s = applicationContext.authService.qrStatus
                                    if (s.includes("成功")) return "#4caf50"
                                    if (s.includes("过期") || s.includes("失败")) return "#f44336"
                                    if (s.includes("确认")) return "#ff9800"
                                    return "#9d9d9d"
                                }
                                font.pixelSize: 13
                                visible: text.length > 0
                            }

                            // ---- 操作按钮 ----
                            // 获取二维码按钮：qrLoginActive=true 时禁用（显示"加载中..."）
                            // 取消按钮：仅 qrLoginActive=true 时可见
                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 12

                                Button {
                                    text: applicationContext.authService.qrLoginActive
                                          ? qsTr("加载中...")
                                          : qsTr("获取二维码")
                                    enabled: !applicationContext.authService.qrLoginActive

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
                                    implicitWidth: 160; implicitHeight: 40
                                    onClicked: applicationContext.authService.startQrLogin()
                                }

                                Button {
                                    text: qsTr("取消")
                                    visible: applicationContext.authService.qrLoginActive

                                    background: Rectangle { radius: 8; color: "#3a3a3a" }
                                    contentItem: Label {
                                        text: parent.text; color: "#dddddd"; font.pixelSize: 14
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    implicitWidth: 100; implicitHeight: 40
                                    onClicked: applicationContext.authService.stopQrLogin()
                                }
                            }
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
                        text: loginModeSwitch.currentIndex === 0
                              ? qsTr("如何获取 Cookie？")
                              : qsTr("扫码登录说明")
                        color: "#f4f4f4"
                        font.pixelSize: 17
                        font.bold: true
                    }

                    // Cookie 登录说明
                    Column {
                        visible: loginModeSwitch.currentIndex === 0
                        spacing: 6
                        Label { text: qsTr("1. 在浏览器中打开 bilibili.com 并登录你的账号"); color: "#a8a8a8"; font.pixelSize: 13 }
                        Label { text: qsTr("2. 按 F12 打开开发者工具 → 网络(Network) 标签"); color: "#a8a8a8"; font.pixelSize: 13 }
                        Label { text: qsTr("3. 刷新页面，点击任意请求，在请求头中找到 Cookie 字段"); color: "#a8a8a8"; font.pixelSize: 13 }
                        Label { text: qsTr("4. 复制完整的 Cookie 值，粘贴到上方输入框中"); color: "#a8a8a8"; font.pixelSize: 13 }
                        Label { text: qsTr("注：Cookie 仅保存在本地，不会上传或泄露"); color: "#7d7d7d"; font.pixelSize: 12 }
                    }

                    // 扫码登录说明
                    Column {
                        visible: loginModeSwitch.currentIndex === 1
                        spacing: 6
                        Label { text: qsTr("1. 点击「获取二维码」按钮生成登录二维码"); color: "#a8a8a8"; font.pixelSize: 13 }
                        Label { text: qsTr("2. 打开B站手机APP，点击右上角扫码图标"); color: "#a8a8a8"; font.pixelSize: 13 }
                        Label { text: qsTr("3. 扫描屏幕上的二维码"); color: "#a8a8a8"; font.pixelSize: 13 }
                        Label { text: qsTr("4. 在手机上确认登录"); color: "#a8a8a8"; font.pixelSize: 13 }
                        Label { text: qsTr("注：二维码有效期为3分钟，过期后需刷新"); color: "#7d7d7d"; font.pixelSize: 12 }
                    }
                }
            }
        }
    }
}
