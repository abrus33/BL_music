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

    Component.onCompleted: Qt.callLater(function() {
        _pc = applicationContext ? applicationContext.playerController : null
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
                    }
                }
            }
        }
    }
}
