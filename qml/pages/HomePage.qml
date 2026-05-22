// ============================================================================
// HomePage.qml - 首页（阶段三：B站音乐区热门推荐 3列网格卡片）
// ============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components/Theme.js" as Theme

ScrollView {
    clip: true

    property var musicModel: []
    property bool _loading: false

    // 信号连接 + 自动加载
    Component.onCompleted: Qt.callLater(function() {
        var svc = applicationContext ? applicationContext.musicService : null
        if (!svc) return
        svc.musicRankLoaded.connect(function(success, json, error) {
            _loading = false
            if (success && json && json.length > 0) {
                try { musicModel = JSON.parse(json) } catch(e) {}
            }
        })
        loadMusic()
    })

    function loadMusic() { _loading = true; musicModel = []; applicationContext.musicService.loadMusicRank(1, 6) }

    function fmtDur(sec) {
        var m = Math.floor(sec / 60), s = sec % 60
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
    }

    // 3列卡片宽度计算: (900 - 2*24边距 - 2*20卡片间距) / 3 = ~270
    property int cardW: (900 - 2 * Theme.spacing.page - 2 * Theme.spacing.card) / 3

    Rectangle {
        implicitWidth: 900
        implicitHeight: contentColumn.implicitHeight + 48
        color: Theme.colors.bgContent

        ColumnLayout {
            id: contentColumn
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            anchors.margins: Theme.spacing.page; spacing: Theme.spacing.card

            Label {
                text: qsTr("B站音乐区热门")
                color: Theme.colors.textPrimary; font.pixelSize: Theme.fontSizes.h1; font.bold: true
            }

            Button {
                text: qsTr("加载热门音乐")
                visible: musicModel.length === 0 && !_loading
                onClicked: loadMusic()
                background: Rectangle {
                    color: Theme.colors.accent; radius: Theme.radius.button
                    implicitWidth: 180; implicitHeight: Theme.sizes.btnHeight
                }
                contentItem: Text {
                    text: parent.text; color: Theme.colors.textPrimary
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    font.pixelSize: Theme.fontSizes.bodySmall
                }
            }

            Label {
                visible: _loading
                text: qsTr("加载中..."); color: Theme.colors.textMuted
                font.pixelSize: Theme.fontSizes.caption
            }

            // 3 列网格：固定每列宽度 = cardW，GridLayout 自动换行
            GridLayout {
                id: musicGrid; columns: 3
                rowSpacing: Theme.spacing.card; columnSpacing: Theme.spacing.card
                visible: musicModel.length > 0

                Repeater {
                    model: musicModel
                    delegate: Rectangle {
                        readonly property var _item: musicModel[index] || {}
                        Layout.preferredWidth: cardW
                        implicitHeight: cardCol.implicitHeight + 32
                        radius: Theme.radius.card
                        color: cardMouse.containsMouse ? Theme.colors.bgCardHover : Theme.colors.bgCard
                        Behavior on color { ColorAnimation { duration: Theme.duration.fast } }

                        MouseArea {
                            id: cardMouse; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                applicationContext.playerController.mediaTitle = _item.title || qsTr("未知")
                                applicationContext.playerController.mediaCover = _item.cover || ""
                                applicationContext.mediaResolver.resolve(_item.id, 12)
                            }
                        }

                        ColumnLayout {
                            id: cardCol
                            anchors.fill: parent; anchors.margins: Theme.spacing.item
                            spacing: Theme.spacing.compact

                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: Layout.preferredWidth * 0.6
                                radius: Theme.radius.cover; clip: true; color: Theme.colors.bgPlaceholder
                                Image {
                                    anchors.fill: parent; source: _item.cover || ""
                                    fillMode: Image.PreserveAspectCrop
                                }
                                Label {
                                    anchors.centerIn: parent; text: "♪"
                                    color: Theme.colors.textDim; font.pixelSize: 32
                                    visible: parent.children[0].status !== Image.Ready
                                }
                            }

                            Label {
                                text: _item.title || qsTr("未知歌曲")
                                color: Theme.colors.textSecondary; font.pixelSize: Theme.fontSizes.body
                                font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true; maximumLineCount: 1
                            }
                            Label {
                                text: _item.artist || ""; color: Theme.colors.textTertiary
                                font.pixelSize: Theme.fontSizes.caption; visible: text.length > 0
                            }
                            Label {
                                text: fmtDur(_item.duration || 0); color: Theme.colors.textDim
                                font.pixelSize: Theme.fontSizes.small; font.family: "Consolas"
                            }
                        }
                    }
                }
            }
        }
    }
}
