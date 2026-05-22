// ============================================================================
// Main.qml - 主窗口 （阶段三：Theme 引用）
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

    property var _pc: null
    property var _ps: null

    Component.onCompleted: Qt.callLater(function() {
        _pc = applicationContext ? applicationContext.playerController : null
        _ps = applicationContext ? applicationContext.playlistService : null
    })

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

                // ---- 底部播放栏 ----
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.sizes.playerHeight
                    color: Theme.colors.bgPlayer
                    border.color: Theme.colors.borderPlayer; border.width: 1

                    RowLayout {
                        anchors.fill: parent; anchors.margins: Theme.spacing.card
                        spacing: Theme.spacing.section

                        // 封面
                        Image {
                            Layout.preferredWidth: Theme.sizes.coverSmall
                            Layout.preferredHeight: Theme.sizes.coverSmall
                            source: _pc ? _pc.mediaCover : ""
                            fillMode: Image.PreserveAspectCrop
                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.radius.cover; color: Theme.colors.bgPlaceholder
                                visible: parent.status !== Image.Ready
                            }
                        }

                        // 标题+状态
                        ColumnLayout { Layout.fillWidth: true; spacing: Theme.spacing.tight
                            Label {
                                text: (_pc && _pc.mediaTitle) || qsTr("未在播放")
                                color: Theme.colors.textSecondary; font.pixelSize: Theme.fontSizes.body
                                font.bold: true; elide: Text.ElideRight
                            }
                            Label {
                                text: _pc && _pc.playbackState === "Playing" ? qsTr("正在播放...") : qsTr("已暂停")
                                color: Theme.colors.textMuted; font.pixelSize: Theme.fontSizes.small
                            }
                        }

                        // 播放/暂停
                        Button {
                            enabled: _pc !== null
                            text: _pc && _pc.playbackState === "Playing" ? qsTr("暂停") : qsTr("播放")
                            onClicked: {
                                if (!_pc) return
                                if (_pc.playbackState === "Playing") _pc.pause(); else _pc.play()
                            }
                            background: Rectangle {
                                radius: Theme.radius.pill; color: Theme.colors.accent
                                implicitWidth: 80; implicitHeight: 36
                            }
                            contentItem: Text {
                                text: parent.text; color: Theme.colors.textPrimary
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            }
                        }

                        // ---- 播放列表控制（上一首 / 模式切换 / 下一首） ----
                        RowLayout {
                            spacing: 2
                            visible: _ps && _ps.playlistSize > 1

                            Button {
                                text: "⏮"
                                enabled: _ps && _ps.playlistSize > 1
                                onClicked: _ps.previous()
                                flat: true
                                implicitWidth: 36; implicitHeight: 36
                                contentItem: Text {
                                    text: parent.text; color: "#9d9d9d"
                                    font.pixelSize: 16
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                            Button {
                                text: _ps && _ps.playMode === 0 ? "🔁" : "🔀"
                                enabled: _ps && _ps.playlistSize > 1
                                onClicked: _ps.setPlayMode(_ps.playMode === 0 ? 1 : 0)
                                flat: true
                                implicitWidth: 36; implicitHeight: 36
                                contentItem: Text {
                                    text: parent.text; color: _ps && _ps.playMode === 0 ? "#fb7299" : "#ff9800"
                                    font.pixelSize: 16
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                            Button {
                                text: "⏭"
                                enabled: _ps && _ps.playlistSize > 1
                                onClicked: _ps.next()
                                flat: true
                                implicitWidth: 36; implicitHeight: 36
                                contentItem: Text {
                                    text: parent.text; color: "#9d9d9d"
                                    font.pixelSize: 16
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }

                        // 进度 + 时间标签
                        RowLayout {
                            Layout.preferredWidth: 260
                            spacing: 8

                            // 当前时间
                            Label {
                                text: {
                                    if (!_pc || _pc.source === "") return "00:00"
                                    var sec = Math.floor(_pc.position / 1000)
                                    var m = Math.floor(sec / 60)
                                    var s = sec % 60
                                    return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
                                }
                                color: Theme.colors.textMuted
                                font.pixelSize: Theme.fontSizes.small
                                font.family: "Consolas"
                            }

                            Slider {
                                id: progressSlider
                                Layout.fillWidth: true
                                from: 0; to: (_pc && _pc.source !== "") ? _pc.duration : 0
                                value: _pc ? _pc.position : 0; enabled: _pc !== null
                                onMoved: { if (_pc && _pc.source !== "") _pc.seek(value) }
                                background: Rectangle {
                                    x: parent.leftPadding; y: parent.topPadding + parent.availableHeight / 2 - height / 2
                                    width: parent.availableWidth; height: 4; radius: 2; color: Theme.colors.borderInput
                                    Rectangle {
                                        width: parent.width * ((_pc ? _pc.position : 0) / Math.max((_pc ? _pc.duration : 1), 1))
                                        height: parent.height; color: Theme.colors.accent; radius: 2
                                    }
                                }
                            }

                            // 总时长
                            Label {
                                text: {
                                    if (!_pc || _pc.source === "" || _pc.duration <= 0) return "00:00"
                                    var sec = Math.floor(_pc.duration / 1000)
                                    var m = Math.floor(sec / 60)
                                    var s = sec % 60
                                    return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
                                }
                                color: Theme.colors.textMuted
                                font.pixelSize: Theme.fontSizes.small
                                font.family: "Consolas"
                            }
                        }

                        // 音量
                        Slider {
                            Layout.preferredWidth: 100
                            from: 0; to: 100
                            value: _pc ? _pc.volume * 100 : 50
                            onMoved: if (_pc) _pc.setVolume(value / 100)
                        }

                        // 播放列表按钮
                        Button {
                            text: "📋"
                            enabled: _ps && _ps.playlistSize > 0
                            flat: true
                            implicitWidth: 36; implicitHeight: 36
                            onClicked: playlistPopup.open()
                            contentItem: Text {
                                text: parent.text; color: "#9d9d9d"
                                font.pixelSize: 16
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- 播放列表弹出窗口 ----
    Popup {
        id: playlistPopup
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        width: 480; height: 560
        x: (window.width - width) / 2
        y: (window.height - height) / 2

        background: Rectangle {
            color: Theme.colors.bgCard
            radius: Theme.radius.card
            border.color: Theme.colors.borderPlayer
        }

        ColumnLayout {
            anchors.fill: parent; anchors.margins: Theme.spacing.section
            spacing: Theme.spacing.card

            // 标题栏
            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: qsTr("播放列表 (%1)").arg(_ps ? _ps.playlistSize : 0)
                    color: Theme.colors.textPrimary
                    font.pixelSize: Theme.fontSizes.h2; font.bold: true
                }
                Item { Layout.fillWidth: true }
                Label {
                    text: _ps && _ps.playMode === 1 ? qsTr("随机") : qsTr("顺序")
                    color: Theme.colors.textTertiary
                    font.pixelSize: Theme.fontSizes.small
                }
            }

            // 列表
            ListView {
                id: playlistView
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true; spacing: 4
                model: _ps ? JSON.parse(_ps.playlistItems) : []
                currentIndex: _ps ? _ps.currentIndex : -1
                highlight: Component {
                    Rectangle {
                        color: Theme.colors.accent
                        opacity: 0.3; radius: 6
                    }
                }
                delegate: Rectangle {
                    width: playlistView.width
                    implicitHeight: 48; radius: 6
                    color: index === (_ps ? _ps.currentIndex : -1)
                           ? Theme.colors.bgCardHover : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.duration.fast } }

                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { if (_ps) _ps.playAt(index) }
                    }

                    RowLayout {
                        anchors.fill: parent; anchors.margins: 8
                        spacing: Theme.spacing.item

                        Label {
                            text: String(index + 1)
                            color: index === (_ps ? _ps.currentIndex : -1)
                                   ? Theme.colors.accent : Theme.colors.textMuted
                            font.pixelSize: Theme.fontSizes.small
                            font.bold: index === (_ps ? _ps.currentIndex : -1)
                            Layout.preferredWidth: 24
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Label {
                            text: {
                                var t = modelData.title || "?"
                                if (t.length > 28) t = t.substring(0, 28) + "..."
                                return t
                            }
                            color: index === (_ps ? _ps.currentIndex : -1)
                                   ? Theme.colors.textPrimary : Theme.colors.textSecondary
                            font.pixelSize: Theme.fontSizes.body
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Label {
                            text: {
                                var dur = modelData.duration || 0
                                var m = Math.floor(dur / 60)
                                var s = dur % 60
                                return m + ":" + (s < 10 ? "0" : "") + s
                            }
                            color: Theme.colors.textDim
                            font.pixelSize: Theme.fontSizes.small
                            font.family: "Consolas"
                        }
                        Label {
                            text: modelData.type === 12 ? "♪" : "▶"
                            color: Theme.colors.textDim
                            font.pixelSize: 12
                        }
                    }
                }
            }

            // 底部按钮：关闭 + 清空
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("清空列表")
                    enabled: _ps && _ps.playlistSize > 0
                    onClicked: { if (_ps) _ps.clear(); playlistPopup.close() }
                    background: Rectangle {
                        color: Theme.colors.borderInput; radius: Theme.radius.button
                        implicitWidth: 80; implicitHeight: 32
                    }
                    contentItem: Text {
                        text: parent.text; color: Theme.colors.textPrimary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: Theme.fontSizes.small
                    }
                }
            }
        }
    }
}
