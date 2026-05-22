// ============================================================================
// CoverImage.qml - 封面图片组件（带占位图标）
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
        visible: coverImg.status !== Image.Ready
    }
}
