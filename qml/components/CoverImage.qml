// ============================================================================
// CoverImage.qml - 封面图片组件（带占位图标）
//
// 新人阅读重点：
// 1. 父组件只需要传 coverUrl，不需要关心图片加载失败时怎么显示。
// 2. Image.Ready 前显示占位符，这样网络图片慢加载时界面不会空白。
// ============================================================================

import QtQuick
import QtQuick.Controls
import "Theme.js" as Theme

Rectangle {
    id: cover

    // ---- 属性 ----
    property string coverUrl: ""
    property string placeholderIcon: ""
    property int placeholderSize: 24
    property url placeholderSource: "qrc:/qt/qml/cursor_music/icon/music-2.svg"

    radius: Theme.radius.control
    clip: true
    color: Theme.colors.surfaceRaised

    Image {
        id: coverImg
        anchors.fill: parent
        source: cover.coverUrl
        sourceSize.width: Math.max(1, cover.width)
        sourceSize.height: Math.max(1, cover.height)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    AppIcon {
        anchors.centerIn: parent
        source: cover.placeholderSource
        iconColor: Theme.colors.textDisabled
        iconSize: cover.placeholderSize
        visible: coverImg.status !== Image.Ready && cover.placeholderIcon.length === 0
    }

    Label {
        anchors.centerIn: parent
        text: cover.placeholderIcon
        color: Theme.colors.textDisabled
        font.pixelSize: cover.placeholderSize
        visible: coverImg.status !== Image.Ready && text.length > 0
    }
}
