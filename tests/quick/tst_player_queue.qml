import QtQuick
import QtTest
import "../../qml/components"
import "../../qml/components/Theme.js" as Theme

TestCase {
    id: testCase

    name: "PlayerQueue"
    when: windowShown
    width: 900
    height: 640

    Window {
        id: testWindow
        width: testCase.width
        height: testCase.height
        visible: true

        Item {
            id: stage
            anchors.fill: parent

            Item {
                id: priorFocusTarget

                objectName: "priorFocusTarget"
                width: 40
                height: 40
                activeFocusOnTab: true
            }
        }
    }

    QtObject {
        id: fakePlayer
        property string source: "https://example.test/audio"
        property int position: 61000
        property int duration: 185000
        property real volume: 0.5
        property string playbackState: "Paused"
        property string mediaTitle: "Test track"
        property string mediaCover: ""
        property int playCount: 0
        property int pauseCount: 0
        property int lastSeek: -1
        property real lastVolume: -1
        function play() { ++playCount }
        function pause() { ++pauseCount }
        function seek(value) { lastSeek = value }
        function setVolume(value) { lastVolume = value }
    }

    QtObject {
        id: fakePlaylist
        property int currentIndex: 0
        property int playlistSize: 2
        property int playMode: 0
        property string playlistItems: JSON.stringify([
            { "id": 1, "title": "First", "duration": 61 },
            { "id": 2, "title": "Second", "duration": 125 }
        ])
        property int previousCount: 0
        property int nextCount: 0
        property int lastMode: -1
        property int lastPlayedIndex: -1
        function previous() { ++previousCount }
        function next() { ++nextCount }
        function setPlayMode(mode) { lastMode = mode; playMode = mode }
        function playAt(index) { lastPlayedIndex = index; currentIndex = index }
    }

    Component {
        id: playerComponent

        ResponsivePlayerBar {
            width: 900
            height: 92
            playerController: fakePlayer
            playlistService: fakePlaylist
            reduceMotion: true
        }
    }

    Component {
        id: drawerComponent

        QueueDrawer {
            width: stage.width
            height: stage.height
            playlistService: fakePlaylist
            reduceMotion: true
        }
    }

    property var player: null
    property var drawer: null

    function init() {
        fakePlaylist.currentIndex = 0
        fakePlaylist.playlistSize = 2
        fakePlaylist.playlistItems = JSON.stringify([
            { "id": 1, "title": "First", "duration": 61 },
            { "id": 2, "title": "Second", "duration": 125 }
        ])
        fakePlaylist.lastPlayedIndex = -1
        player = createTemporaryObject(playerComponent, stage)
        drawer = createTemporaryObject(drawerComponent, stage)
        verify(player !== null)
        verify(drawer !== null)
    }

    function cleanup() {
        player = null
        drawer = null
    }

    function test_expandedShowsAllPlayerRegions() {
        player.layoutMode = "expanded"
        verify(player.mediaInfoVisible)
        verify(player.statusSubtitleVisible)
        verify(player.previousVisible)
        verify(player.nextVisible)
        verify(player.playPauseVisible)
        verify(player.progressVisible)
        verify(player.volumeVisible)
        verify(player.queueButtonVisible)
    }

    function test_mediumHidesStatusSubtitle() {
        player.layoutMode = "medium"
        verify(player.mediaInfoVisible)
        verify(!player.statusSubtitleVisible)
        verify(player.previousVisible)
        verify(player.nextVisible)
        verify(player.volumeVisible)
    }

    function test_longQueueTabAdvancesToNextModelIndex() {
        const items = []
        for (let index = 0; index < 80; ++index) {
            items.push({
                "id": index + 1,
                "title": "Track " + (index + 1),
                "duration": 60 + index
            })
        }
        fakePlaylist.playlistSize = items.length
        fakePlaylist.playlistItems = JSON.stringify(items)
        drawer.open()
        const list = findChild(drawer, "queueList")
        tryCompare(list, "count", items.length)
        list.positionViewAtIndex(0, ListView.Beginning)
        list.forceLayout()

        let lastInstantiatedIndex = -1
        for (let index = 0; index < list.count; ++index) {
            if (list.itemAtIndex(index) !== null)
                lastInstantiatedIndex = index
        }
        verify(lastInstantiatedIndex >= 0)
        verify(lastInstantiatedIndex < list.count - 1)
        const lastInstantiatedRow = list.itemAtIndex(lastInstantiatedIndex)
        lastInstantiatedRow.forceActiveFocus()

        keyClick(Qt.Key_Tab)

        const nextIndex = lastInstantiatedIndex + 1
        tryVerify(function() {
            const nextRow = list.itemAtIndex(nextIndex)
            return nextRow !== null && nextRow.activeFocus
        })
    }

    function test_compactKeepsCoreControls() {
        player.layoutMode = "compact"
        verify(player.playPauseVisible)
        verify(player.progressVisible)
        verify(player.queueButtonVisible)
        verify(!player.previousVisible)
        verify(!player.nextVisible)
        verify(!player.volumeVisible)
    }

    function test_queueSignalIsEmitted() {
        const spy = signalSpy.createObject(player, {
            target: player,
            signalName: "queueRequested"
        })
        const queueButton = findChild(player, "queueButton")
        verify(queueButton !== null)
        mouseClick(queueButton, queueButton.width / 2, queueButton.height / 2)
        compare(spy.count, 1)
    }

    function test_drawerEscapeCloses() {
        drawer.open()
        verify(drawer.opened)
        testWindow.requestActivate()
        tryVerify(function() { return testWindow.active })
        drawer.forceActiveFocus()
        keyClick(Qt.Key_Escape)
        verify(!drawer.opened)
    }

    function test_drawerCloseRestoresPreviousFocus() {
        testWindow.requestActivate()
        tryVerify(function() { return testWindow.active })
        priorFocusTarget.forceActiveFocus()
        tryVerify(function() { return priorFocusTarget.activeFocus })

        drawer.open()
        verify(!priorFocusTarget.activeFocus)
        drawer.close()

        tryVerify(function() { return priorFocusTarget.activeFocus })
    }

    function test_drawerTrapsTabAndBacktab() {
        drawer.open()
        const closeButton = findChild(drawer, "queueCloseButton")
        const list = findChild(drawer, "queueList")
        verify(closeButton !== null)
        verify(list !== null)
        tryCompare(list, "count", 2)
        list.forceLayout()
        tryVerify(function() { return list.itemAtIndex(1) !== null })
        const lastRow = list.itemAtIndex(1)

        closeButton.forceActiveFocus()
        keyClick(Qt.Key_Backtab)
        tryVerify(function() { return lastRow.activeFocus })

        keyClick(Qt.Key_Tab)
        tryVerify(function() { return closeButton.activeFocus })
    }

    function test_drawerBackdropCloses() {
        drawer.open()
        const backdrop = findChild(drawer, "queueBackdrop")
        verify(backdrop !== null)
        mouseClick(backdrop, 20, backdrop.height / 2)
        verify(!drawer.opened)
    }

    function test_drawerWidthAndCurrentIndexStaySynchronized() {
        drawer.open()
        const panel = findChild(drawer, "queuePanel")
        const list = findChild(drawer, "queueList")
        verify(panel !== null)
        verify(list !== null)
        compare(panel.width, Math.min(420, drawer.width * 0.88))
        compare(list.currentIndex, 0)

        fakePlaylist.currentIndex = 1
        tryCompare(list, "currentIndex", 1)
    }

    function test_queueRowSupportsKeyboardActivation() {
        drawer.open()
        const list = findChild(drawer, "queueList")
        tryCompare(list, "count", 2)
        list.forceLayout()
        tryVerify(function() { return list.itemAtIndex(1) !== null })
        const secondRow = list.itemAtIndex(1)

        secondRow.forceActiveFocus()
        keyClick(Qt.Key_Return)

        compare(fakePlaylist.lastPlayedIndex, 1)
    }

    function test_queueRowExposesAccessibleStateAndPressAction() {
        drawer.open()
        const list = findChild(drawer, "queueList")
        tryCompare(list, "count", 2)
        list.forceLayout()
        tryVerify(function() { return list.itemAtIndex(0) !== null })
        const firstRow = list.itemAtIndex(0)

        verify(firstRow.activeFocusOnTab)
        compare(firstRow.Accessible.role, Accessible.ListItem)
        compare(firstRow.Accessible.name, "First")
        verify(firstRow.Accessible.selected)
        firstRow.Accessible.pressAction()

        compare(fakePlaylist.lastPlayedIndex, 0)
    }

    function test_playerSlidersDescribeTheirAccessibleValues() {
        const progress = findChild(player, "progressSlider")
        const volume = findChild(player, "volumeSlider")
        verify(progress !== null)
        verify(volume !== null)
        compare(progress.Accessible.name, "播放进度")
        compare(progress.Accessible.description, "01:01 / 03:05")
        compare(volume.Accessible.name, "音量")
        compare(volume.Accessible.description, "50%")
    }

    function test_playerQueueGeometryUsesThemeTokens() {
        player.width = 1400
        player.layoutMode = "expanded"
        drawer.open()
        const media = findChild(player, "playerMediaInfo")
        const progress = findChild(player, "playerProgressSection")
        const volume = findChild(player, "playerVolumeSection")
        const backdrop = findChild(drawer, "queueBackdrop")
        const list = findChild(drawer, "queueList")
        verify(media !== null)
        verify(progress !== null)
        verify(volume !== null)
        verify(backdrop !== null)
        tryCompare(list, "count", 2)
        list.forceLayout()
        tryVerify(function() { return list.itemAtIndex(0) !== null })

        compare(Theme.sizes.playerMediaExpandedWidth, 260)
        compare(Theme.sizes.playerMediaMediumWidth, 190)
        compare(Theme.sizes.playerProgressMinWidth, 180)
        compare(Theme.sizes.playerVolumeWidth, 132)
        compare(Theme.sizes.queueRowHeight, 56)
        compare(media.width, Theme.sizes.playerMediaExpandedWidth)
        verify(progress.width >= Theme.sizes.playerProgressMinWidth)
        compare(volume.width, Theme.sizes.playerVolumeWidth)
        compare(list.itemAtIndex(0).implicitHeight, Theme.sizes.queueRowHeight)
        compare(backdrop.color, Theme.colors.drawerBackdrop)

        player.layoutMode = "medium"
        tryCompare(media, "width", Theme.sizes.playerMediaMediumWidth)
    }

    function test_rapidOpenCloseLeavesInteractionStateCorrect() {
        drawer.open()
        drawer.close()
        drawer.open()
        drawer.close()
        verify(!drawer.opened)
        verify(!drawer.enabled)
        drawer.open()
        verify(drawer.opened)
        verify(drawer.enabled)
    }

    Component {
        id: signalSpy

        SignalSpy {}
    }
}
