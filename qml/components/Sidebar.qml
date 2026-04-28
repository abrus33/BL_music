import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: sidebar

    property int currentIndex: 0

    signal navigationRequested(int index)

    color: "#111111"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 18

        Label {
            text: qsTr("Bili Music")
            color: "#ffffff"
            font.pixelSize: 24
            font.bold: true
        }

        Label {
            text: qsTr("阶段一 · 基础框架")
            color: "#fb7299"
            font.pixelSize: 13
        }

        Repeater {
            model: [
                qsTr("首页"),
                qsTr("收藏夹"),
                qsTr("登录")
            ]

            delegate: Rectangle {
                required property string modelData
                required property int index

                Layout.fillWidth: true
                implicitHeight: 40
                radius: 8
                color: sidebar.currentIndex === index ? "#252525" : "transparent"

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    height: 20
                    radius: 1.5
                    color: sidebar.currentIndex === index ? "#fb7299" : "transparent"
                    anchors.leftMargin: 0
                }

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    text: parent.modelData
                    color: sidebar.currentIndex === index ? "#ffffff" : "#dddddd"
                    font.pixelSize: 14
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        sidebar.currentIndex = index
                        sidebar.navigationRequested(index)
                    }
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }

        Label {
            text: qsTr("Qt %1 / 应用已就绪").arg(applicationContext.qtVersion)
            color: "#7d7d7d"
            font.pixelSize: 12
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }
    }
}
