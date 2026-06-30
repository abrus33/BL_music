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
    property string placeholderIcon: "♪"
    property int placeholderSize: 24

    radius: Theme.radius.cover
    clip: true
    color: Theme.colors.bgPlaceholder

    Image {
        id: coverImg
        anchors.fill: parent
        source: cover.coverUrl
        fillMode: Image.PreserveAspectCrop
    }

    Label {
        anchors.centerIn: parent
        text: cover.placeholderIcon
        color: Theme.colors.textDim
        font.pixelSize: cover.placeholderSize
        // 图片没准备好时显示图标；Ready 后由真实封面覆盖。
        visible: coverImg.status !== Image.Ready
    }
}
