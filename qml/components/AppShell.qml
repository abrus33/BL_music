import QtQuick
import QtQuick.Layouts
import "Theme.js" as Theme

Item {
    id: root

    readonly property string layoutMode: width >= Theme.breakpoints.expanded
        ? "expanded"
        : width >= Theme.breakpoints.compact ? "medium" : "compact"
    readonly property int navigationWidth: layoutMode === "expanded" ? 240
        : layoutMode === "medium" ? 72 : 0
    property bool reduceMotion: false
    property bool queueOpen: false
    property int currentIndex: 0
    readonly property int pageTransitionDuration: reduceMotion ? 0 : Theme.motion.page
    readonly property real pageOpacity: contentHost.opacity
    readonly property real pageTranslateY: pageTranslate.y
    property alias navigationEntries: navigation.entries

    property alias mainContent: contentHost.data
    property alias playerContent: playerHost.data
    // Optional inline queue slot for embedders/tests. Main uses a window-level
    // QueueDrawer instead so its modal backdrop can cover navigation as well.
    property alias queueContent: queueHost.data
    property alias compactNavigationContent: compactNavigationHost.data

    signal navigationRequested(int index)

    onCurrentIndexChanged: {
        navigation.currentIndex = root.currentIndex
        pageTransition.stop()
        contentHost.opacity = 0
        pageTranslate.y = 8
        pageTransition.start()
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.colors.canvas
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        NavigationRail {
            id: navigation

            Layout.fillHeight: true
            Layout.preferredWidth: root.navigationWidth
            visible: root.navigationWidth > 0
            expanded: root.layoutMode === "expanded"
            currentIndex: root.currentIndex
            updatesCurrentIndex: false
            onNavigationRequested: function(index) {
                root.navigationRequested(index)
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.colors.surface

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Item {
                    id: contentHost

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    transform: Translate { id: pageTranslate }
                }

                Item {
                    id: playerHost

                    Layout.fillWidth: true
                    implicitHeight: childrenRect.height
                    visible: children.length > 0
                }

                Item {
                    id: compactNavigationHost

                    Layout.fillWidth: true
                    implicitHeight: childrenRect.height
                    visible: root.layoutMode === "compact" && children.length > 0
                }
            }
        }

        Item {
            id: queueHost

            Layout.fillHeight: true
            Layout.preferredWidth: root.queueOpen ? implicitWidth : 0
            visible: root.queueOpen
            implicitWidth: childrenRect.width
        }
    }

    ParallelAnimation {
        id: pageTransition

        NumberAnimation {
            target: contentHost
            property: "opacity"
            from: 0
            to: 1
            duration: root.pageTransitionDuration
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: pageTranslate
            property: "y"
            from: 8
            to: 0
            duration: root.pageTransitionDuration
            easing.type: Easing.OutCubic
        }
    }
}
