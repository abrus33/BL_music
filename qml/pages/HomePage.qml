// ============================================================================
// HomePage.qml - 首页（B站音乐区热门推荐 横向列表）
// ============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components/Theme.js" as Theme

ScrollView {
    clip: true

    property var musicModel: []
    property bool _loading: false

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

    function loadMusic() {
        _loading = true; musicModel = []
        applicationContext.musicService.loadMusicRank(1, 6)
    }

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
                color: Theme.colors.textPrimary
                font.pixelSize: Theme.fontSizes.h1; font.bold: true
            }

            AppButton {
                text: qsTr("加载热门音乐")
                visible: musicModel.length === 0 && !_loading
                onClicked: loadMusic()
            }

            Label {
                visible: _loading
                text: qsTr("加载中...")
                color: Theme.colors.textMuted; font.pixelSize: Theme.fontSizes.caption
            }

            // ---- 横向列表（与收藏夹资源列表布局一致） ----
            Repeater {
                model: musicModel
                delegate: MediaCard {
                    readonly property var _item: musicModel[index] || {}
                    Layout.fillWidth: true
                    implicitHeight: 100
                    layoutMode: "list"
                    coverUrl: _item.cover || ""
                    title: _item.title || qsTr("未知歌曲")
                    subtitle: _item.artist || ""
                    duration: _item.duration || 0
                    mediaType: 12

                    onClicked: {
                        applicationContext.playerController.mediaTitle = _item.title || qsTr("未知")
                        applicationContext.playerController.mediaCover = _item.cover || ""
                        applicationContext.mediaResolver.resolve(_item.id, 12)
                    }
                }
            }
        }
    }
}
