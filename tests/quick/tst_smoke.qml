import QtQuick
import QtTest

TestCase {
    name: "Smoke"

    Component {
        id: itemComponent

        Item {
            property string readiness: "ready"
        }
    }

    function test_runtimeCreatesQmlItem() {
        const item = createTemporaryObject(itemComponent, this)

        verify(item !== null)
        compare(item.readiness, "ready")
    }
}
