pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components/Theme.js" as Theme

ApplicationWindow {
    id: window

    property int currentPageIndex: 0
    property bool queueOpen: false
    required property var appContext

    minimumWidth: 760
    minimumHeight: 560
    width: 1360
    height: 860
    visible: true
    title: qsTr("Bilibili Music Client")
    color: Theme.colors.canvas

    AppShell {
        id: shell

        anchors.fill: parent
        currentIndex: window.currentPageIndex
        queueOpen: window.queueOpen
        reduceMotion: window.appContext.settings.reduceMotion
        onNavigationRequested: function(index) { window.currentPageIndex = index }

        mainContent: StackLayout {
            anchors.fill: parent
            currentIndex: window.currentPageIndex

            HomePage {
                musicService: window.appContext.musicService
                mediaResolver: window.appContext.mediaResolver
                playerController: window.appContext.playerController
            }
            FavoritesPage {
                authService: window.appContext.authService
                favoriteService: window.appContext.favoriteService
                playlistService: window.appContext.playlistService
                playerController: window.appContext.playerController
            }
            LoginPage {
                authService: window.appContext.authService
            }
        }

        playerContent: ResponsivePlayerBar {
            width: parent.width
            height: Theme.sizes.playerHeight
            layoutMode: shell.layoutMode
            reduceMotion: shell.reduceMotion
            playerController: window.appContext.playerController
            playlistService: window.appContext.playlistService
            onQueueRequested: queueDrawer.open()
        }

        compactNavigationContent: NavigationRail {
            objectName: "compactNavigation"
            width: parent.width
            height: implicitHeight
            horizontal: true
            expanded: false
            updatesCurrentIndex: false
            entries: shell.navigationEntries
            currentIndex: window.currentPageIndex
            onNavigationRequested: function(index) { window.currentPageIndex = index }
        }
    }

    QueueDrawer {
        id: queueDrawer

        anchors.fill: parent
        z: 100
        reduceMotion: shell.reduceMotion
        playlistService: window.appContext.playlistService
        onOpenedChanged: window.queueOpen = queueDrawer.opened
    }
}
