pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "Theme.js" as Theme

Rectangle {
    id: root

    property int currentIndex: 0
    property bool expanded: true
    property bool horizontal: false
    property bool updatesCurrentIndex: true
    property var entries: [
        { label: qsTr("首页"), icon: "qrc:/qt/qml/cursor_music/icon/home.svg" },
        { label: qsTr("收藏夹"), icon: "qrc:/qt/qml/cursor_music/icon/folder-heart.svg" },
        { label: qsTr("登录"), icon: "qrc:/qt/qml/cursor_music/icon/log-in.svg" }
    ]

    signal navigationRequested(int index)

    implicitHeight: horizontal ? Theme.sizes.navItemHeight + Theme.spacing.lg : 0
    color: Theme.colors.controlInset
    clip: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.horizontal ? Theme.spacing.sm
                                            : root.expanded ? Theme.spacing.xl
                                                            : Theme.spacing.lg
        spacing: root.horizontal ? 0 : Theme.spacing.lg

        Label {
            Layout.fillWidth: true
            visible: root.expanded && !root.horizontal
            text: qsTr("Bili Music")
            color: Theme.colors.textPrimary
            font.pixelSize: Theme.fontSizes.h1
            font.bold: true
            elide: Text.ElideRight
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: root.horizontal
            columns: root.horizontal ? Math.max(1, root.entries.length) : 1
            rows: root.horizontal ? 1 : Math.max(1, root.entries.length)
            columnSpacing: Theme.spacing.xs
            rowSpacing: Theme.spacing.xs

            Repeater {
                model: root.entries

                delegate: Button {
                    id: navigationItem

                    required property var modelData
                    required property int index

                    objectName: "navigationItem" + index
                    Layout.fillWidth: true
                    Layout.fillHeight: root.horizontal
                    implicitHeight: Theme.sizes.navItemHeight
                    activeFocusOnTab: true
                    hoverEnabled: true
                    focusPolicy: Qt.StrongFocus

                    Accessible.name: modelData.label
                    Accessible.role: Accessible.Button
                    Accessible.selected: root.currentIndex === index
                    Accessible.onPressAction: navigationItem.click()

                    Keys.onReturnPressed: function(event) {
                        navigationItem.click()
                        event.accepted = true
                    }

                    contentItem: RowLayout {
                        spacing: Theme.spacing.md

                        AppIcon {
                            objectName: "navigationIcon" + navigationItem.index
                            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                            source: navigationItem.modelData.icon
                            iconColor: root.currentIndex === navigationItem.index
                                       ? Theme.colors.accent
                                       : Theme.colors.textSecondary
                        }

                        Label {
                            objectName: "navigationLabel" + navigationItem.index
                            Layout.fillWidth: true
                            visible: root.expanded || root.horizontal
                            text: navigationItem.modelData.label
                            color: root.currentIndex === navigationItem.index
                                   ? Theme.colors.textPrimary
                                   : Theme.colors.textSecondary
                            font.pixelSize: Theme.fontSizes.bodySmall
                            font.bold: root.currentIndex === navigationItem.index
                            horizontalAlignment: root.horizontal ? Text.AlignHCenter : Text.AlignLeft
                            elide: Text.ElideRight
                        }
                    }

                    background: Rectangle {
                        color: root.currentIndex === navigationItem.index
                               ? Theme.colors.surfaceRaised
                               : navigationItem.down
                                 ? Theme.colors.surfaceRaised
                                 : navigationItem.hovered
                                   ? Theme.colors.surfaceHover
                                   : Theme.colors.transparent
                        radius: Theme.radius.control
                        border.width: navigationItem.activeFocus ? 1 : 0
                        border.color: Theme.colors.borderFocus
                    }

                    onClicked: {
                        if (root.updatesCurrentIndex)
                            root.currentIndex = navigationItem.index
                        root.navigationRequested(navigationItem.index)
                    }
                }
            }
        }

        Item {
            Layout.fillHeight: true
            visible: !root.horizontal
        }
    }
}
