import QtQuick
import QtTest
import "../../qml/components"

TestCase {
    id: testCase

    name: "AppShell"
    when: windowShown

    width: 1360
    height: 860

    Window {
        id: testWindow

        width: testCase.width
        height: testCase.height
        visible: true

        Item {
            id: stage
            anchors.fill: parent
        }
    }

    Component {
        id: shellComponent

        AppShell {
            id: testShell

            height: 860

            queueContent: Rectangle {
                objectName: "testQueueContent"
                width: 320
                height: parent ? parent.height : 0
            }

            compactNavigationContent: NavigationRail {
                objectName: "compactNavigation"
                width: parent.width
                height: implicitHeight
                horizontal: true
                expanded: false
                updatesCurrentIndex: false
                entries: testShell.navigationEntries
                currentIndex: testShell.currentIndex
                onNavigationRequested: function(index) {
                    testShell.currentIndex = index
                    testShell.navigationRequested(index)
                }
            }
        }
    }

    Component {
        id: navigationComponent

        NavigationRail {
            height: 560
        }
    }

    function test_layoutModes() {
        const shell = createTemporaryObject(shellComponent, stage)
        verify(shell !== null)

        shell.width = 1360
        compare(shell.layoutMode, "expanded")
        compare(shell.navigationWidth, 240)

        shell.width = 1024
        compare(shell.layoutMode, "medium")
        compare(shell.navigationWidth, 72)

        shell.width = 800
        compare(shell.layoutMode, "compact")
        compare(shell.navigationWidth, 0)
    }

    function test_mediumNavigationKeepsIconsAndHidesLabels() {
        const navigation = createTemporaryObject(navigationComponent, stage, {
            expanded: false,
            width: 72
        })
        verify(navigation !== null)

        const firstIcon = findChild(navigation, "navigationIcon0")
        const firstLabel = findChild(navigation, "navigationLabel0")
        verify(firstIcon !== null)
        verify(firstLabel !== null)
        verify(firstIcon.visible)
        verify(!firstLabel.visible)
    }

    function test_compactNavigationOffersThreeOperableItems() {
        const shell = createTemporaryObject(shellComponent, stage, {
            width: 800,
            height: 860
        })
        verify(shell !== null)
        compare(shell.layoutMode, "compact")
        compare(shell.navigationWidth, 0)
        const spy = signalSpy.createObject(shell, {
            target: shell,
            signalName: "navigationRequested"
        })
        const compactNavigation = findChild(shell, "compactNavigation")
        verify(compactNavigation !== null)

        for (let index = 0; index < 3; ++index) {
            const item = findChild(compactNavigation, "navigationItem" + index)
            verify(item !== null)
            verify(item.visible)
            verify(item.enabled)
            verify(item.width > 0)
        }

        const thirdItem = findChild(compactNavigation, "navigationItem2")
        mouseClick(thirdItem, thirdItem.width / 2, thirdItem.height / 2)
        compare(shell.currentIndex, 2)
        compare(spy.count, 1)
        compare(spy.signalArguments[0][0], 2)
    }

    function test_desktopNavigationActivatesOnceWithReturnAndSpace() {
        const navigation = createTemporaryObject(navigationComponent, stage, {
            expanded: true,
            width: 240
        })
        verify(navigation !== null)
        const firstItem = findChild(navigation, "navigationItem0")
        const secondItem = findChild(navigation, "navigationItem1")
        verify(firstItem !== null)
        verify(secondItem !== null)
        verify(firstItem.activeFocusOnTab)
        verify(secondItem.activeFocusOnTab)
        compare(firstItem.Accessible.role, Accessible.Button)
        compare(firstItem.Accessible.name, "首页")
        const spy = signalSpy.createObject(navigation, {
            target: navigation,
            signalName: "navigationRequested"
        })

        testWindow.requestActivate()
        tryVerify(function() { return testWindow.active })
        firstItem.forceActiveFocus()
        tryVerify(function() { return firstItem.activeFocus })
        keyClick(Qt.Key_Return)
        compare(spy.count, 1)
        compare(spy.signalArguments[0][0], 0)

        keyClick(Qt.Key_Tab)
        tryVerify(function() { return secondItem.activeFocus })
        keyClick(Qt.Key_Space)
        compare(spy.count, 2)
        compare(spy.signalArguments[1][0], 1)
    }

    function test_navigationRequestUpdatesCurrentIndex() {
        const navigation = createTemporaryObject(navigationComponent, stage, {
            expanded: true,
            width: 240
        })
        verify(navigation !== null)
        const secondItem = findChild(navigation, "navigationItem1")
        verify(secondItem !== null)
        const spy = signalSpy.createObject(navigation, {
            target: navigation,
            signalName: "navigationRequested"
        })

        mouseClick(secondItem, secondItem.width / 2, secondItem.height / 2)

        compare(navigation.currentIndex, 1)
        compare(spy.count, 1)
        compare(spy.signalArguments[0][0], 1)
    }

    function test_accessiblePressActivatesExactlyOnce() {
        const navigation = createTemporaryObject(navigationComponent, stage, {
            expanded: true,
            width: 240
        })
        verify(navigation !== null)
        const firstItem = findChild(navigation, "navigationItem0")
        verify(firstItem !== null)
        const spy = signalSpy.createObject(navigation, {
            target: navigation,
            signalName: "navigationRequested"
        })

        firstItem.Accessible.pressAction()

        compare(spy.count, 1)
        compare(spy.signalArguments[0][0], 0)
    }

    function test_reduceMotionDisablesPageTransition() {
        const shell = createTemporaryObject(shellComponent, stage, {
            width: 1360,
            reduceMotion: true
        })
        verify(shell !== null)

        shell.currentIndex = 1

        compare(shell.pageTransitionDuration, 0)
        tryCompare(shell, "pageOpacity", 1)
        tryCompare(shell, "pageTranslateY", 0)
    }

    function test_queueOpenControlsRightPanelSlot() {
        const shell = createTemporaryObject(shellComponent, stage, {
            width: 1360,
            queueOpen: false
        })
        verify(shell !== null)
        const queue = findChild(shell, "testQueueContent")
        verify(queue !== null)
        verify(!queue.visible)

        shell.queueOpen = true

        tryVerify(function() { return queue.visible })
    }

    Component {
        id: signalSpy

        SignalSpy {}
    }
}
