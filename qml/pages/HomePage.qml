import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ScrollView {
    clip: true

    Rectangle {
        implicitWidth: 900
        implicitHeight: contentColumn.implicitHeight + 48
        color: "#202020"

        ColumnLayout {
            id: contentColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 24
            spacing: 20

            Label {
                text: qsTr("开发环境与目录结构已确认")
                color: "#ffffff"
                font.pixelSize: 28
                font.bold: true
            }

            Label {
                text: qsTr("当前基线：Qt %1，C++17，CMake 已预留 Network / Multimedia / QuickControls2 / Svg 模块。")
                    .arg(applicationContext.qtVersion)
                color: "#bcbcbc"
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }

            Repeater {
                model: [
                    { "title": qsTr("src/app"), "desc": qsTr("应用上下文、依赖装配与后续全局服务入口") },
                    { "title": qsTr("src/network"), "desc": qsTr("通用 HTTP 客户端，支持 GET/POST、超时、自定义 Header") },
                    { "title": qsTr("src/storage"), "desc": qsTr("持久化 CookieJar 与 AppSettings 配置读写") },
                    { "title": qsTr("qml/components"), "desc": qsTr("可复用 UI 组件，如侧边栏、播放栏、卡片") },
                    { "title": qsTr("qml/pages"), "desc": qsTr("页面级视图，如首页、收藏页、登录页") }
                ]

                delegate: Rectangle {
                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: 88
                    radius: 12
                    color: "#262626"

                    Column {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 6

                        Label {
                            text: parent.parent.modelData.title
                            color: "#f4f4f4"
                            font.pixelSize: 17
                            font.bold: true
                        }

                        Label {
                            text: parent.parent.modelData.desc
                            color: "#a8a8a8"
                            font.pixelSize: 13
                            wrapMode: Text.Wrap
                            width: parent.width
                        }
                    }
                }
            }
        }
    }
}
