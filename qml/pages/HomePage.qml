// ============================================================================
// HomePage.qml - 首页（B站音乐区热门推荐 横向列表）
//
// 新人阅读重点：
// 1. 这是最简单的一条“QML 调 C++ 服务”的链路。
// 2. 页面启动时连接 musicService.musicRankLoaded 信号，然后调用 loadMusicRank()。
// 3. C++ 返回 JSON 字符串，QML 用 JSON.parse() 转成数组给 Repeater 展示。
// 4. 点击卡片时这里只走单曲播放，不创建 PlaylistService 播放列表。
// ============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components/Theme.js" as Theme

ScrollView {
    clip: true

    // musicModel 是页面本地状态，不是 C++ Model。
    // C++ 只传回 JSON 字符串，QML 解析后存到这个数组。
    property var musicModel: []
    property bool _loading: false

    // Qt.callLater 让连接和加载动作推迟到组件创建完成之后执行，
    // 避免 applicationContext 或子对象还没准备好时就访问。
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
        // Q_INVOKABLE: 这里从 QML 直接调用 C++ 的 MusicService::loadMusicRank。
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
                    // Repeater 的 index 是 delegate 隐式提供的当前下标。
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
                        // 首页卡片不经过播放列表，直接设置播放器展示信息并解析单首音频。
                        applicationContext.playerController.mediaTitle = _item.title || qsTr("未知")
                        applicationContext.playerController.mediaCover = _item.cover || ""
                        applicationContext.mediaResolver.resolve(_item.id, 12)
                    }
                }
            }
        }
    }
}
