// ============================================================================
// Sidebar.qml - 侧边导航栏
//
// 新人阅读重点：
// 1. Sidebar 不知道页面具体内容，只维护 currentIndex。
// 2. Main.qml 把 currentIndex 绑定到 StackLayout.currentIndex 完成页面切换。
// 3. 用户信息直接绑定 AuthService 的 Q_PROPERTY，登录状态变化后自动刷新。
// ============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Theme.js" as Theme

Rectangle {
    id: sidebar

    // 导航项索引：0=首页，1=收藏夹，2=登录。
    property int currentIndex: 0
    // 给父组件的通知。当前 Main.qml 主要用 currentIndex 绑定即可。
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
            // applicationContext 来自 main.cpp 的 setContextProperty。
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
                // 小型固定菜单直接用 JS 数组即可，不需要 C++ Model。
                model: [
                    { label: qsTr("首页"), icon: "" },
                    { label: qsTr("收藏夹"), icon: "📂" },
                    { label: qsTr("登录"), icon: "🔑" }
                ]
                delegate: Rectangle {
                    // required property 是 Qt 6 推荐写法，明确说明 delegate 需要哪些隐式数据。
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
                        // 修改 currentIndex 后，Main.qml 的 StackLayout 会自动切换页面。
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
