// ============================================================================
// Sidebar.qml - 侧边导航栏
// ============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Theme.js" as Theme

Rectangle {
    id: sidebar

    property int currentIndex: 0
    signal navigationRequested(int index)

    color: Theme.colors.bgSidebar

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing.card
        spacing: Theme.spacing.section

        // ---- 品牌 ----
        Label {
            text: qsTr("Bili Music")
            color: Theme.colors.textPrimary
            font.pixelSize: 24; font.bold: true
        }
        Label {
            text: qsTr("哔哩哔哩音乐客户端")
            color: Theme.colors.accent
            font.pixelSize: Theme.fontSizes.caption
        }

        // ---- 用户信息 ----
        Rectangle {
            Layout.fillWidth: true; implicitHeight: 56
            radius: Theme.radius.button
            color: applicationContext && applicationContext.authService
                   && applicationContext.authService.isLoggedIn
                   ? Theme.colors.bgCard : "transparent"
            visible: applicationContext && applicationContext.authService
                     && applicationContext.authService.isLoggedIn

            RowLayout {
                anchors.fill: parent; anchors.margins: 10; spacing: 10

                Rectangle {
                    Layout.preferredWidth: 36; Layout.preferredHeight: 36
                    radius: 18; color: Theme.colors.accent
                    Label {
                        anchors.centerIn: parent
                        text: applicationContext && applicationContext.authService
                              ? (applicationContext.authService.userName || "U")[0].toUpperCase() : "U"
                        color: Theme.colors.textPrimary; font.bold: true; font.pixelSize: 14
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 2
                    Label {
                        text: applicationContext && applicationContext.authService
                              ? applicationContext.authService.userName : ""
                        color: Theme.colors.textSecondary
                        font.pixelSize: Theme.fontSizes.bodySmall; font.bold: true
                        elide: Text.ElideRight; Layout.fillWidth: true
                    }
                    Label {
                        text: qsTr("已登录")
                        color: Theme.colors.accent; font.pixelSize: Theme.fontSizes.small
                    }
                }
            }
        }

        // ---- 导航项 ----
        ColumnLayout {
            Layout.fillWidth: true; spacing: 4

            Repeater {
                model: [
                    { label: qsTr("首页"), icon: "" },
                    { label: qsTr("收藏夹"), icon: "📂" },
                    { label: qsTr("登录"), icon: "🔑" }
                ]
                delegate: Rectangle {
                    required property var modelData; required property int index
                    Layout.fillWidth: true; implicitHeight: Theme.sizes.navItemHeight
                    radius: Theme.radius.button
                    color: sidebar.currentIndex === index ? Theme.colors.bgCard
                         : navMouse.containsMouse ? Theme.colors.bgCardHover : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.duration.fast } }

                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 12; spacing: 10
                        Label { text: modelData.icon; font.pixelSize: 16 }
                        Label {
                            text: modelData.label
                            color: sidebar.currentIndex === index
                                   ? Theme.colors.textPrimary : Theme.colors.textMuted
                            font.pixelSize: Theme.fontSizes.bodySmall
                            font.bold: sidebar.currentIndex === index
                        }
                    }
                    MouseArea {
                        id: navMouse; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { sidebar.currentIndex = index; sidebar.navigationRequested(index) }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        Label {
            text: qsTr("Qt %1").arg(applicationContext ? applicationContext.qtVersion : "")
            color: Theme.colors.textDim; font.pixelSize: Theme.fontSizes.small
            wrapMode: Text.Wrap; Layout.fillWidth: true
        }
    }
}
