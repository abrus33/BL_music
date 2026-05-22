// ============================================================================
// AppButton.qml - 统一样式按钮（消除内联 Button 样板代码）
// ============================================================================

import QtQuick
import QtQuick.Controls
import "Theme.js" as Theme

Button {
    id: control

    // ---- 可定制属性 ----
    property color bgColor: Theme.colors.accent
    property color textColor: Theme.colors.textPrimary
    property int btnWidth: 180
    property int btnHeight: Theme.sizes.btnHeight
    property int fontSize: Theme.fontSizes.bodySmall
    property int btnRadius: Theme.radius.button
    property bool flatButton: false

    background: Rectangle {
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
