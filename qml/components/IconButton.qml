import QtQuick
import QtQuick.Controls.Basic
import "Theme.js" as Theme

Button {
    id: root

    property url iconSource
    property string accessibleName: ""

    signal triggered()

    implicitWidth: Math.max(40, implicitContentWidth)
    implicitHeight: Math.max(40, implicitContentHeight)
    hoverEnabled: true

    icon.source: iconSource
    icon.width: 20
    icon.height: 20
    icon.color: !enabled ? Theme.colors.textDisabled
                         : down ? Theme.colors.textPrimary
                                : Theme.colors.textSecondary

    background: Rectangle {
        color: !root.enabled ? "transparent"
                             : root.down ? Theme.colors.surfaceRaised
                                         : root.hovered ? Theme.colors.surfaceHover
                                                        : "transparent"
        radius: Theme.radius.control
        border.width: root.activeFocus ? 1 : 0
        border.color: Theme.colors.borderFocus
    }

    Accessible.role: Accessible.Button
    Accessible.name: accessibleName
    Accessible.description: ToolTip.text

    onClicked: root.triggered()
}
