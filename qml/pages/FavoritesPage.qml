// ============================================================================
// FavoritesPage.qml - 收藏夹页面
// 功能：显示收藏夹列表 → 点击文件夹显示资源列表 → 点击资源播放
// 与 C++ 的交互：
//   - authService:      登录态 + userMid
//   - favoriteService:  加载文件夹列表 + 资源列表
//   - mediaResolver:    解析播放 URL
//   - playerController: 控制播放
// ============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ScrollView {
    clip: true

    // ---- 页面状态 ----
    property string viewState: "folders"
    property string currentFolderTitle: ""
    property int currentMediaId: 0

    // ---- 数据模型 ----
    property var folderModel: []
    property var resourceModel: []
    property bool hasMoreResources: false

    // ---- 加载状态 ----
    property bool _loading: false
    property string _playError: ""

    // ---- 初始化：连接 C++ 信号 ----
    Component.onCompleted: Qt.callLater(function() {
        console.log("[FavPage] onCompleted, applicationContext=", !!applicationContext)

        var svc = applicationContext ? applicationContext.favoriteService : null
        console.log("[FavPage] favoriteService=", !!svc)
        if (!svc) return

        svc.favoriteFoldersLoaded.connect(function(success, foldersJson, error) {
            console.log("[FavPage] 文件夹加载完成, success=", success,
                        "len=", foldersJson ? foldersJson.length : 0,
                        "error=", error)
            _loading = false
            if (success && foldersJson && foldersJson.length > 0) {
                try { folderModel = JSON.parse(foldersJson); }
                catch(e) { console.log("[FavPage] JSON解析失败:", e); }
            } else {
                console.log("[FavPage] 加载收藏夹失败:", error);
            }
        })

        svc.favoriteResourcesLoaded.connect(function(success, infoJson, mediasJson, hasMore, error) {
            console.log("[FavPage] 资源加载完成, success=", success,
                        "len=", mediasJson ? mediasJson.length : 0,
                        "hasMore=", hasMore, "error=", error)
            _loading = false
            if (success && mediasJson && mediasJson.length > 0) {
                try { resourceModel = JSON.parse(mediasJson); }
                catch(e) { console.log("[FavPage] JSON解析失败:", e); }
                hasMoreResources = hasMore
            } else {
                resourceModel = []
                console.log("[FavPage] 加载收藏内容失败:", error);
            }
        })

        var res = applicationContext.mediaResolver
        console.log("[FavPage] mediaResolver=", !!res)
        if (res) {
            res.mediaResolved.connect(function(success, url, t, c, d, error) {
                console.log("[FavPage] mediaResolved signal! success=", success,
                            "url.length=", url ? url.length : 0, "error=", error)
                if (success && url && url.length > 0) {
                    console.log("[FavPage] 设置播放源:", url.substring(0, 60) + "...")
                    applicationContext.playerController.source = url
                } else {
                    _playError = qsTr("播放失败: ") + error
                }
            })
        }
    })

    Rectangle {
        implicitWidth: 900
        implicitHeight: contentColumn.implicitHeight + 48
        color: "#202020"

        ColumnLayout {
            id: contentColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 24
            spacing: 20

            // ---- 标题行 ----
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Button {
                    text: qsTr("< 返回")
                    visible: viewState === "resources"
                    flat: true
                    onClicked: { viewState = "folders"; currentFolderTitle = "" }
                    background: Rectangle {
                        color: "#3a3a3a"; radius: 8
                        implicitWidth: 80; implicitHeight: 36
                    }
                    contentItem: Text {
                        text: parent.text; color: "#ffffff"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Label {
                    text: viewState === "folders" ? qsTr("收藏夹")
                          : currentFolderTitle || qsTr("收藏夹内容")
                    color: "#ffffff"; font.pixelSize: 28; font.bold: true
                    Layout.fillWidth: true
                }
            }

            // ---- 提示 ----
            Label {
                visible: viewState === "folders"
                text: (applicationContext && applicationContext.authService
                       && applicationContext.authService.isLoggedIn)
                      ? qsTr("已登录，点击收藏夹查看内容")
                      : qsTr("请先在「登录」页面导入 Cookie")
                color: (applicationContext && applicationContext.authService
                        && applicationContext.authService.isLoggedIn)
                       ? "#bcbcbc" : "#7d7d7d"
                wrapMode: Text.Wrap; Layout.fillWidth: true
                font.pixelSize: 14
            }

            // ---- 加载按钮 ----
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
                    color: parent.enabled ? "#fb7299" : "#3a3a3a"; radius: 8
                    implicitWidth: 200; implicitHeight: 44
                }
                contentItem: Text {
                    text: parent.text; color: "#ffffff"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 14
                }
            }

            // ---- 加载中 ----
            Label {
                id: loadingLabel
                visible: _loading
                text: qsTr("加载中...")
                color: "#9d9d9d"; font.pixelSize: 13
            }

            // ============ 收藏夹列表 ============
            Repeater {
                id: folderRepeater
                model: folderModel
                visible: viewState === "folders"

                // 通过 parentRepeater.model[index] 访问模型数据
                // 这是 Qt 6 中最可靠的模型数据访问方式
                delegate: Rectangle {
                    readonly property var _item: folderRepeater.model[index] || {}

                    Layout.fillWidth: true
                    implicitHeight: 80; radius: 12; color: "#262626"

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var mid = _item.id || 0
                            viewState = "resources"
                            currentFolderTitle = _item.title || qsTr("收藏夹")
                            currentMediaId = mid
                            _loading = true
                            resourceModel = []
                            applicationContext.favoriteService.loadFavoriteResources(mid, 1, 20)
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16; spacing: 4

                        Label {
                            text: _item.title || qsTr("未知收藏夹")
                            color: "#f4f4f4"; font.pixelSize: 17; font.bold: true
                            elide: Text.ElideRight
                        }
                        Label {
                            text: qsTr("%1 个内容").arg(_item.media_count || 0)
                            color: "#a8a8a8"; font.pixelSize: 13
                        }
                    }
                }
            }

            // ============ 资源列表 ============
            Repeater {
                id: resRepeater
                model: resourceModel
                visible: viewState === "resources"

                delegate: Rectangle {
                    readonly property var _item: resRepeater.model[index] || {}

                    Layout.fillWidth: true
                    implicitHeight: 100; radius: 12; color: "#262626"

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (_item.attr !== undefined && _item.attr !== 0) {
                                _playError = qsTr("该资源已失效"); return
                            }
                            applicationContext.playerController.mediaTitle =
                                _item.title || qsTr("未知标题")
                            applicationContext.playerController.mediaCover =
                                _item.cover || ""
                            if (_item.type === 12) {
                                applicationContext.mediaResolver.resolve(_item.id, 12)
                            } else {
                                var bv = _item.bvid || _item.bv_id || ""
                                applicationContext.mediaResolver.resolve(_item.id, 2, bv, 0)
                            }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12; spacing: 12

                        // 封面
                        Rectangle {
                            Layout.preferredWidth: 76; Layout.preferredHeight: 76
                            radius: 8; clip: true; color: "#3a3a3a"

                            Image {
                                anchors.fill: parent
                                source: _item.cover || ""
                                fillMode: Image.PreserveAspectCrop
                            }
                            Label {
                                anchors.centerIn: parent
                                text: _item.type === 12 ? "♪" : "▶"
                                color: "#7d7d7d"; font.pixelSize: 24
                                visible: parent.children[0].status !== Image.Ready
                            }
                        }

                        // 信息
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 4

                            Label {
                                text: _item.title || qsTr("未知标题")
                                color: "#f4f4f4"; font.pixelSize: 15; font.bold: true
                                elide: Text.ElideRight; Layout.fillWidth: true
                            }
                            Label {
                                text: (_item.upper && _item.upper.name) || ""
                                color: "#a8a8a8"; font.pixelSize: 12
                                visible: text.length > 0
                            }
                            Label {
                                text: {
                                    var dur = _item.duration || 0
                                    var m = Math.floor(dur / 60)
                                    var s = dur % 60
                                    return (_item.type === 12 ? qsTr("音频") : qsTr("视频"))
                                           + " · " + m + ":" + (s < 10 ? "0" : "") + s
                                }
                                color: "#7d7d7d"; font.pixelSize: 12
                            }
                        }
                    }
                }
            }

            // ---- 播放错误 ----
            Label {
                text: _playError
                color: "#fb7299"; font.pixelSize: 13
                visible: text.length > 0
            }

            // ---- 空列表 ----
            Label {
                visible: viewState === "resources" && resourceModel.length === 0 && !_loading
                text: qsTr("该收藏夹暂无内容")
                color: "#7d7d7d"; font.pixelSize: 13
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }
}
