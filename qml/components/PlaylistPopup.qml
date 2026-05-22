// ============================================================================
// PlaylistPopup.qml - 播放列表弹出窗口
// ============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Theme.js" as Theme

Popup {
    id: popup

    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    width: 480; height: 560

    property var _ps: null

    Component.onCompleted: Qt.callLater(function() {
        _ps = applicationContext ? applicationContext.playlistService : null
    })

    background: Rectangle {
        color: Theme.colors.bgCard
        radius: Theme.radius.card
        border.color: Theme.colors.borderPlayer
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing.section
        spacing: Theme.spacing.card

        // ---- 标题栏 ----
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

        // ---- 列表 ----
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
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
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
                            return t.length > 28 ? t.substring(0, 28) + "..." : t
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
                            var m = Math.floor(dur / 60), s = dur % 60
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

        // ---- 底部按钮 ----
        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }

            AppButton {
                text: qsTr("清空列表")
                enabled: _ps && _ps.playlistSize > 0
                bgColor: Theme.colors.borderInput
                btnWidth: 80; btnHeight: 32
                fontSize: Theme.fontSizes.small
                onClicked: { if (_ps) _ps.clear(); popup.close() }
            }
        }
    }
}
