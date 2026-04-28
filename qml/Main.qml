import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: window

    width: 1360
    height: 860
    visible: true
    title: qsTr("Bilibili Music Client")
    color: "#181818"

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Sidebar {
            id: sidebar

            Layout.fillHeight: true
            Layout.preferredWidth: 240
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#202020"

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                StackLayout {
                    id: pageStack

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: sidebar.currentIndex

                    HomePage {}
                    FavoritesPage {}
                    LoginPage {}
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 92
                    color: "#141414"
                    border.color: "#292929"
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 16

                        Rectangle {
                            Layout.preferredWidth: 52
                            Layout.preferredHeight: 52
                            radius: 8
                            color: "#2a2a2a"
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Label {
                                text: qsTr("播放栏占位")
                                color: "#f5f5f5"
                                font.pixelSize: 16
                                font.bold: true
                            }

                            Label {
                                text: qsTr("Qt %1 / 后续接入播放器控制").arg(applicationContext.qtVersion)
                                color: "#9d9d9d"
                                font.pixelSize: 12
                            }
                        }

                        Slider {
                            Layout.preferredWidth: 200
                            from: 0
                            to: 100
                            value: 30
                        }
                    }
                }
            }
        }
    }
}
