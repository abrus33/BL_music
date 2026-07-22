// ============================================================================
// AppButton.qml - 统一样式按钮（消除内联 Button 样板代码）
//
// 新人阅读重点：
// 1. 这是对 Qt Quick Controls Button 的二次封装。
// 2. 父组件仍然使用 Button 自带的 text/enabled/onClicked。
// 3. 这里额外提供颜色、尺寸、圆角等视觉属性，避免每个页面重复写 background。
// ============================================================================

import QtQuick
import QtQuick.Controls.Basic
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
    property int btnRadius: Theme.radius.control
    property bool flatButton: false
    property color hoverColor: flatButton ? Theme.colors.surfaceHover : Theme.colors.accentHover
    property color pressedColor: flatButton ? Theme.colors.surfaceRaised : Theme.colors.accentPressed
    property color checkedColor: flatButton ? Theme.colors.surfaceRaised : Theme.colors.accentChecked

    function colorForState(isEnabled, isDown, isChecked, isHovered) {
        return !isEnabled ? Theme.colors.controlDisabled
             : isDown ? pressedColor
             : isChecked ? checkedColor
             : isHovered ? hoverColor
             : flatButton ? Theme.colors.transparent : bgColor
    }

    background: Rectangle {
        objectName: "appButtonBackground"
        color: control.colorForState(control.enabled, control.down,
                                     control.checked, control.hovered)
        radius: control.btnRadius
        implicitWidth: control.btnWidth
        implicitHeight: control.btnHeight
        border.width: control.activeFocus ? 2 : 0
        border.color: Theme.colors.borderFocus
    }

    contentItem: Text {
        text: control.text
        color: control.enabled ? control.textColor : Theme.colors.textDisabled
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font.pixelSize: control.fontSize
        font.bold: control.checked
        elide: Text.ElideRight
    }
}
