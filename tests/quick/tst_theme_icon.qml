import QtQuick
import QtTest
import "../../qml/components"
import "../../qml/components/Theme.js" as Theme

TestCase {
    name: "ThemeAndIcon"
    when: windowShown

    Component {
        id: iconComponent

        AppIcon {
            source: "qrc:/qt/qml/cursor_music/icon/home.svg"
        }
    }

    Component {
        id: resourceImageComponent

        Image {
            source: "qrc:/qt/qml/cursor_music/icon/home.svg"
        }
    }

    function test_breakpointsAreStable() {
        compare(Theme.breakpoints.compact, 860)
        compare(Theme.breakpoints.expanded, 1180)
        compare(Theme.motion.drawer, 240)
    }

    function test_canonicalMotionStaysWithinLimit() {
        verify(Theme.motion.drawer <= 260)
    }

    function test_homeIconLoadsFromResource() {
        let icon = createTemporaryObject(iconComponent, this)
        verify(icon !== null)
        compare(icon.source, "qrc:/qt/qml/cursor_music/icon/home.svg")

        let resourceImage = createTemporaryObject(resourceImageComponent, this)
        verify(resourceImage !== null)
        tryCompare(resourceImage, "status", Image.Ready)
    }
}
