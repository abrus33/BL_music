import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "Theme.js" as Theme

Rectangle {
    id: root

    property string layoutMode: "expanded"
    property bool reduceMotion: false
    property var playerController: null
    property var playlistService: null

    readonly property bool mediaInfoVisible: mediaInfo.visible
    readonly property bool statusSubtitleVisible: statusSubtitle.visible
    readonly property bool previousVisible: previousButton.visible
    readonly property bool nextVisible: nextButton.visible
    readonly property bool playPauseVisible: playPauseButton.visible
    readonly property bool progressVisible: progressSection.visible
    readonly property bool volumeVisible: volumeSection.visible
    readonly property bool queueButtonVisible: queueButton.visible

    signal queueRequested()

    color: Theme.colors.controlInset
    border.color: Theme.colors.borderSoft
    border.width: 1

    function formatTime(milliseconds) {
        const totalSeconds = Math.max(0, Math.floor(milliseconds / 1000))
        const minutes = Math.floor(totalSeconds / 60)
        const seconds = totalSeconds % 60
        return (minutes < 10 ? "0" : "") + minutes + ":"
                + (seconds < 10 ? "0" : "") + seconds
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacing.lg
        anchors.rightMargin: Theme.spacing.lg
        spacing: root.layoutMode === "compact" ? Theme.spacing.sm : Theme.spacing.lg

        RowLayout {
            id: mediaInfo

            objectName: "playerMediaInfo"
            Layout.preferredWidth: root.layoutMode === "expanded"
                                   ? Theme.sizes.playerMediaExpandedWidth
                                   : Theme.sizes.playerMediaMediumWidth
            Layout.maximumWidth: Layout.preferredWidth
            Layout.fillHeight: true
            spacing: Theme.spacing.md
            visible: root.layoutMode !== "compact"

            CoverImage {
                Layout.preferredWidth: Theme.sizes.coverSmall
                Layout.preferredHeight: Theme.sizes.coverSmall
                coverUrl: root.playerController ? root.playerController.mediaCover : ""
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing.xs

                Label {
                    Layout.fillWidth: true
                    text: root.playerController && root.playerController.mediaTitle
                          ? root.playerController.mediaTitle : qsTr("未在播放")
                    color: Theme.colors.textPrimary
                    font.pixelSize: Theme.fontSizes.body
                    font.bold: true
                    elide: Text.ElideRight
                }

                Label {
                    id: statusSubtitle

                    Layout.fillWidth: true
                    visible: root.layoutMode === "expanded"
                    text: root.playerController
                          && root.playerController.playbackState === "Playing"
                          ? qsTr("正在播放") : qsTr("已暂停")
                    color: Theme.colors.textTertiary
                    font.pixelSize: Theme.fontSizes.small
                    elide: Text.ElideRight
                }
            }
        }

        RowLayout {
            spacing: Theme.spacing.xs

            IconButton {
                id: previousButton

                visible: root.layoutMode !== "compact"
                enabled: root.playlistService && root.playlistService.playlistSize > 1
                iconSource: "qrc:/qt/qml/cursor_music/icon/skip-back.svg"
                accessibleName: qsTr("上一首")
                onTriggered: root.playlistService.previous()
            }

            IconButton {
                id: playPauseButton

                enabled: root.playerController !== null
                iconSource: root.playerController
                            && root.playerController.playbackState === "Playing"
                            ? "qrc:/qt/qml/cursor_music/icon/pause.svg"
                            : "qrc:/qt/qml/cursor_music/icon/play.svg"
                accessibleName: root.playerController
                                && root.playerController.playbackState === "Playing"
                                ? qsTr("暂停") : qsTr("播放")
                onTriggered: {
                    if (root.playerController.playbackState === "Playing")
                        root.playerController.pause()
                    else
                        root.playerController.play()
                }
            }

            IconButton {
                id: nextButton

                visible: root.layoutMode !== "compact"
                enabled: root.playlistService && root.playlistService.playlistSize > 1
                iconSource: "qrc:/qt/qml/cursor_music/icon/skip-forward.svg"
                accessibleName: qsTr("下一首")
                onTriggered: root.playlistService.next()
            }

            IconButton {
                id: playModeButton

                enabled: root.playlistService && root.playlistService.playlistSize > 1
                iconSource: root.playlistService && root.playlistService.playMode === 1
                            ? "qrc:/qt/qml/cursor_music/icon/shuffle.svg"
                            : "qrc:/qt/qml/cursor_music/icon/repeat-2.svg"
                accessibleName: root.playlistService && root.playlistService.playMode === 1
                                ? qsTr("随机播放") : qsTr("循环播放")
                onTriggered: root.playlistService.setPlayMode(
                                 root.playlistService.playMode === 1 ? 0 : 1)
            }
        }

        RowLayout {
            id: progressSection

            objectName: "playerProgressSection"
            Layout.fillWidth: true
            Layout.minimumWidth: Theme.sizes.playerProgressMinWidth
            spacing: Theme.spacing.sm

            Label {
                text: root.formatTime(root.playerController
                                      ? root.playerController.position : 0)
                color: Theme.colors.textTertiary
                font.pixelSize: Theme.fontSizes.small
                font.family: "monospace"
            }

            Slider {
                id: progressSlider

                objectName: "progressSlider"
                Layout.fillWidth: true
                from: 0
                to: root.playerController ? Math.max(0, root.playerController.duration) : 0
                value: root.playerController ? root.playerController.position : 0
                enabled: root.playerController !== null
                Accessible.name: qsTr("播放进度")
                Accessible.description: qsTr("%1 / %2")
                                        .arg(root.formatTime(progressSlider.value))
                                        .arg(root.formatTime(progressSlider.to))
                onMoved: root.playerController.seek(value)
            }

            Label {
                text: root.formatTime(root.playerController
                                      ? root.playerController.duration : 0)
                color: Theme.colors.textTertiary
                font.pixelSize: Theme.fontSizes.small
                font.family: "monospace"
            }
        }

        RowLayout {
            id: volumeSection

            objectName: "playerVolumeSection"
            Layout.preferredWidth: Theme.sizes.playerVolumeWidth
            Layout.maximumWidth: Theme.sizes.playerVolumeWidth
            spacing: Theme.spacing.xs
            visible: root.layoutMode !== "compact"

            AppIcon {
                source: "qrc:/qt/qml/cursor_music/icon/volume-2.svg"
                iconColor: Theme.colors.textSecondary
            }

            Slider {
                id: volumeSlider

                objectName: "volumeSlider"
                Layout.fillWidth: true
                from: 0
                to: 100
                value: root.playerController ? root.playerController.volume * 100 : 0
                enabled: root.playerController !== null
                Accessible.name: qsTr("音量")
                Accessible.description: qsTr("%1%").arg(
                                            Math.round(volumeSlider.value))
                onMoved: root.playerController.setVolume(value / 100)
            }
        }

        IconButton {
            id: queueButton

            objectName: "queueButton"
            enabled: root.playlistService && root.playlistService.playlistSize > 0
            iconSource: "qrc:/qt/qml/cursor_music/icon/list-music.svg"
            accessibleName: qsTr("播放队列")
            onTriggered: root.queueRequested()
        }
    }
}
