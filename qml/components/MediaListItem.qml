import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "Theme.js" as Theme

Button {
    id: root

    property var mediaId
    property string title: ""
    property string coverUrl: ""
    property string uploader: ""
    property string resourceTypeLabel: ""
    property string duration: ""
    property bool invalid: false
    property bool current: false

    signal activated(var mediaId)

    implicitWidth: 320
    implicitHeight: Theme.sizes.mediaRowHeight
    padding: Theme.spacing.md
    hoverEnabled: true
    enabled: !invalid

    Accessible.role: Accessible.Button
    Accessible.name: title
    Accessible.description: invalid ? qsTr("Unavailable")
                                    : [uploader, resourceTypeLabel].filter(Boolean).join(", ")

    contentItem: RowLayout {
        spacing: Theme.spacing.md

        CoverImage {
            objectName: "mediaCover"
            Layout.preferredWidth: Theme.sizes.coverMedium
            Layout.preferredHeight: Theme.sizes.coverMedium
            coverUrl: root.coverUrl
        }

        AppIcon {
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            source: root.current ? "qrc:/qt/qml/cursor_music/icon/pause.svg"
                                 : "qrc:/qt/qml/cursor_music/icon/play.svg"
            iconColor: root.invalid ? Theme.colors.textDisabled
                                    : root.current ? Theme.colors.accent
                                                   : Theme.colors.textSecondary
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.xs

            Label {
                Layout.fillWidth: true
                text: root.title
                color: root.invalid ? Theme.colors.textDisabled
                                    : root.current ? Theme.colors.accent
                                                   : Theme.colors.textPrimary
                font.pixelSize: Theme.fontSizes.body
                elide: Text.ElideRight
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing.sm

                Label {
                    objectName: "mediaUploaderLabel"
                    Layout.fillWidth: true
                    text: root.uploader
                    color: root.invalid ? Theme.colors.textDisabled : Theme.colors.textTertiary
                    font.pixelSize: Theme.fontSizes.caption
                    elide: Text.ElideRight
                    visible: text.length > 0
                }

                Label {
                    objectName: "mediaTypeLabel"
                    text: root.invalid ? qsTr("Unavailable") : root.resourceTypeLabel
                    color: root.invalid ? Theme.colors.error : Theme.colors.textTertiary
                    font.pixelSize: Theme.fontSizes.caption
                    visible: text.length > 0
                }
            }
        }

        Label {
            objectName: "mediaDurationLabel"
            text: root.duration
            color: root.invalid ? Theme.colors.textDisabled : Theme.colors.textTertiary
            font.pixelSize: Theme.fontSizes.caption
            font.family: "monospace"
        }
    }

    background: Rectangle {
        objectName: "mediaBackground"
        color: root.invalid ? Theme.colors.transparent
                            : root.down ? Theme.colors.surfaceRaised
                                        : root.hovered ? Theme.colors.surfaceHover
                                                       : root.current ? Theme.colors.surfaceRaised
                                                                      : Theme.colors.transparent
        radius: Theme.radius.control
        border.width: root.activeFocus ? 1 : 0
        border.color: Theme.colors.borderFocus
    }

    onClicked: {
        if (!root.invalid)
            root.activated(root.mediaId)
    }

    Keys.onReturnPressed: event => {
        event.accepted = true
        if (root.enabled && !root.invalid)
            root.activated(root.mediaId)
    }

    Keys.onSpacePressed: event => {
        event.accepted = true
        if (root.enabled && !root.invalid)
            root.activated(root.mediaId)
    }
}
