// ============================================================================
// FavoritesPage.qml - 收藏夹页面
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
    property var _pendingStartId: 0
    property string _playError: ""

    // ---- 自动加载 ----
    onVisibleChanged: {
        if (!visible) return
        Qt.callLater(tryAutoLoadFolders)
    }

    Connections {
        target: applicationContext ? applicationContext.authService : null
        enabled: target !== null
        function onLoginStateChanged() {
            var auth = applicationContext.authService
            if (auth && !auth.isLoggedIn) {
                folderModel = []; resourceModel = []
            }
            if (visible) Qt.callLater(tryAutoLoadFolders)
        }
    }

    function tryAutoLoadFolders() {
        if (folderModel.length > 0 || _loading) return
        var auth = applicationContext ? applicationContext.authService : null
        if (auth && auth.isLoggedIn) {
            _loading = true
            applicationContext.favoriteService.loadFavoriteFolders(auth.userMid)
        }
    }

    Component.onCompleted: Qt.callLater(function() {
        var svc = applicationContext ? applicationContext.favoriteService : null
        if (!svc) return

        svc.favoriteFoldersLoaded.connect(function(success, f, error) {
            _loading = false
            if (success && f && f.length > 0) { try { folderModel = JSON.parse(f); } catch(e) {} }
        })

        svc.favoriteResourcesLoaded.connect(function(success, info, medias, hasMore, error) {
            _loading = false
            if (success && medias && medias.length > 0) {
                try { resourceModel = JSON.parse(medias); } catch(e) {}
                hasMoreResources = hasMore
            } else { resourceModel = []; }
        })

        svc.allFavoriteResourcesLoaded.connect(function(success, mediasJson, error) {
            _loading = false
            if (!success || !mediasJson || mediasJson.length === 0) {
                if (error.length > 0) _playError = qsTr("加载失败: ") + error
                else resourceModel = []
                return
            }
            try { resourceModel = JSON.parse(mediasJson); } catch(e) {}
            hasMoreResources = false

            var ps = applicationContext ? applicationContext.playlistService : null
            if (ps && _pendingStartId > 0) {
                ps.createPlaylist(mediasJson, _pendingStartId)
                _pendingStartId = 0
            }
        })

        var res = applicationContext ? applicationContext.mediaResolver : null
        if (res) {
            res.mediaResolved.connect(function(success, url, t, c, d, error) {
                if (!success || error.length > 0) _playError = qsTr("播放失败: ") + error
            })
        }
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

            // ---- 标题栏 ----
            RowLayout {
                Layout.fillWidth: true; spacing: Theme.spacing.item

                AppButton {
                    text: qsTr("< 返回")
                    visible: viewState === "resources"
                    bgColor: Theme.colors.borderInput
                    btnWidth: 80; btnHeight: 36
                    btnRadius: Theme.radius.card
                    onClicked: { viewState = "folders"; currentFolderTitle = "" }
                }
                Label {
                    text: viewState === "folders" ? qsTr("收藏夹") : currentFolderTitle || qsTr("收藏夹内容")
                    color: Theme.colors.textPrimary
                    font.pixelSize: Theme.fontSizes.h1; font.bold: true
                    Layout.fillWidth: true
                }
            }

            // ---- 登录状态提示 ----
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

            // ---- 加载按钮 ----
            AppButton {
                text: qsTr("加载收藏夹列表")
                enabled: applicationContext && applicationContext.authService
                         && applicationContext.authService.isLoggedIn
                visible: folderModel.length === 0 && viewState === "folders"
                onClicked: {
                    _loading = true
                    applicationContext.favoriteService.loadFavoriteFolders(
                        applicationContext.authService.userMid)
                }
            }

            // ---- 加载提示 ----
            Label {
                visible: _loading
                text: qsTr("加载中...")
                color: Theme.colors.textMuted; font.pixelSize: Theme.fontSizes.caption
            }

            // ---- 收藏夹列表 ----
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
                            viewState = "resources"
                            currentFolderTitle = _item.title || qsTr("收藏夹"); currentMediaId = mid
                            _loading = true; resourceModel = []; _playError = ""
                            applicationContext.favoriteService.loadAllFavoriteResources(mid)
                        }
                    }
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spacing.section
                        spacing: Theme.spacing.tight

                        Label {
                            text: _item.title || qsTr("未知收藏夹")
                            color: Theme.colors.textSecondary
                            font.pixelSize: Theme.fontSizes.h3; font.bold: true
                            elide: Text.ElideRight
                        }
                        Label {
                            text: qsTr("%1 个内容").arg(_item.media_count || 0)
                            color: Theme.colors.textTertiary
                            font.pixelSize: Theme.fontSizes.caption
                        }
                    }
                }
            }

            // ---- 资源列表 ----
            Repeater {
                id: resRepeater; model: resourceModel; visible: viewState === "resources"
                delegate: MediaCard {
                    readonly property var _item: resRepeater.model[index] || {}
                    Layout.fillWidth: true
                    implicitHeight: 100
                    layoutMode: "list"
                    coverUrl: _item.cover || ""
                    title: _item.title || qsTr("未知标题")
                    subtitle: (_item.upper && _item.upper.name) || ""
                    duration: _item.duration || 0
                    mediaType: _item.type || 12

                    onClicked: {
                        if (_item.attr !== undefined && _item.attr !== 0) {
                            _playError = qsTr("该资源已失效"); return
                        }
                        var ps = applicationContext ? applicationContext.playlistService : null
                        if (ps && resourceModel.length > 0) {
                            ps.createPlaylist(JSON.stringify(resourceModel), _item.id)
                        } else {
                            _pendingStartId = _item.id
                        }
                    }
                }
            }

            // ---- 错误/空状态 ----
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
