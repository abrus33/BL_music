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
    // "folders": 显示收藏夹列表
    // "resources": 显示某个收藏夹的内容列表
    property string viewState: "folders"
    property string currentFolderTitle: ""
    property int currentMediaId: 0

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

            // ---- 页面标题 + 返回按钮 ----
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // 返回按钮（资源列表视图时显示）
                Button {
                    text: qsTr("< 返回")
                    visible: viewState === "resources"
                    flat: true
                    onClicked: {
                        viewState = "folders"
                        currentFolderTitle = ""
                    }
                    background: Rectangle {
                        radius: 8
                        color: "#3a3a3a"
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

                // 页面标题
                Label {
                    text: viewState === "folders"
                          ? qsTr("收藏夹")
                          : currentFolderTitle || qsTr("收藏夹内容")
                    color: "#ffffff"
                    font.pixelSize: 28
                    font.bold: true
                    Layout.fillWidth: true
                }
            }

            // ---- 登录状态提示 ----
            Label {
                text: applicationContext.authService.isLoggedIn
                      ? qsTr("已登录，点击收藏夹查看内容")
                      : qsTr("请先在「登录」页面导入 Cookie 以同步收藏夹")
                color: applicationContext.authService.isLoggedIn ? "#bcbcbc" : "#7d7d7d"
                wrapMode: Text.Wrap
                Layout.fillWidth: true
                font.pixelSize: 14
                visible: viewState === "folders"
            }

            // ---- 加载收藏夹按钮（文件夹列表为空时显示） ----
            Button {
                text: qsTr("加载收藏夹列表")
                enabled: applicationContext.authService.isLoggedIn
                visible: folderRepeater.count === 0 && viewState === "folders"

                background: Rectangle {
                    radius: 8
                    color: parent.enabled ? "#fb7299" : "#3a3a3a"
                }
                contentItem: Label {
                    text: parent.text
                    color: "#ffffff"
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                implicitWidth: 200
                implicitHeight: 44

                onClicked: {
                    loadingLabel.visible = true
                    folderRepeater.model = []
                    applicationContext.favoriteService.loadFavoriteFolders(
                        applicationContext.authService.userMid
                    )
                }
            }

            // ---- 加载中提示 ----
            Label {
                id: loadingLabel
                text: qsTr("加载中...")
                color: "#9d9d9d"
                font.pixelSize: 13
                visible: false
            }

            // ============ 收藏夹列表视图 ============
            Repeater {
                id: folderRepeater
                model: []  // 由 C++ onFavoriteFoldersLoaded 动态填充
                visible: viewState === "folders"

                delegate: Rectangle {
                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: 80
                    radius: 12
                    color: "#262626"

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            // 切换到资源列表视图
                            viewState = "resources"
                            currentFolderTitle = modelData.title || qsTr("收藏夹")
                            currentMediaId = modelData.id || 0
                            // 加载该收藏夹的内容
                            loadingLabel.visible = true
                            resourceRepeater.model = []
                            applicationContext.favoriteService.loadFavoriteResources(
                                currentMediaId, 1, 20
                            )
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Label {
                                text: modelData.title || qsTr("未知收藏夹")
                                color: "#f4f4f4"
                                font.pixelSize: 17
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Label {
                                text: qsTr("%1 个内容").arg(modelData.media_count || 0)
                                color: "#a8a8a8"
                                font.pixelSize: 13
                            }
                        }
                    }
                }
            }

            // ============ 资源列表视图 ============
            Repeater {
                id: resourceRepeater
                model: []  // 由 C++ onFavoriteResourcesLoaded 动态填充
                visible: viewState === "resources"

                delegate: Rectangle {
                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: 100
                    radius: 12
                    color: "#262626"

                    // 点击播放
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            // 检查资源是否有效（attr=0 有效，attr=1 已失效）
                            if (modelData.attr !== undefined && modelData.attr !== 0) {
                                playError.text = qsTr("该资源已失效")
                                return
                            }

                            // 1. 设置播放器显示信息
                            applicationContext.playerController.mediaTitle =
                                modelData.title || qsTr("未知标题")
                            applicationContext.playerController.mediaCover =
                                modelData.cover || ""

                            // 2. 解析媒体并播放
                            var mediaType = modelData.type || 2
                            if (mediaType === 12) {
                                // 音频：直接用 id
                                applicationContext.mediaResolver.resolve(modelData.id, 12)
                            } else if (mediaType === 2) {
                                // 视频：需要 bvid
                                var bvid = modelData.bvid || modelData.bv_id || ""
                                applicationContext.mediaResolver.resolve(modelData.id, 2, bvid, 0)
                            }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        // 封面缩略图（使用带圆角裁切的 Rectangle + Image）
                        Rectangle {
                            Layout.preferredWidth: 76
                            Layout.preferredHeight: 76
                            radius: 8
                            clip: true
                            color: "#3a3a3a"

                            Image {
                                anchors.fill: parent
                                source: modelData.cover || ""
                                fillMode: Image.PreserveAspectCrop
                            }

                            // 占位图标（图片未加载时显示）
                            Label {
                                anchors.centerIn: parent
                                text: modelData.type === 12 ? "♪" : "▶"
                                color: "#7d7d7d"
                                font.pixelSize: 24
                                visible: parent.children[0].status !== Image.Ready
                            }
                        }

                        // 内容信息
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 4

                            Label {
                                text: modelData.title || qsTr("未知标题")
                                color: "#f4f4f4"
                                font.pixelSize: 15
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            // UP 主
                            Label {
                                text: {
                                    var upper = modelData.upper
                                    return upper ? (upper.name || "") : ""
                                }
                                color: "#a8a8a8"
                                font.pixelSize: 12
                                visible: text.length > 0
                            }

                            // 类型 + 时长
                            Label {
                                text: {
                                    var typeStr = modelData.type === 12 ? qsTr("音频") : qsTr("视频")
                                    var dur = modelData.duration || 0
                                    var min = Math.floor(dur / 60)
                                    var sec = dur % 60
                                    return typeStr + " · " + min + ":" +
                                           (sec < 10 ? "0" : "") + sec
                                }
                                color: "#7d7d7d"
                                font.pixelSize: 12
                            }
                        }
                    }
                }
            }

            // ---- 加载更多按钮 ----
            Button {
                text: qsTr("加载更多")
                visible: viewState === "resources" && hasMoreResources
                onClicked: {
                    // TODO: 分页加载（当前仅加载第一页）
                }
                flat: true
                Label {
                    anchors.centerIn: parent
                    text: parent.text
                    color: "#9d9d9d"
                }
            }

            // ---- 播放错误提示 ----
            Label {
                id: playError
                text: qsTr("")
                color: "#fb7299"
                font.pixelSize: 13
                visible: text.length > 0
            }
        }
    }

    // ---- 是否有更多资源（控制"加载更多"按钮） ----
    property bool hasMoreResources: false

    // ---- 监听 C++ 信号 ----
    Connections {
        target: applicationContext.favoriteService

        // 收藏夹列表加载完成
        onFavoriteFoldersLoaded: function(success, foldersJson, error) {
            loadingLabel.visible = false
            if (success && foldersJson.length > 0) {
                folderRepeater.model = JSON.parse(foldersJson)
            } else {
                console.log("加载收藏夹失败:", error)
            }
        }

        // 收藏夹内容加载完成
        onFavoriteResourcesLoaded: function(success, infoJson, mediasJson, hasMore, error) {
            loadingLabel.visible = false
            if (success && mediasJson.length > 0) {
                resourceRepeater.model = JSON.parse(mediasJson)
                hasMoreResources = hasMore
            } else {
                console.log("加载收藏内容失败:", error)
            }
        }
    }

    // ---- 监听媒体解析结果 ----
    Connections {
        target: applicationContext.mediaResolver
        onMediaResolved: function(success, url, title, cover, duration, error) {
            if (success && url.length > 0) {
                // 设置播放源并开始播放
                applicationContext.playerController.source = url
                applicationContext.playerController.play()
            } else {
                playError.text = qsTr("播放失败: ") + error
            }
        }
    }
}
