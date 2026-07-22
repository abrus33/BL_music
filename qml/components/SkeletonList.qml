import QtQuick
import QtQuick.Layouts
import "Theme.js" as Theme

Item {
    id: root

    property int count: 5
    readonly property int effectiveCount: Math.min(Math.max(count, 0), 12)

    implicitWidth: 320
    implicitHeight: Math.max(0, effectiveCount * 64
                             + Math.max(0, effectiveCount - 1) * Theme.spacing.xs)

    Accessible.ignored: true

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacing.xs

        Repeater {
            model: root.effectiveCount

            delegate: Rectangle {
                required property int index

                Layout.fillWidth: true
                Layout.preferredHeight: 64
                color: index % 2 === 0 ? Theme.colors.surfaceRaised : Theme.colors.surface
                radius: Theme.radius.control
            }
        }
    }
}
