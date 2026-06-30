// ============================================================================
// MediaCard.qml - 通用媒体卡片（封面+标题+时长+悬停效果）
// layoutMode: "grid" (纵向, HomePage) | "list" (横向, FavoritesPage)
//
// 新人阅读重点：
// 1. 这是纯 UI 组件，不知道 B站 API，也不直接播放。
// 2. 父页面通过属性传入 cover/title/duration/type。
// 3. 用户点击后只发出 clicked() 信号，具体播放逻辑由父页面决定。
// ============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Theme.js" as Theme

Rectangle {
    id: card

    // ---- 信号 ----
    signal clicked()

    // ---- 属性接口 ----
    // 这些属性就是组件对外的“参数”。父页面创建 MediaCard 时给它们赋值。
    property string coverUrl: ""
    property string title: ""
    property string subtitle: ""
    property int duration: 0
    property int mediaType: 12   // 12=audio ♪, 2=video ▶
    property string layoutMode: "list"  // "grid" | "list"

    // ---- 样式 ----
    radius: Theme.radius.card
    color: hoverMouse.containsMouse ? Theme.colors.bgCardHover : Theme.colors.bgCard
    Behavior on color { ColorAnimation { duration: Theme.duration.fast } }

    // ---- 悬停+点击 ----
    MouseArea {
        id: hoverMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        // 向外发信号，而不是在组件内部写业务逻辑，这样组件可以复用。
        onClicked: card.clicked()
    }

    // ---- 横向布局 (list) ----
    RowLayout {
        visible: layoutMode === "list"
        anchors.fill: parent
        anchors.margins: Theme.spacing.item
        spacing: Theme.spacing.item

        CoverImage {
            Layout.preferredWidth: Theme.sizes.coverMedium
            Layout.preferredHeight: Theme.sizes.coverMedium
            coverUrl: card.coverUrl
            placeholderIcon: mediaType === 12 ? "♪" : "▶"
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: Theme.spacing.tight

            Label {
                text: card.title || qsTr("未知标题")
                color: Theme.colors.textSecondary
                font.pixelSize: Theme.fontSizes.body
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Label {
                text: card.subtitle
                color: Theme.colors.textTertiary
                font.pixelSize: Theme.fontSizes.small
                visible: text.length > 0
            }
            Label {
                text: {
                    var m = Math.floor(card.duration / 60), s = card.duration % 60
                    return (mediaType === 12 ? qsTr("音频") : qsTr("视频"))
                           + " · " + m + ":" + (s < 10 ? "0" : "") + s
                }
                color: Theme.colors.textDim
                font.pixelSize: Theme.fontSizes.small
            }
        }
    }

    // ---- 纵向布局 (grid) ----
    ColumnLayout {
        visible: layoutMode === "grid"
        anchors.fill: parent
        anchors.margins: Theme.spacing.item
        spacing: Theme.spacing.compact

        CoverImage {
            Layout.fillWidth: true
            Layout.preferredHeight: width * 0.6
            coverUrl: card.coverUrl
            placeholderIcon: "♪"
            placeholderSize: 32
        }

        Label {
            text: card.title || qsTr("未知歌曲")
            color: Theme.colors.textSecondary
            font.pixelSize: Theme.fontSizes.body
            font.bold: true
            elide: Text.ElideRight
            Layout.fillWidth: true
            maximumLineCount: 1
        }
        Label {
            text: card.subtitle
            color: Theme.colors.textTertiary
            font.pixelSize: Theme.fontSizes.caption
            visible: text.length > 0
        }
        Label {
            text: {
                var m = Math.floor(card.duration / 60), s = card.duration % 60
                return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
            }
            color: Theme.colors.textDim
            font.pixelSize: Theme.fontSizes.small
            font.family: "Consolas"
        }
    }
}
