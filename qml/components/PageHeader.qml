import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Theme.js" as Theme

Item {
    id: root

    property string title: ""
    property string subtitle: ""
    property bool showBack: false

    signal backRequested()

    implicitHeight: Math.max(40, titleBlock.implicitHeight)

    RowLayout {
        anchors.fill: parent
        spacing: Theme.spacing.md

        IconButton {
            id: backButton
            objectName: "backButton"
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            visible: root.showBack
            iconSource: "qrc:/qt/qml/cursor_music/icon/chevron-left.svg"
            accessibleName: qsTr("Back")
            onTriggered: root.backRequested()
        }

        Column {
            id: titleBlock
            objectName: "titleBlock"
            Layout.fillWidth: true
            spacing: Theme.spacing.xs

            Label {
                width: parent.width
                text: root.title
                color: Theme.colors.textPrimary
                font.pixelSize: Theme.fontSizes.h1
                font.bold: true
                elide: Text.ElideRight
            }

            Label {
                width: parent.width
                text: root.subtitle
                color: Theme.colors.textTertiary
                font.pixelSize: Theme.fontSizes.bodySmall
                elide: Text.ElideRight
                visible: text.length > 0
            }
        }
    }
}
