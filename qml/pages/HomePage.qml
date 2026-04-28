// ============================================================================
// HomePage.qml - 首页
// 功能：项目结构和开发进度的概览展示页
// 与 C++ 的交互：通过 applicationContext.qtVersion 读取 Qt 版本号
// ============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// ScrollView：可滚动的视图容器，当内容超出高度时可滚动查看
ScrollView {
    clip: true  // 裁剪超出部分，防止内容溢出

    Rectangle {
        // implicitWidth/Height：建议尺寸，ScrollView 会根据内容自适应
        implicitWidth: 900
        implicitHeight: contentColumn.implicitHeight + 48
        color: "#202020"

        // ---- 内容列布局 ----
        ColumnLayout {
            id: contentColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 24
            spacing: 20

            // 页面标题
            Label {
                text: qsTr("开发环境与目录结构已确认")
                color: "#ffffff"
                font.pixelSize: 28
                font.bold: true
            }

            // Qt 版本信息（从 C++ ApplicationContext 读取）
            Label {
                // .arg() = QML 的字符串格式化，将 Qt 版本号填入 %1 位置
                text: qsTr("当前基线：Qt %1，C++17，CMake 已预留 Network / Multimedia / QuickControls2 / Svg 模块。")
                    .arg(applicationContext.qtVersion)
                color: "#bcbcbc"
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }

            // ---- 模块卡片列表 ----
            // Repeater 根据模型数组动态生成信息卡片
            Repeater {
                model: [
                    // title: 模块名称，desc: 模块功能描述
                    { "title": qsTr("src/app"), "desc": qsTr("应用上下文、依赖装配与后续全局服务入口") },
                    { "title": qsTr("src/network"), "desc": qsTr("通用 HTTP 客户端，支持 GET/POST、超时、自定义 Header") },
                    { "title": qsTr("src/storage"), "desc": qsTr("持久化 CookieJar 与 AppSettings 配置读写") },
                    { "title": qsTr("qml/components"), "desc": qsTr("可复用 UI 组件，如侧边栏、播放栏、卡片") },
                    { "title": qsTr("qml/pages"), "desc": qsTr("页面级视图，如首页、收藏页、登录页") }
                ]

                // 卡片委托
                delegate: Rectangle {
                    required property var modelData  // 当前卡片的标题+描述对象

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
