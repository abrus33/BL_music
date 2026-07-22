import QtQuick
import QtQuick.Controls.Basic

Button {
    id: root

    property url source
    property color iconColor: "white"
    property int iconSize: 20

    enabled: false
    focusPolicy: Qt.NoFocus
    hoverEnabled: false
    display: AbstractButton.IconOnly
    padding: 0
    width: iconSize
    height: iconSize

    icon.source: source
    icon.color: iconColor
    icon.width: iconSize
    icon.height: iconSize

    background: null
    Accessible.ignored: true
}
