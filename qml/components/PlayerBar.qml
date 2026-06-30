// ============================================================================
// PlayerBar.qml - 底部播放控制栏
//
// 新人阅读重点：
// 1. 这是一个“展示 + 控制”组件，真正的播放逻辑在 C++ PlayerController。
// 2. _pc 保存 playerController，_ps 保存 playlistService，都是 applicationContext 暴露的服务。
// 3. 按钮点击直接调用 C++ 的 Q_INVOKABLE 方法，如 play()/pause()/next()/seek()。
// 4. 打开播放列表时不直接操作 Popup，而是发出 playlistButtonClicked 信号给 Main.qml。
// ============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Theme.js" as Theme

Rectangle {
    id: bar

    // ---- 信号 ----
    signal playlistButtonClicked()

    // ---- 内部引用 ----
    // Qt.callLater 后再取 applicationContext，避免组件创建早期 C++ 上下文还没就绪。
    property var _pc: null
    property var _ps: null

    color: Theme.colors.bgPlayer
    border.color: Theme.colors.borderPlayer
    border.width: 1

    Component.onCompleted: Qt.callLater(function() {
        _pc = applicationContext ? applicationContext.playerController : null
        _ps = applicationContext ? applicationContext.playlistService : null
    })

    RowLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing.card
        spacing: Theme.spacing.section

        // ---- 封面 ----
        Rectangle {
            Layout.preferredWidth: Theme.sizes.coverSmall
            Layout.preferredHeight: Theme.sizes.coverSmall
            radius: Theme.radius.cover
            color: Theme.colors.bgPlaceholder

            Image {
                anchors.fill: parent
                source: _pc ? _pc.mediaCover : ""
                fillMode: Image.PreserveAspectCrop
            }
        }

        // ---- 标题 + 状态 ----
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.tight

            Label {
                text: (_pc && _pc.mediaTitle) || qsTr("未在播放")
                color: Theme.colors.textSecondary
                font.pixelSize: Theme.fontSizes.body
                font.bold: true
                elide: Text.ElideRight
            }
            Label {
                text: _pc && _pc.playbackState === "Playing" ? qsTr("正在播放...") : qsTr("已暂停")
                color: Theme.colors.textMuted
                font.pixelSize: Theme.fontSizes.small
            }
        }

        // ---- 播放/暂停 ----
        AppButton {
            text: _pc && _pc.playbackState === "Playing" ? qsTr("暂停") : qsTr("播放")
            enabled: _pc !== null
            btnWidth: 80; btnHeight: 36
            btnRadius: Theme.radius.pill
            onClicked: {
                if (!_pc) return
                if (_pc.playbackState === "Playing") _pc.pause()
                else _pc.play()
            }
        }

        // ---- 上一首 / 模式 / 下一首 ----
        RowLayout {
            spacing: 2
            visible: _ps && _ps.playlistSize > 1

            AppButton {
                text: "⏮"
                enabled: _ps && _ps.playlistSize > 1
                flatButton: true
                btnWidth: 36; btnHeight: 36
                textColor: "#9d9d9d"
                fontSize: 16
                onClicked: _ps.previous()
            }
            AppButton {
                text: _ps && _ps.playMode === 0 ? "🔁" : "🔀"
                enabled: _ps && _ps.playlistSize > 1
                flatButton: true
                btnWidth: 36; btnHeight: 36
                textColor: _ps && _ps.playMode === 0 ? "#fb7299" : "#ff9800"
                fontSize: 16
                onClicked: _ps.setPlayMode(_ps.playMode === 0 ? 1 : 0)
            }
            AppButton {
                text: "⏭"
                enabled: _ps && _ps.playlistSize > 1
                flatButton: true
                btnWidth: 36; btnHeight: 36
                textColor: "#9d9d9d"
                fontSize: 16
                onClicked: _ps.next()
            }
        }

        // ---- 进度条 + 时间 ----
        RowLayout {
            Layout.preferredWidth: 260
            spacing: 8

            Label {
                text: {
                    if (!_pc || _pc.source === "") return "00:00"
                    var sec = Math.floor(_pc.position / 1000)
                    var m = Math.floor(sec / 60), s = sec % 60
                    return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
                }
                color: Theme.colors.textMuted
                font.pixelSize: Theme.fontSizes.small
                font.family: "Consolas"
            }

            Slider {
                id: progressSlider
                Layout.fillWidth: true
                from: 0
                to: (_pc && _pc.source !== "") ? _pc.duration : 0
                value: _pc ? _pc.position : 0
                enabled: _pc !== null
                // onMoved 只在用户拖动时触发；普通 position 更新不会反复 seek。
                onMoved: { if (_pc && _pc.source !== "") _pc.seek(value) }

                background: Rectangle {
                    x: parent.leftPadding
                    y: parent.topPadding + parent.availableHeight / 2 - height / 2
                    width: parent.availableWidth
                    height: 4; radius: 2
                    color: Theme.colors.borderInput

                    Rectangle {
                        width: parent.width * ((_pc ? _pc.position : 0) / Math.max((_pc ? _pc.duration : 1), 1))
                        height: parent.height
                        color: Theme.colors.accent; radius: 2
                    }
                }
            }

            Label {
                text: {
                    if (!_pc || _pc.source === "" || _pc.duration <= 0) return "00:00"
                    var sec = Math.floor(_pc.duration / 1000)
                    var m = Math.floor(sec / 60), s = sec % 60
                    return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
                }
                color: Theme.colors.textMuted
                font.pixelSize: Theme.fontSizes.small
                font.family: "Consolas"
            }
        }

        // ---- 音量 ----
        Slider {
            Layout.preferredWidth: 100
            from: 0; to: 100
            value: _pc ? _pc.volume * 100 : 50
            // QML 使用 0~100，C++ QAudioOutput 使用 0.0~1.0。
            onMoved: if (_pc) _pc.setVolume(value / 100)
        }

        // ---- 播放列表按钮 ----
        AppButton {
            text: "📋"
            enabled: _ps && _ps.playlistSize > 0
            flatButton: true
            btnWidth: 36; btnHeight: 36
            textColor: "#9d9d9d"
            fontSize: 16
            onClicked: bar.playlistButtonClicked()
        }
    }
}
