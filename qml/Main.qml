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

    // ---- 窗口基础属性 ----
    width: 1360
    height: 860
    visible: true
    title: qsTr("Bilibili Music Client")
    color: "#181818"

    // ---- 主体布局 ----
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ========== 左侧导航栏 ==========
        Sidebar {
            id: sidebar
            Layout.fillHeight: true
            Layout.preferredWidth: 240
        }

        // ========== 中间内容区 ==========
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#202020"

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // ---- 页面容器 ----
                StackLayout {
                    id: pageStack
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: sidebar.currentIndex

                    HomePage {}
                    FavoritesPage {}
                    LoginPage {}
                }

                // ---- 底部播放栏（阶段二：接入 PlayerController） ----
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 92
                    color: "#141414"
                    border.color: "#292929"
                    border.width: 1

                    // 播放栏内容布局
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 16

                        // 封面（绑定 C++ PlayerController.mediaCover）
                        Image {
                            Layout.preferredWidth: 52
                            Layout.preferredHeight: 52
                            source: applicationContext.playerController.mediaCover
                            fillMode: Image.PreserveAspectCrop

                            // 无封面时显示默认占位图
                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                color: "#2a2a2a"
                                visible: parent.status !== Image.Ready
                            }
                        }

                        // 歌曲信息（绑定 C++ PlayerController.mediaTitle）
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Label {
                                // 显示当前播放的媒体标题
                                text: applicationContext.playerController.mediaTitle
                                      || qsTr("未在播放")
                                color: "#f5f5f5"
                                font.pixelSize: 16
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Label {
                                // 显示播放状态：Playing / Paused / Stopped
                                text: applicationContext.playerController.playbackState === "Playing"
                                      ? qsTr("正在播放...")
                                      : qsTr("已暂停")
                                color: "#9d9d9d"
                                font.pixelSize: 12
                            }
                        }

                        // 播放/暂停按钮
                        Button {
                            text: applicationContext.playerController.playbackState === "Playing"
                                  ? qsTr("暂停") : qsTr("播放")
                            onClicked: {
                                if (applicationContext.playerController.playbackState === "Playing") {
                                    applicationContext.playerController.pause()
                                } else {
                                    applicationContext.playerController.play()
                                }
                            }
                            background: Rectangle {
                                radius: 20
                                color: "#fb7299"
                                implicitWidth: 80
                                implicitHeight: 36
                            }
                            contentItem: Label {
                                text: parent.text
                                color: "#ffffff"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        // 进度条（绑定 C++ PlayerController.position/duration）
                        Slider {
                            Layout.preferredWidth: 180
                            from: 0
                            to: applicationContext.playerController.duration
                            value: applicationContext.playerController.position
                            onMoved: applicationContext.playerController.seek(value)

                            background: Rectangle {
                                x: parent.leftPadding
                                y: parent.topPadding + parent.availableHeight / 2 - height / 2
                                width: parent.availableWidth
                                height: 4
                                radius: 2
                                color: "#3a3a3a"
                                Rectangle {
                                    width: parent.width * (applicationContext.playerController.position
                                                           / Math.max(applicationContext.playerController.duration, 1))
                                    height: parent.height
                                    color: "#fb7299"
                                    radius: 2
                                }
                            }
                        }

                        // 音量控制（绑定 C++ PlayerController.volume 0.0-1.0）
                        Slider {
                            Layout.preferredWidth: 100
                            from: 0
                            to: 100
                            value: applicationContext.playerController.volume * 100
                            onMoved: applicationContext.playerController.setVolume(value / 100)
                        }
                    }
                }
            }
        }
    }
}
