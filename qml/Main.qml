// ============================================================================
// Main.qml - 主窗口
// 功能：三段式布局——左侧导航栏 + 中间内容区 + 底部播放栏
// 与 C++ 的交互：通过 applicationContext 访问 PlayerController 等阶段二服务
// ============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: window

    width: 1360
    height: 860
    visible: true
    title: qsTr("Bilibili Music Client")
    color: "#181818"

    // ---- 安全访问 PlayerController ----
    // Component.onCompleted/Qt.callLater 确保 applicationContext 已就绪
    property var _pc: null  // PlayerController 引用

    Component.onCompleted: Qt.callLater(function() {
        _pc = applicationContext ? applicationContext.playerController : null
        console.log("[Main] playerController 就绪:", !!_pc)
    })

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Sidebar {
            id: sidebar
            Layout.fillHeight: true
            Layout.preferredWidth: 240
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#202020"

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                StackLayout {
                    id: pageStack
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: sidebar.currentIndex

                    HomePage {}
                    FavoritesPage {}
                    LoginPage {}
                }

                // ---- 底部播放栏 ----
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 92
                    color: "#141414"
                    border.color: "#292929"
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 16

                        // 封面
                        Image {
                            Layout.preferredWidth: 52
                            Layout.preferredHeight: 52
                            // 通过 _pc 安全访问
                            source: _pc ? _pc.mediaCover : ""
                            fillMode: Image.PreserveAspectCrop
                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                color: "#2a2a2a"
                                visible: parent.status !== Image.Ready
                            }
                        }

                        // 歌曲信息
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Label {
                                text: (_pc && _pc.mediaTitle) || qsTr("未在播放")
                                color: "#f5f5f5"
                                font.pixelSize: 16
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Label {
                                text: _pc && _pc.playbackState === "Playing"
                                      ? qsTr("正在播放...")
                                      : qsTr("已暂停")
                                color: "#9d9d9d"
                                font.pixelSize: 12
                            }
                        }

                        // 播放/暂停按钮
                        Button {
                            enabled: _pc !== null
                            text: _pc && _pc.playbackState === "Playing"
                                  ? qsTr("暂停") : qsTr("播放")
                            onClicked: {
                                if (!_pc) return
                                if (_pc.playbackState === "Playing") {
                                    _pc.pause()
                                } else {
                                    _pc.play()
                                }
                            }
                            background: Rectangle {
                                radius: 20
                                color: "#fb7299"
                                implicitWidth: 80
                                implicitHeight: 36
                            }
                            contentItem: Text {
                                text: parent.text
                                color: "#ffffff"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        // 进度条
                        Slider {
                            id: progressSlider
                            Layout.preferredWidth: 180
                            from: 0
                            to: (_pc && _pc.source !== "") ? _pc.duration : 0
                            value: _pc ? _pc.position : 0
                            enabled: _pc !== null
                            // 只在用户释放滑块时 seek（防止绑定循环）
                            onMoved: {
                                if (_pc && _pc.source !== "")
                                    _pc.seek(value)
                            }

                            background: Rectangle {
                                x: parent.leftPadding
                                y: parent.topPadding + parent.availableHeight / 2 - height / 2
                                width: parent.availableWidth
                                height: 4
                                radius: 2
                                color: "#3a3a3a"
                                Rectangle {
                                    width: parent.width * ((_pc ? _pc.position : 0)
                                        / Math.max((_pc ? _pc.duration : 1), 1))
                                    height: parent.height
                                    color: "#fb7299"
                                    radius: 2
                                }
                            }
                        }

                        // 音量
                        Slider {
                            Layout.preferredWidth: 100
                            from: 0
                            to: 100
                            value: _pc ? _pc.volume * 100 : 50
                            onMoved: if (_pc) _pc.setVolume(value / 100)
                        }
                    }
                }
            }
        }
    }
}
