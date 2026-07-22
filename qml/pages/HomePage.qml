pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../components/Theme.js" as Theme

Item {
    id: root

    required property var musicService
    required property var mediaResolver
    required property var playerController

    property var musicModel: []
    property string viewState: "loading"
    property string errorMessage: ""
    property string playbackError: ""
    property bool _resolvePending: false
    readonly property string resolverOwnerToken: "home-" + Date.now().toString(36)
                                                 + "-" + Math.random().toString(36).slice(2)

    function rebuildMediaViewModel() {
        mediaViewModel.clear()
        for (let index = 0; index < musicModel.length; ++index) {
            const item = musicModel[index]
            mediaViewModel.append({
                mediaId: item.id,
                title: item.title || qsTr("Unknown track"),
                coverUrl: item.cover || "",
                uploader: item.artist || "",
                resourceTypeLabel: qsTr("Audio"),
                duration: formatDuration(item.duration),
                invalid: false
            })
        }
    }

    function formatDuration(seconds) {
        if (seconds === undefined || seconds === null || seconds === "")
            return ""
        const total = Math.max(0, Math.floor(Number(seconds)))
        const minutes = Math.floor(total / 60)
        const remainder = total % 60
        return (minutes < 10 ? "0" : "") + minutes + ":"
                + (remainder < 10 ? "0" : "") + remainder
    }

    function loadMusic() {
        errorMessage = ""
        musicModel = []
        rebuildMediaViewModel()
        viewState = "loading"
        musicService.loadMusicRank(1, 6)
    }

    function handleMusicLoaded(success, json, error) {
        if (!success) {
            errorMessage = error || qsTr("Could not load popular music")
            viewState = "error"
            return
        }

        try {
            const parsed = JSON.parse(json || "[]")
            if (!Array.isArray(parsed))
                throw new Error("Expected a JSON array")
            musicModel = parsed
            rebuildMediaViewModel()
            errorMessage = ""
            viewState = "ready"
        } catch (parseError) {
            musicModel = []
            rebuildMediaViewModel()
            errorMessage = qsTr("Invalid music response")
            viewState = "error"
        }
    }

    function playMedia(mediaId) {
        if (_resolvePending)
            return

        for (let index = 0; index < musicModel.length; ++index) {
            const item = musicModel[index]
            if (item.id === mediaId) {
                playbackError = ""
                _resolvePending = true
                playerController.mediaTitle = item.title || qsTr("Unknown")
                playerController.mediaCover = item.cover || ""
                mediaResolver.resolveForOwner(resolverOwnerToken, item.id, 12)
                return
            }
        }
    }

    function handleMediaResolved(success, url, title, cover, duration, error) {
        if (!_resolvePending)
            return

        _resolvePending = false
        if (!success || !url) {
            playbackError = error || qsTr("Could not resolve this track")
            return
        }

        playbackError = ""
        playerController.source = url
        playerController.play()
    }

    Connections {
        target: root.musicService

        function onMusicRankLoaded(success, json, error) {
            root.handleMusicLoaded(success, json, error)
        }
    }

    Connections {
        target: root.mediaResolver

        function onMediaResolvedForOwner(ownerToken, success, url, title, cover,
                                         duration, error) {
            if (ownerToken !== root.resolverOwnerToken)
                return
            root.handleMediaResolved(success, url, title, cover, duration, error)
        }
    }

    Component.onCompleted: Qt.callLater(function() { root.loadMusic() })

    ListModel {
        id: mediaViewModel
    }

    ScrollView {
        id: pageScroll
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        contentHeight: pageContent.height

        Item {
            id: pageContent
            width: Math.max(pageScroll.availableWidth, Theme.sizes.favoritesContentMinWidth)
            height: Math.max(Theme.sizes.favoritesContentMinHeight,
                             pageColumn.implicitHeight + 2 * Theme.spacing.xl)

            ColumnLayout {
                id: pageColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spacing.xl
                spacing: Theme.spacing.xl

                PageHeader {
                    Layout.fillWidth: true
                    title: qsTr("B站音乐区热门")
                }

                SkeletonList {
                    objectName: "homeLoadingState"
                    Layout.fillWidth: true
                    visible: root.viewState === "loading"
                    count: 6
                }

                MediaList {
                    id: mediaList
                    objectName: "homeMediaList"
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(
                                                Theme.sizes.mediaRowHeight,
                                                count * (Theme.sizes.mediaRowHeight
                                                         + Theme.spacing.xs))
                    visible: root.viewState === "ready"
                    enabled: !root._resolvePending
                    interactive: false
                    model: mediaViewModel
                    onMediaActivated: function(mediaId) { root.playMedia(mediaId) }
                }


                Label {
                    objectName: "homePlaybackError"
                    Layout.fillWidth: true
                    visible: root.playbackError.length > 0
                    text: root.playbackError
                    color: Theme.colors.error
                    font.pixelSize: Theme.fontSizes.caption
                    wrapMode: Text.Wrap
                }

                EmptyState {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.sizes.statePanelHeight
                    visible: root.viewState === "ready" && root.musicModel.length === 0
                    title: qsTr("No popular music")
                    message: qsTr("Try again later")
                }

                ErrorState {
                    objectName: "homeErrorState"
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.sizes.statePanelHeight
                    visible: root.viewState === "error"
                    message: root.errorMessage
                    onRetryRequested: root.loadMusic()
                }
            }
        }
    }
}
