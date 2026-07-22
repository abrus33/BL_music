pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "Theme.js" as Theme

FocusScope {
    id: root

    property bool opened: false
    property bool reduceMotion: false
    property var playlistService: null
    property var parsedItems: []
    property var previousFocusItem: null
    property int pendingFocusIndex: -1
    property int focusRetryCount: 0
    readonly property int animationDuration: reduceMotion ? 0 : Theme.motion.drawer

    enabled: opened
    focus: opened

    function open() {
        if (opened)
            return
        const window = root.Window.window
        previousFocusItem = window ? window.activeFocusItem : null
        opened = true
        closeButton.forceActiveFocus()
    }

    function close() {
        if (!opened)
            return
        const restoreItem = previousFocusItem
        previousFocusItem = null
        pendingFocusIndex = -1
        focusRetry.stop()
        opened = false
        if (restoreItem && restoreItem.visible && restoreItem.enabled)
            restoreItem.forceActiveFocus()
    }

    function focusRow(index) {
        if (index < 0 || index >= queueList.count)
            return
        pendingFocusIndex = index
        focusRetryCount = 0
        queueList.positionViewAtIndex(index, ListView.Contain)
        focusRetry.restart()
    }

    function completeFocusMove() {
        if (!opened || pendingFocusIndex < 0) {
            focusRetry.stop()
            return
        }
        queueList.forceLayout()
        const row = queueList.itemAtIndex(pendingFocusIndex)
        if (row) {
            pendingFocusIndex = -1
            focusRetry.stop()
            row.forceActiveFocus()
            return
        }
        ++focusRetryCount
        if (focusRetryCount < 4) {
            queueList.positionViewAtIndex(pendingFocusIndex, ListView.Contain)
            focusRetry.restart()
        } else {
            pendingFocusIndex = -1
            focusRetry.stop()
            closeButton.forceActiveFocus()
        }
    }

    function moveFocus(forward, currentRowIndex) {
        if (queueList.count === 0) {
            closeButton.forceActiveFocus()
            return
        }
        if (currentRowIndex < 0) {
            focusRow(forward ? 0 : queueList.count - 1)
        } else if (forward && currentRowIndex < queueList.count - 1) {
            focusRow(currentRowIndex + 1)
        } else if (!forward && currentRowIndex > 0) {
            focusRow(currentRowIndex - 1)
        } else {
            closeButton.forceActiveFocus()
        }
    }

    function updateItems() {
        if (!playlistService || !playlistService.playlistItems) {
            parsedItems = []
            return
        }
        try {
            const items = JSON.parse(playlistService.playlistItems)
            parsedItems = Array.isArray(items) ? items : []
        } catch (error) {
            parsedItems = []
        }
    }

    onPlaylistServiceChanged: updateItems()
    Keys.onEscapePressed: function(event) {
        close()
        event.accepted = true
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        enabled: root.opened
        onActivated: root.close()
    }

    Timer {
        id: focusRetry

        interval: 0
        onTriggered: root.completeFocusMove()
    }

    Connections {
        target: root.playlistService
        ignoreUnknownSignals: true

        function onPlaylistChanged() { root.updateItems() }
        function onPlaylistItemsChanged() { root.updateItems() }
    }

    Rectangle {
        id: backdrop

        objectName: "queueBackdrop"
        anchors.fill: parent
        color: Theme.colors.drawerBackdrop
        opacity: root.opened ? 1 : 0

        Behavior on opacity {
            OpacityAnimator { duration: root.animationDuration }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    Rectangle {
        id: panel

        objectName: "queuePanel"
        width: Math.min(420, root.width * 0.88)
        height: root.height
        x: root.opened ? root.width - width : root.width
        color: Theme.colors.surfaceRaised
        border.color: Theme.colors.borderSoft

        Behavior on x {
            XAnimator { duration: root.animationDuration }
        }

        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacing.lg
            spacing: Theme.spacing.md

            RowLayout {
                Layout.fillWidth: true

                Label {
                    Layout.fillWidth: true
                    text: qsTr("播放队列 (%1)").arg(root.parsedItems.length)
                    color: Theme.colors.textPrimary
                    font.pixelSize: Theme.fontSizes.h2
                    font.bold: true
                }

                IconButton {
                    id: closeButton

                    objectName: "queueCloseButton"
                    iconSource: "qrc:/qt/qml/cursor_music/icon/close.svg"
                    accessibleName: qsTr("关闭播放队列")
                    Keys.onTabPressed: function(event) {
                        root.moveFocus(true, -1)
                        event.accepted = true
                    }
                    Keys.onBacktabPressed: function(event) {
                        root.moveFocus(false, -1)
                        event.accepted = true
                    }
                    onTriggered: root.close()
                }
            }

            ListView {
                id: queueList

                objectName: "queueList"
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: root.parsedItems
                currentIndex: root.playlistService ? root.playlistService.currentIndex : -1
                spacing: Theme.spacing.xs
                clip: true

                delegate: Button {
                    id: queueItem

                    required property int index
                    required property var modelData

                    objectName: "queueItem" + queueItem.index
                    width: queueList.width
                    implicitHeight: Theme.sizes.queueRowHeight
                    leftPadding: Theme.spacing.md
                    rightPadding: Theme.spacing.md
                    activeFocusOnTab: true
                    focusPolicy: Qt.StrongFocus
                    hoverEnabled: true

                    Accessible.role: Accessible.ListItem
                    Accessible.name: queueItem.modelData.title || qsTr("未知曲目")
                    Accessible.selected: queueItem.index === queueList.currentIndex
                    Accessible.onPressAction: queueItem.click()

                    Keys.onReturnPressed: function(event) {
                        queueItem.click()
                        event.accepted = true
                    }
                    Keys.onTabPressed: function(event) {
                        root.moveFocus(true, queueItem.index)
                        event.accepted = true
                    }
                    Keys.onBacktabPressed: function(event) {
                        root.moveFocus(false, queueItem.index)
                        event.accepted = true
                    }

                    contentItem: RowLayout {
                        spacing: Theme.spacing.md

                        AppIcon {
                            source: queueItem.index === queueList.currentIndex
                                    ? "qrc:/qt/qml/cursor_music/icon/play.svg"
                                    : "qrc:/qt/qml/cursor_music/icon/music-2.svg"
                            iconColor: queueItem.index === queueList.currentIndex
                                       ? Theme.colors.accent : Theme.colors.textTertiary
                        }

                        Label {
                            Layout.fillWidth: true
                            text: queueItem.modelData.title || qsTr("未知曲目")
                            color: queueItem.index === queueList.currentIndex
                                   ? Theme.colors.textPrimary : Theme.colors.textSecondary
                            font.pixelSize: Theme.fontSizes.body
                            elide: Text.ElideRight
                        }

                        Label {
                            text: {
                                const duration = Math.max(
                                                   0, queueItem.modelData.duration || 0)
                                const minutes = Math.floor(duration / 60)
                                const seconds = duration % 60
                                return minutes + ":" + (seconds < 10 ? "0" : "") + seconds
                            }
                            color: Theme.colors.textTertiary
                            font.pixelSize: Theme.fontSizes.small
                            font.family: "monospace"
                        }
                    }

                    background: Rectangle {
                        color: queueItem.index === queueList.currentIndex
                               ? Theme.colors.surfaceHover
                               : queueItem.down ? Theme.colors.surfaceHover
                                                : Theme.colors.transparent
                        radius: Theme.radius.control
                        border.width: queueItem.activeFocus ? 1 : 0
                        border.color: Theme.colors.borderFocus
                    }

                    onClicked: {
                        if (root.playlistService)
                            root.playlistService.playAt(queueItem.index)
                    }
                }
            }
        }
    }
}
