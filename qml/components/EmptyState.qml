import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Theme.js" as Theme

Item {
    id: root

    property string title: qsTr("Nothing here yet")
    property string message: ""
    property url iconSource: "qrc:/qt/qml/cursor_music/icon/music-2.svg"

    implicitWidth: 240
    implicitHeight: 180

    Accessible.role: Accessible.StaticText
    Accessible.name: message.length > 0 ? qsTr("%1. %2").arg(title).arg(message) : title

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width, 360)
        spacing: Theme.spacing.md

        AppIcon {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            source: root.iconSource
            iconSize: 40
            iconColor: Theme.colors.textDisabled
        }

        Label {
            objectName: "emptyTitleLabel"
            Layout.fillWidth: true
            text: root.title
            color: Theme.colors.textPrimary
            font.pixelSize: Theme.fontSizes.h2
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            Accessible.ignored: true
        }

        Label {
            objectName: "emptyMessageLabel"
            Layout.fillWidth: true
            text: root.message
            color: Theme.colors.textTertiary
            font.pixelSize: Theme.fontSizes.bodySmall
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            visible: text.length > 0
            Accessible.ignored: true
        }
    }
}
