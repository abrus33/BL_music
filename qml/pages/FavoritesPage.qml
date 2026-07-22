pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../components/Theme.js" as Theme

Item {
    id: root

    required property var authService
    required property var favoriteService
    required property var playlistService
    required property var playerController

    property string viewState: "foldersLoading"
    property string currentFolderTitle: ""
    property var currentMediaId: 0
    property var folderModel: []
    property var resourceModel: []
    property string errorMessage: ""
    property var _folderCache: ({})
    property real _overviewContentY: 0
    property bool _showingCachedData: false

    readonly property int stackIndex: viewState === "foldersLoading"
                                      || viewState === "foldersReady" ? 0 : 1
    readonly property bool folderOverviewVisible: stackIndex === 0
    readonly property bool folderDetailVisible: stackIndex === 1
    readonly property var _currentPlayingItem: {
        try {
            return JSON.parse(playlistService.currentItemJson || "{}")
        } catch (error) {
            return {}
        }
    }
    readonly property var currentPlayingItemId: _currentPlayingItem.id || 0

    function parseArray(json) {
        const parsed = JSON.parse(json)
        if (!Array.isArray(parsed))
            throw new Error("Expected a JSON array")
        return parsed
    }

    function rebuildMediaViewModel() {
        mediaViewModel.clear()
        for (let index = 0; index < resourceModel.length; ++index) {
            const item = resourceModel[index]
            mediaViewModel.append({
                mediaId: item.id,
                title: item.title || qsTr("Unknown title"),
                coverUrl: item.cover || item.pic || "",
                uploader: item.upper && item.upper.name ? item.upper.name : "",
                resourceTypeLabel: item.type === 2 ? qsTr("Video")
                                   : item.type === 12 ? qsTr("Audio")
                                   : item.type === 21 ? qsTr("Video collection")
                                                     : qsTr("Media"),
                duration: formatDuration(item.duration),
                invalid: item.attr !== undefined && item.attr !== 0
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

    function loadFolders() {
        if (!authService || !authService.isLoggedIn) {
            folderModel = []
            viewState = "foldersReady"
            return
        }
        errorMessage = ""
        viewState = "foldersLoading"
        favoriteService.loadFavoriteFolders(authService.userMid)
    }

    function openFolder(folder) {
        if (!folder)
            return

        const overviewFlickable = folderOverview.contentItem as Flickable
        _overviewContentY = overviewFlickable ? overviewFlickable.contentY : 0
        currentMediaId = folder.id || 0
        currentFolderTitle = folder.title || qsTr("Favorites")
        errorMessage = ""

        const cached = _folderCache[currentMediaId]
        if (cached !== undefined) {
            resourceModel = cached
            rebuildMediaViewModel()
            _showingCachedData = true
            viewState = resourceModel.length === 0 ? "empty" : "folderReady"
        } else {
            resourceModel = []
            rebuildMediaViewModel()
            _showingCachedData = false
            viewState = "folderLoading"
        }

        favoriteService.loadAllFavoriteResources(currentMediaId)
    }

    function goBack() {
        currentMediaId = 0
        viewState = "foldersReady"
        currentFolderTitle = ""
        Qt.callLater(function() {
            const overviewFlickable = folderOverview.contentItem as Flickable
            if (overviewFlickable)
                overviewFlickable.contentY = _overviewContentY
        })
    }

    function retry() {
        errorMessage = ""
        if (currentMediaId) {
            viewState = "folderLoading"
            favoriteService.loadAllFavoriteResources(currentMediaId)
        } else {
            loadFolders()
        }
    }

    function handleFoldersLoaded(upMid, success, foldersJson, error) {
        if (!authService || !authService.isLoggedIn
                || upMid !== authService.userMid)
            return

        if (!success) {
            errorMessage = error || qsTr("Could not load favorites")
            currentMediaId = 0
            viewState = "error"
            return
        }

        try {
            folderModel = parseArray(foldersJson)
            errorMessage = ""
            viewState = "foldersReady"
        } catch (parseError) {
            folderModel = []
            errorMessage = qsTr("Invalid favorites response")
            currentMediaId = 0
            viewState = "error"
        }
    }

    function handleResourcesLoaded(mediaId, success, mediasJson, error) {
        if (mediaId !== currentMediaId)
            return

        if (!success) {
            errorMessage = error || qsTr("Could not load folder")
            if (_showingCachedData) {
                viewState = resourceModel.length === 0 ? "empty" : "folderReady"
            } else {
                viewState = "error"
            }
            return
        }

        try {
            const resources = parseArray(mediasJson)
            resourceModel = resources
            rebuildMediaViewModel()
            _folderCache[mediaId] = resources
            _showingCachedData = false
            errorMessage = ""
            viewState = resources.length === 0 ? "empty" : "folderReady"
        } catch (parseError) {
            errorMessage = qsTr("Invalid folder response")
            if (_showingCachedData)
                viewState = resourceModel.length === 0 ? "empty" : "folderReady"
            else
                viewState = "error"
        }
    }

    function clearForLogout() {
        folderModel = []
        resourceModel = []
        rebuildMediaViewModel()
        _folderCache = ({})
        currentMediaId = 0
        currentFolderTitle = ""
        errorMessage = ""
        _overviewContentY = 0
        _showingCachedData = false
        viewState = "foldersReady"
    }

    Connections {
        target: root.authService
        function onLoginStateChanged() {
            if (!root.authService.isLoggedIn)
                root.clearForLogout()
            else
                root.loadFolders()
        }
    }

    Connections {
        target: root.favoriteService
        function onFavoriteFoldersLoaded(upMid, success, foldersJson, error) {
            root.handleFoldersLoaded(upMid, success, foldersJson, error)
        }
        function onAllFavoriteResourcesLoaded(mediaId, success, mediasJson, error) {
            root.handleResourcesLoaded(mediaId, success, mediasJson, error)
        }
    }

    Component.onCompleted: Qt.callLater(loadFolders)

    ListModel {
        id: mediaViewModel
    }

    StackLayout {
        id: viewStack
        objectName: "favoritesViewStack"
        anchors.fill: parent
        currentIndex: root.stackIndex

        ScrollView {
            id: folderOverview
            objectName: "folderOverview"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth
            contentHeight: overviewContent.height

            Item {
                id: overviewContent
                width: Math.max(folderOverview.availableWidth,
                                Theme.sizes.favoritesContentMinWidth)
                height: Math.max(Theme.sizes.favoritesContentMinHeight,
                                 overviewColumn.implicitHeight + 2 * Theme.spacing.xl)

                ColumnLayout {
                    id: overviewColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacing.xl
                    spacing: Theme.spacing.xl

                    PageHeader {
                        Layout.fillWidth: true
                        title: qsTr("Favorites")
                        subtitle: root.authService && root.authService.isLoggedIn
                                  ? qsTr("Your saved folders")
                                  : qsTr("Sign in to view favorites")
                    }

                    SkeletonList {
                        Layout.fillWidth: true
                        visible: root.viewState === "foldersLoading"
                        count: 5
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.viewState === "foldersReady"
                        spacing: Theme.spacing.sm

                        Repeater {
                            model: root.folderModel
                            delegate: FolderCard {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: Theme.sizes.favoriteFolderCardHeight
                                folderId: modelData.id || 0
                                title: modelData.title || qsTr("Untitled folder")
                                itemCount: modelData.media_count || 0
                                onOpened: root.openFolder(modelData)
                            }
                        }

                        EmptyState {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Theme.sizes.statePanelHeight
                            visible: root.folderModel.length === 0
                            title: root.authService && root.authService.isLoggedIn
                                   ? qsTr("No favorite folders") : qsTr("Sign in required")
                            message: root.authService && root.authService.isLoggedIn
                                     ? qsTr("Saved folders will appear here")
                                     : qsTr("Import your cookie from the Login page")
                        }
                    }
                }
            }
        }

        ScrollView {
            id: folderDetail
            objectName: "folderDetail"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth
            contentHeight: detailContent.height

            Item {
                id: detailContent
                width: Math.max(folderDetail.availableWidth,
                                Theme.sizes.favoritesContentMinWidth)
                height: Math.max(Theme.sizes.favoritesContentMinHeight,
                                 detailColumn.implicitHeight + 2 * Theme.spacing.xl)

                ColumnLayout {
                    id: detailColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacing.xl
                    spacing: Theme.spacing.xl

                    PageHeader {
                        Layout.fillWidth: true
                        title: root.currentFolderTitle || qsTr("Favorites")
                        subtitle: root.viewState === "folderReady"
                                  ? qsTr("%1 items").arg(root.resourceModel.length) : ""
                        showBack: true
                        onBackRequested: root.goBack()
                    }

                    SkeletonList {
                        Layout.fillWidth: true
                        visible: root.viewState === "folderLoading"
                        count: 7
                    }

                    MediaList {
                        id: mediaList
                        objectName: "favoriteMediaList"
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.max(
                                                    Theme.sizes.mediaRowHeight,
                                                    count * (Theme.sizes.mediaRowHeight
                                                             + Theme.spacing.xs))
                        visible: root.viewState === "folderReady"
                        interactive: false
                        model: mediaViewModel
                        currentMediaId: root.currentPlayingItemId
                        onMediaActivated: function(mediaId) {
                            root.playlistService.createPlaylist(
                                        JSON.stringify(root.resourceModel), mediaId)
                        }
                    }

                    EmptyState {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.sizes.statePanelHeight
                        visible: root.viewState === "empty"
                        title: qsTr("This folder is empty")
                        message: qsTr("Add media to see it here")
                    }

                    ErrorState {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.sizes.statePanelHeight
                        visible: root.viewState === "error"
                        message: root.errorMessage
                        onRetryRequested: root.retry()
                    }

                    Label {
                        Layout.fillWidth: true
                        visible: root.viewState === "folderReady"
                                 && root.errorMessage.length > 0
                        text: root.errorMessage
                        color: Theme.colors.error
                        font.pixelSize: Theme.fontSizes.caption
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
    }
}
