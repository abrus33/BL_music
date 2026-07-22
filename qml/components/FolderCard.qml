import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "Theme.js" as Theme

Button {
    id: root

    property var folderId
    property string title: ""
    property int itemCount: 0

    signal opened(var folderId)

    implicitWidth: 220
    implicitHeight: 88
    padding: Theme.spacing.lg
    hoverEnabled: true

    Accessible.role: Accessible.Button
    Accessible.name: title
    Accessible.description: qsTr("%1 items").arg(itemCount)

    contentItem: RowLayout {
        spacing: Theme.spacing.md

        AppIcon {
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            source: "qrc:/qt/qml/cursor_music/icon/folder-heart.svg"
            iconSize: 24
            iconColor: root.enabled ? Theme.colors.accent : Theme.colors.textDisabled
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.xs

            Label {
                Layout.fillWidth: true
                text: root.title
                color: root.enabled ? Theme.colors.textPrimary : Theme.colors.textDisabled
                font.pixelSize: Theme.fontSizes.h3
                font.bold: true
                elide: Text.ElideRight
            }

            Label {
                Layout.fillWidth: true
                text: qsTr("%1 items").arg(root.itemCount)
                color: root.enabled ? Theme.colors.textTertiary : Theme.colors.textDisabled
                font.pixelSize: Theme.fontSizes.caption
                elide: Text.ElideRight
            }
        }

        AppIcon {
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            source: "qrc:/qt/qml/cursor_music/icon/chevron-right.svg"
            iconColor: root.enabled ? Theme.colors.textSecondary : Theme.colors.textDisabled
        }
    }

    background: Rectangle {
        color: !root.enabled ? Theme.colors.surface
                             : root.down ? Theme.colors.surfaceHover
                                         : root.hovered ? Theme.colors.surfaceRaised
                                                        : Theme.colors.surface
        radius: Theme.radius.card
        border.width: root.activeFocus ? 1 : 0
        border.color: Theme.colors.borderFocus
    }

    onClicked: root.opened(root.folderId)
}
