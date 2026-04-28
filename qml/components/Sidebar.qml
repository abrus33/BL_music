// ============================================================================
// Sidebar.qml - 侧边导航栏
// 功能：应用主导航菜单，点击切换内容区页面
// 与 C++ 的交互：通过 applicationContext.qtVersion 读取 Qt 版本
// 向父组件暴露：
//   - currentIndex: 当前选中项索引（被 Main.qml 的 StackLayout 绑定）
//   - navigationRequested 信号（通知父组件页面切换事件）
// ============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: sidebar

    // ---- 对外暴露的属性 ----
    /** @brief 当前选中导航项的索引（0=首页，1=收藏夹，2=登录） */
    property int currentIndex: 0

    /** @brief 导航请求信号（父组件可监听此信号执行额外逻辑） */
    signal navigationRequested(int index)

    color: "#111111"  // 侧边栏背景色（最深色，与内容区形成对比）

    // ---- 侧边栏内容垂直布局 ----
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 18

        // 应用标题
        Label {
            text: qsTr("Bili Music")
            color: "#ffffff"
            font.pixelSize: 24
            font.bold: true
        }

        // 阶段标识（粉色文字 #fb7299 = B站品牌色）
        Label {
            text: qsTr("阶段一 · 基础框架")
            color: "#fb7299"
            font.pixelSize: 13
        }

        // ---- 导航菜单项目 ----
        // Repeater 根据 model 数组动态生成导航项
        // 每个项点击时更新 currentIndex 并触发 navigationRequested 信号
        Repeater {
            model: [
                qsTr("首页"),       // 索引 0
                qsTr("收藏夹"),    // 索引 1
                qsTr("登录")       // 索引 2
            ]

            // 每个导航项的委托（delegate）
            delegate: Rectangle {
                // required property: 从 Repeater 隐式提供的模型数据
                required property string modelData  // 当前项的文本（"首页"/"收藏夹"/"登录"）
                required property int index         // 当前项的索引（0/1/2）

                Layout.fillWidth: true
                implicitHeight: 40
                radius: 8

                // 高亮效果：当前选中项使用 #252525 背景
                color: sidebar.currentIndex === index ? "#252525" : "transparent"

                // ---- 左侧选中指示条 ----
                // 当前选中项显示粉色竖条（#fb7299 = B站品牌色）
                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    height: 20
                    radius: 1.5
                    color: sidebar.currentIndex === index ? "#fb7299" : "transparent"
                    anchors.leftMargin: 0
                }

                // 菜单标签
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    text: parent.modelData
                    // 选中项文字白色，未选中项灰色
                    color: sidebar.currentIndex === index ? "#ffffff" : "#dddddd"
                    font.pixelSize: 14
                }

                // ---- 点击交互 ----
                // MouseArea 覆盖整项，处理点击事件
                // cursorShape: Qt.PointingHandCursor 显示手型光标
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        // 更新当前选中项索引（驱动 StackLayout 页面切换）
                        sidebar.currentIndex = index
                        // 发射导航信号（供父组件监听）
                        sidebar.navigationRequested(index)
                    }
                }
            }
        }

        // ---- 底部弹性空间 ----
        // Item 会自动填充剩余垂直空间，将底部信息推到最下方
        Item {
            Layout.fillHeight: true
        }

        // ---- 底部版本信息 ----
        // 展示当前 Qt 版本和运行状态
        // applicationContext 是 C++ 暴露给 QML 的全局属性
        Label {
            text: qsTr("Qt %1 / 应用已就绪").arg(applicationContext.qtVersion)
            color: "#7d7d7d"
            font.pixelSize: 12
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }
    }
}
