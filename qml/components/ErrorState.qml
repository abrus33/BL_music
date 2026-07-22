import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Theme.js" as Theme

Item {
    id: root

    property string message: ""

    signal retryRequested()

    implicitWidth: 280
    implicitHeight: 200

    Accessible.role: Accessible.AlertMessage
    Accessible.name: message

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width, 420)
        spacing: Theme.spacing.md

        AppIcon {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            source: "qrc:/qt/qml/cursor_music/icon/alert-circle.svg"
            iconSize: 40
            iconColor: Theme.colors.error
        }

        Label {
            objectName: "errorMessageLabel"
            Layout.fillWidth: true
            text: root.message
            color: Theme.colors.textSecondary
            font.pixelSize: Theme.fontSizes.body
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            Accessible.ignored: true
        }

        IconButton {
            id: retryButton
            objectName: "retryButton"
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            iconSource: "qrc:/qt/qml/cursor_music/icon/refresh-cw.svg"
            accessibleName: qsTr("Retry")
            onTriggered: root.retryRequested()
        }
    }
}
