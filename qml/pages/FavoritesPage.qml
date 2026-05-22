// ============================================================================
// FavoritesPage.qml - 收藏夹页面（阶段三：Theme 引用+悬停效果）
// ============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components/Theme.js" as Theme

ScrollView {
    clip: true

    property string viewState: "folders"
    property string currentFolderTitle: ""
    property var currentMediaId: 0

    property var folderModel: []
    property var resourceModel: []
    property bool hasMoreResources: false

    property bool _loading: false
    property var _pendingStartId: 0   // 用户点击时暂存资源 ID，全量加载完成后用于创建播放列表
    property string _playError: ""

    // ---- 自动加载收藏夹：页面可见且已登录时自动触发 ----
    onVisibleChanged: {
        if (!visible) return
        Qt.callLater(tryAutoLoadFolders)
    }

    Connections {
        target: applicationContext ? applicationContext.authService : null
        enabled: target !== null
        function onLoginStateChanged() {
            // 登录状态变化时：如果已登出，清空列表；如果已登录，尝试自动加载
            var auth = applicationContext.authService
            if (auth && !auth.isLoggedIn) {
                folderModel = []
                resourceModel = []
            }
            if (visible) Qt.callLater(tryAutoLoadFolders)
        }
    }

    function tryAutoLoadFolders() {
        console.log("[FavoritesPage] tryAutoLoadFolders, folderModel.length:", folderModel.length, "_loading:", _loading)
        if (folderModel.length > 0 || _loading) return
        var auth = applicationContext ? applicationContext.authService : null
        if (auth && auth.isLoggedIn) {
            console.log("[FavoritesPage] auto-loading folders, userMid:", auth.userMid)
            _loading = true
            applicationContext.favoriteService.loadFavoriteFolders(auth.userMid)
        } else {
            console.log("[FavoritesPage] skip auto-load: auth=", auth, "isLoggedIn=", auth ? auth.isLoggedIn : "N/A")
        }
    }

    Component.onCompleted: Qt.callLater(function() {
        var svc = applicationContext ? applicationContext.favoriteService : null
        if (!svc) return
        svc.favoriteFoldersLoaded.connect(function(success, f, error) {
            console.log("[FavoritesPage] favoriteFoldersLoaded: success=", success, "jsonLen=", f ? f.length : 0)
            _loading = false
            if (success && f && f.length > 0) { try { folderModel = JSON.parse(f); } catch(e) {} }
        })
        svc.favoriteResourcesLoaded.connect(function(success, info, medias, hasMore, error) {
            console.log("[FavoritesPage] favoriteResourcesLoaded: success=", success, "mediasLen=", medias ? medias.length : 0, "hasMore=", hasMore)
            _loading = false
            if (success && medias && medias.length > 0) {
                try { resourceModel = JSON.parse(medias); } catch(e) {}
                hasMoreResources = hasMore
            } else { resourceModel = []; }
        })
        // mediaResolved 连接仅作错误提示用途（播放由 PlaylistService 管理）
        var res = applicationContext ? applicationContext.mediaResolver : null
        if (res) {
            res.mediaResolved.connect(function(success, url, t, c, d, error) {
                if (!success || error.length > 0) {
                    _playError = qsTr("播放失败: ") + error
                }
            })
        }
        // allFavoriteResourcesLoaded: 全量加载完成后更新显示+创建播放列表
        svc.allFavoriteResourcesLoaded.connect(function(success, mediasJson, error) {
            console.log("[FavoritesPage] allFavoriteResourcesLoaded: success=", success, "jsonLen=", mediasJson ? mediasJson.length : 0, "error=", error, "pendingStartId=", _pendingStartId)
            _loading = false
            if (!success || !mediasJson || mediasJson.length === 0) {
                if (error.length > 0) _playError = qsTr("加载失败: ") + error
                else resourceModel = []
                return
            }
            // 更新页面显示：用全部数据替换 resourceModel
            try { resourceModel = JSON.parse(mediasJson); } catch(e) {}
            hasMoreResources = false

            // 如果用户在加载期间点击了某个视频，创建播放列表
            var ps = applicationContext ? applicationContext.playlistService : null
            if (ps && _pendingStartId > 0) {
                console.log("[FavoritesPage] creating playlist from allFavoriteResources, size:", resourceModel.length, "startId:", _pendingStartId)
                ps.createPlaylist(mediasJson, _pendingStartId)
                _pendingStartId = 0
            }
        })
    })

    Rectangle {
        implicitWidth: 900
        implicitHeight: contentColumn.implicitHeight + 48
        color: Theme.colors.bgContent

        ColumnLayout {
            id: contentColumn
            anchors.left: parent.left; anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.spacing.page
            spacing: Theme.spacing.card

            RowLayout {
                Layout.fillWidth: true; spacing: Theme.spacing.item
                Button {
                    text: qsTr("< 返回")
                    visible: viewState === "resources"; flat: true
                    onClicked: { viewState = "folders"; currentFolderTitle = "" }
                    background: Rectangle {
                        color: Theme.colors.borderInput; radius: Theme.radius.card
                        implicitWidth: 80; implicitHeight: 36
                    }
                    contentItem: Text {
                        text: parent.text; color: Theme.colors.textPrimary
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                }
                Label {
                    text: viewState === "folders" ? qsTr("收藏夹") : currentFolderTitle || qsTr("收藏夹内容")
                    color: Theme.colors.textPrimary
                    font.pixelSize: Theme.fontSizes.h1; font.bold: true
                    Layout.fillWidth: true
                }
            }

            Label {
                visible: viewState === "folders"
                text: (applicationContext && applicationContext.authService
                       && applicationContext.authService.isLoggedIn)
                      ? qsTr("已登录，点击收藏夹查看内容")
                      : qsTr("请先在「登录」页面导入 Cookie")
                color: Theme.colors.textTertiary
                wrapMode: Text.Wrap; Layout.fillWidth: true
                font.pixelSize: Theme.fontSizes.bodySmall
            }

            Button {
                text: qsTr("加载收藏夹列表")
                enabled: applicationContext && applicationContext.authService
                         && applicationContext.authService.isLoggedIn
                visible: folderModel.length === 0 && viewState === "folders"
                onClicked: {
                    _loading = true
                    applicationContext.favoriteService.loadFavoriteFolders(
                        applicationContext.authService.userMid)
                }
                background: Rectangle {
                    color: parent.enabled ? Theme.colors.accent : Theme.colors.borderInput
                    radius: Theme.radius.button
                    implicitWidth: 200; implicitHeight: Theme.sizes.btnHeight
                }
                contentItem: Text {
                    text: parent.text; color: Theme.colors.textPrimary
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    font.pixelSize: Theme.fontSizes.bodySmall
                }
            }

            Label {
                id: loadingLabel
                visible: _loading
                text: qsTr("加载中...")
                color: Theme.colors.textMuted; font.pixelSize: Theme.fontSizes.caption
            }

            // ============ 收藏夹列表 ============
            Repeater {
                id: folderRepeater; model: folderModel; visible: viewState === "folders"
                delegate: Rectangle {
                    readonly property var _item: folderRepeater.model[index] || {}
                    Layout.fillWidth: true
                    implicitHeight: 80; radius: Theme.radius.card
                    color: fldMouse.containsMouse ? Theme.colors.bgCardHover : Theme.colors.bgCard
                    Behavior on color { ColorAnimation { duration: Theme.duration.fast } }

                    MouseArea {
                        id: fldMouse; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var mid = _item.id || 0
                            console.log("[FavoritesPage] folder clicked: id=", mid, "title=", _item.title)
                            viewState = "resources"
                            currentFolderTitle = _item.title || qsTr("收藏夹"); currentMediaId = mid
                            _loading = true; resourceModel = []; _playError = ""
                            applicationContext.favoriteService.loadAllFavoriteResources(mid)
                        }
                    }
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: Theme.spacing.section; spacing: Theme.spacing.tight
                        Label {
                            text: _item.title || qsTr("未知收藏夹")
                            color: Theme.colors.textSecondary; font.pixelSize: Theme.fontSizes.h3
                            font.bold: true; elide: Text.ElideRight
                        }
                        Label {
                            text: qsTr("%1 个内容").arg(_item.media_count || 0)
                            color: Theme.colors.textTertiary; font.pixelSize: Theme.fontSizes.caption
                        }
                    }
                }
            }

            // ============ 资源列表 ============
            Repeater {
                id: resRepeater; model: resourceModel; visible: viewState === "resources"
                delegate: Rectangle {
                    readonly property var _item: resRepeater.model[index] || {}
                    Layout.fillWidth: true
                    implicitHeight: 100; radius: Theme.radius.card
                    color: resMouse.containsMouse ? Theme.colors.bgCardHover : Theme.colors.bgCard
                    Behavior on color { ColorAnimation { duration: Theme.duration.fast } }

                    MouseArea {
                        id: resMouse; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            console.log("[FavoritesPage] resource clicked: id=", _item.id, "title=", _item.title, "attr=", _item.attr)
                            if (_item.attr !== undefined && _item.attr !== 0) {
                                _playError = qsTr("该资源已失效"); return
                            }
                            var ps = applicationContext ? applicationContext.playlistService : null
                            if (ps && resourceModel.length > 0) {
                                // 数据已在进入收藏夹时全量加载，直接创建播放列表
                                console.log("[FavoritesPage] creating playlist from resourceModel, size:", resourceModel.length, "startId:", _item.id)
                                ps.createPlaylist(JSON.stringify(resourceModel), _item.id)
                            } else {
                                // 回退：数据尚未加载完成，暂存 ID 等待 allFavoriteResourcesLoaded
                                console.log("[FavoritesPage] resourceModel not ready, deferring via _pendingStartId")
                                _pendingStartId = _item.id
                            }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent; anchors.margins: Theme.spacing.item; spacing: Theme.spacing.item

                        Rectangle {
                            Layout.preferredWidth: Theme.sizes.coverMedium
                            Layout.preferredHeight: Theme.sizes.coverMedium
                            radius: Theme.radius.cover; clip: true
                            color: Theme.colors.bgPlaceholder
                            Image {
                                anchors.fill: parent; source: _item.cover || ""
                                fillMode: Image.PreserveAspectCrop
                            }
                            Label {
                                anchors.centerIn: parent
                                text: _item.type === 12 ? "♪" : "▶"
                                color: Theme.colors.textDim; font.pixelSize: 24
                                visible: parent.children[0].status !== Image.Ready
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
                            spacing: Theme.spacing.tight
                            Label {
                                text: _item.title || qsTr("未知标题")
                                color: Theme.colors.textSecondary; font.pixelSize: Theme.fontSizes.body
                                font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true
                            }
                            Label {
                                text: (_item.upper && _item.upper.name) || ""
                                color: Theme.colors.textTertiary; font.pixelSize: Theme.fontSizes.small
                                visible: text.length > 0
                            }
                            Label {
                                text: {
                                    var dur = _item.duration || 0; var m = Math.floor(dur / 60); var s = dur % 60
                                    return (_item.type === 12 ? qsTr("音频") : qsTr("视频"))
                                           + " · " + m + ":" + (s < 10 ? "0" : "") + s
                                }
                                color: Theme.colors.textDim; font.pixelSize: Theme.fontSizes.small
                            }
                        }
                    }
                }
            }

            Label {
                text: _playError
                color: Theme.colors.error; font.pixelSize: Theme.fontSizes.caption
                visible: text.length > 0
            }

            Label {
                visible: viewState === "resources" && resourceModel.length === 0 && !_loading
                text: qsTr("该收藏夹暂无内容")
                color: Theme.colors.textDim; font.pixelSize: Theme.fontSizes.caption
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }
}
