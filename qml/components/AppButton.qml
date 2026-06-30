// ============================================================================
// AppButton.qml - 统一样式按钮（消除内联 Button 样板代码）
//
// 新人阅读重点：
// 1. 这是对 Qt Quick Controls Button 的二次封装。
// 2. 父组件仍然使用 Button 自带的 text/enabled/onClicked。
// 3. 这里额外提供颜色、尺寸、圆角等视觉属性，避免每个页面重复写 background。
// ============================================================================

import QtQuick
import QtQuick.Controls
import "Theme.js" as Theme

Button {
    id: control

    // ---- 可定制属性 ----
    // 这些属性不是 Button 原生属性，是本项目为了统一样式额外加的。
    property color bgColor: Theme.colors.accent
    property color textColor: Theme.colors.textPrimary
    property int btnWidth: 180
    property int btnHeight: Theme.sizes.btnHeight
    property int fontSize: Theme.fontSizes.bodySmall
    property int btnRadius: Theme.radius.button
    property bool flatButton: false

    background: Rectangle {
        // flatButton 用于播放栏图标按钮：保留点击区域，但不画实心背景。
        color: control.flatButton ? "transparent"
             : control.enabled ? control.bgColor : Theme.colors.borderInput
        radius: control.btnRadius
        implicitWidth: control.btnWidth
        implicitHeight: control.btnHeight
    }

    contentItem: Text {
        text: control.text
        color: control.enabled ? control.textColor : Theme.colors.textDim
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font.pixelSize: control.fontSize
        elide: Text.ElideRight
    }
}
