import QtQuick
import QtTest
import "../../qml/pages"

TestCase {
    id: testCase
    name: "FavoritesPage"
    when: windowShown
    width: 900
    height: 700

    Window {
        id: testWindow
        width: testCase.width
        height: testCase.height
        visible: true
        Item { id: stage; anchors.fill: parent }
    }

    QtObject {
        id: fakeAuth
        property bool isLoggedIn: true
        property var userMid: 9001
        signal loginStateChanged()
    }

    QtObject {
        id: fakeFavorite
        property int folderLoadCount: 0
        property var resourceLoadIds: []
        signal favoriteFoldersLoaded(var upMid, bool success, string foldersJson, string error)
        signal allFavoriteResourcesLoaded(var mediaId, bool success, string mediasJson, string error)
        function loadFavoriteFolders(userMid) { ++folderLoadCount }
        function loadAllFavoriteResources(mediaId) {
            const copy = resourceLoadIds.slice()
            copy.push(mediaId)
            resourceLoadIds = copy
        }
    }

    QtObject {
        id: fakePlaylist
        property string currentItemJson: "{}"
        property int createCount: 0
        property string lastItemsJson: ""
        property var lastStartId: 0
        signal currentItemChanged()
        function createPlaylist(itemsJson, startId) {
            ++createCount
            lastItemsJson = itemsJson
            lastStartId = startId
        }
        function setCurrentItem(json) {
            currentItemJson = json
            currentItemChanged()
        }
    }

    QtObject {
        id: fakePlayer
        property int stopCount: 0
        function stop() { ++stopCount }
    }

    Component {
        id: pageComponent
        FavoritesPage {
            width: 900
            height: 700
        }
    }

    property var page: null

    function init() {
        fakeAuth.isLoggedIn = true
        fakeAuth.userMid = 9001
        fakeFavorite.folderLoadCount = 0
        fakeFavorite.resourceLoadIds = []
        fakePlaylist.currentItemJson = "{}"
        fakePlaylist.createCount = 0
        fakePlaylist.lastItemsJson = ""
        fakePlaylist.lastStartId = 0
        fakePlayer.stopCount = 0
        page = createTemporaryObject(pageComponent, stage, {
            authService: fakeAuth,
            favoriteService: fakeFavorite,
            playlistService: fakePlaylist,
            playerController: fakePlayer
        })
        verify(page !== null)
    }

    function cleanup() { page = null }

    function folder(id, title) {
        return { id: id, title: title, media_count: 1 }
    }

    function media(id, title) {
        return { id: id, title: title, duration: 61, upper: { name: "Author" }, attr: 0 }
    }

    function test_viewStateHasSixValuesAndViewsAreStructurallyExclusive() {
        const overview = findChild(page, "folderOverview")
        const detail = findChild(page, "folderDetail")
        const stack = findChild(page, "favoritesViewStack")
        verify(overview !== null)
        verify(detail !== null)
        verify(stack !== null)
        compare(overview.parent, stack)
        compare(detail.parent, stack)

        const overviewStates = ["foldersLoading", "foldersReady"]
        for (let i = 0; i < overviewStates.length; ++i) {
            page.viewState = overviewStates[i]
            compare(page.stackIndex, 0)
            verify(page.folderOverviewVisible)
            verify(!page.folderDetailVisible)
        }
        const detailStates = ["folderLoading", "folderReady", "empty", "error"]
        for (let j = 0; j < detailStates.length; ++j) {
            page.viewState = detailStates[j]
            compare(page.stackIndex, 1)
            verify(!page.folderOverviewVisible)
            verify(page.folderDetailVisible)
        }
    }

    function test_openFolderShowsOnlyDetail() {
        page.folderModel = [folder(11, "Favorites A")]
        page.viewState = "foldersReady"
        page.openFolder(page.folderModel[0])
        compare(page.currentMediaId, 11)
        compare(page.stackIndex, 1)
        compare(page.viewState, "folderLoading")
        verify(!page.folderOverviewVisible)
        verify(page.folderDetailVisible)
        compare(fakeFavorite.resourceLoadIds.length, 1)
        compare(fakeFavorite.resourceLoadIds[0], 11)
    }

    function test_oldFolderResultIsIgnored() {
        page.currentMediaId = 22
        page.resourceModel = []
        page.handleResourcesLoaded(11, true, JSON.stringify([media(1, "Old")]), "")
        compare(page.resourceModel.length, 0)
    }

    function test_rapidFolderResultsStayWithRequestedFolder() {
        page.openFolder(folder(11, "A"))
        page.openFolder(folder(22, "B"))
        page.handleResourcesLoaded(11, true, JSON.stringify([media(1, "A item")]), "")
        compare(page.resourceModel.length, 0)
        page.handleResourcesLoaded(22, true, JSON.stringify([media(2, "B item")]), "")
        compare(page.resourceModel.length, 1)
        compare(page.resourceModel[0].id, 2)
        compare(page.currentMediaId, 22)
    }

    function test_cachedFolderShowsImmediatelyAndRefreshesInBackground() {
        page.openFolder(folder(11, "A"))
        page.handleResourcesLoaded(11, true, JSON.stringify([media(1, "Cached")]), "")
        page.goBack()
        const callsBefore = fakeFavorite.resourceLoadIds.length

        page.openFolder(folder(11, "A"))

        compare(page.viewState, "folderReady")
        compare(page.resourceModel.length, 1)
        compare(page.resourceModel[0].title, "Cached")
        compare(fakeFavorite.resourceLoadIds.length, callsBefore + 1)
    }

    function test_cachedRefreshFailureKeepsDataAndShowsNonBlockingError() {
        page.openFolder(folder(11, "A"))
        page.handleResourcesLoaded(11, true, JSON.stringify([media(1, "Cached")]), "")
        page.goBack()
        page.openFolder(folder(11, "A"))

        page.handleResourcesLoaded(11, false, "", "offline")

        compare(page.viewState, "folderReady")
        compare(page.resourceModel.length, 1)
        compare(page.errorMessage, "offline")
    }

    function test_goBackInvalidatesPendingDetailResult() {
        page.openFolder(folder(77, "Pending"))
        compare(page.viewState, "folderLoading")

        page.goBack()
        fakeFavorite.allFavoriteResourcesLoaded(
                    77, true, JSON.stringify([media(700, "Late")]), "")

        compare(page.currentMediaId, 0)
        compare(page.stackIndex, 0)
        compare(page.viewState, "foldersReady")
        compare(page.resourceModel.length, 0)
    }

    function test_folderResultBelongsToCurrentAccount() {
        fakeAuth.userMid = 1
        fakeAuth.loginStateChanged()

        fakeAuth.isLoggedIn = false
        fakeAuth.loginStateChanged()
        fakeAuth.userMid = 2
        fakeAuth.isLoggedIn = true
        fakeAuth.loginStateChanged()

        fakeFavorite.favoriteFoldersLoaded(
                    1, true, JSON.stringify([folder(11, "Old account")]), "")
        compare(page.folderModel.length, 0)

        fakeFavorite.favoriteFoldersLoaded(
                    2, true, JSON.stringify([folder(22, "Current account")]), "")
        compare(page.folderModel.length, 1)
        compare(page.folderModel[0].id, 22)
        compare(page.viewState, "foldersReady")
    }

    function test_folderPayloadMustBeJsonArray() {
        const invalidPayloads = ["{}", "null"]
        for (let index = 0; index < invalidPayloads.length; ++index) {
            page.folderModel = []
            page.errorMessage = ""
            fakeFavorite.favoriteFoldersLoaded(
                        fakeAuth.userMid, true, invalidPayloads[index], "")
            compare(page.viewState, "error")
            compare(page.folderModel.length, 0)
            verify(page.errorMessage.length > 0)
        }
    }

    function test_uncachedResourcePayloadMustBeJsonArray() {
        page.openFolder(folder(88, "Invalid"))

        page.handleResourcesLoaded(88, true, "{}", "")

        compare(page.viewState, "error")
        compare(page.resourceModel.length, 0)
        verify(page.errorMessage.length > 0)
        compare(page._folderCache[88], undefined)
    }

    function test_invalidRefreshKeepsEmptyCacheVisible() {
        page.openFolder(folder(99, "Empty cached"))
        page.handleResourcesLoaded(99, true, "[]", "")
        page.goBack()
        page.openFolder(folder(99, "Empty cached"))
        compare(page.viewState, "empty")

        page.handleResourcesLoaded(99, true, "null", "")

        compare(page.viewState, "empty")
        compare(page.resourceModel.length, 0)
        verify(Array.isArray(page._folderCache[99]))
        compare(page._folderCache[99].length, 0)
        verify(page.errorMessage.length > 0)
    }

    function test_emptyFolderAndRetry() {
        page.openFolder(folder(33, "Empty"))
        page.handleResourcesLoaded(33, true, "[]", "")
        compare(page.viewState, "empty")

        page.handleResourcesLoaded(33, false, "", "network")
        compare(page.viewState, "error")
        compare(page.errorMessage, "network")
        const before = fakeFavorite.resourceLoadIds.length
        page.retry()
        compare(page.viewState, "folderLoading")
        compare(fakeFavorite.resourceLoadIds.length, before + 1)
        compare(fakeFavorite.resourceLoadIds[before], 33)
    }

    function test_goBackRestoresOverviewScrollWithoutStoppingPlayback() {
        page.viewState = "foldersReady"
        const overview = findChild(page, "folderOverview")
        verify(overview !== null)
        overview.contentItem.contentY = 137
        page.openFolder(folder(44, "Scroll"))
        overview.contentItem.contentY = 0

        page.goBack()
        wait(0)

        compare(page.stackIndex, 0)
        compare(overview.contentItem.contentY, 137)
        compare(fakePlayer.stopCount, 0)
    }

    function test_logoutClearsModelsCacheAndSelection() {
        page.folderModel = [folder(11, "A")]
        page.openFolder(page.folderModel[0])
        page.handleResourcesLoaded(11, true, JSON.stringify([media(1, "Cached")]), "")
        verify(page._folderCache[11] !== undefined)

        fakeAuth.isLoggedIn = false
        fakeAuth.loginStateChanged()

        compare(page.folderModel.length, 0)
        compare(page.resourceModel.length, 0)
        compare(Object.keys(page._folderCache).length, 0)
        compare(page.currentMediaId, 0)
    }

    function test_mediaActivationCreatesPlaylistWithRawItemsAndMediaId() {
        const items = [media(101, "First"), media(202, "Second")]
        page.openFolder(folder(55, "Playable"))
        page.handleResourcesLoaded(55, true, JSON.stringify(items), "")
        const list = findChild(page, "favoriteMediaList")
        verify(list !== null)

        list.mediaActivated(202)

        compare(fakePlaylist.createCount, 1)
        compare(fakePlaylist.lastStartId, 202)
        compare(JSON.parse(fakePlaylist.lastItemsJson)[1].title, "Second")
    }

    function test_currentItemChangeMarksOnlyMatchingMediaRowCurrent() {
        page.openFolder(folder(55, "Playable"))
        page.handleResourcesLoaded(55, true,
                                   JSON.stringify([media(101, "First"), media(202, "Second")]), "")
        const list = findChild(page, "favoriteMediaList")
        verify(list !== null)
        tryCompare(list, "count", 2)

        fakePlaylist.setCurrentItem('{"id":202}')
        tryCompare(list, "currentMediaId", 202)
        list.width = 900
        list.height = 2 * 64
        list.forceLayout()
        tryVerify(function() {
            return list.itemAtIndex(0) !== null && list.itemAtIndex(1) !== null
        })
        const first = list.itemAtIndex(0)
        const second = list.itemAtIndex(1)
        verify(first !== null)
        verify(second !== null)
        verify(!first.current)
        verify(second.current)
    }

    function test_resourceViewModelCarriesCompleteDisplayMetadata() {
        page.openFolder(folder(55, "Metadata"))
        page.handleResourcesLoaded(55, true, JSON.stringify([{
            id: 303,
            title: "Complete item",
            cover: "https://example.test/cover.jpg",
            duration: 125,
            type: 2,
            attr: 1,
            upper: { name: "Uploader" }
        }]), "")

        const list = findChild(page, "favoriteMediaList")
        verify(list !== null)
        compare(list.count, 1)
        const row = list.model.get(0)
        compare(row.coverUrl, "https://example.test/cover.jpg")
        compare(row.uploader, "Uploader")
        compare(row.resourceTypeLabel, "Video")
        compare(row.duration, "02:05")
        verify(row.invalid)
    }

    function test_videoCollectionHasSpecificResourceTypeLabel() {
        page.openFolder(folder(56, "Collections"))
        page.handleResourcesLoaded(56, true, JSON.stringify([{
            id: 304,
            title: "Collected series",
            duration: 0,
            type: 21,
            attr: 0,
            upper: { name: "Curator" }
        }]), "")

        const list = findChild(page, "favoriteMediaList")
        verify(list !== null)
        compare(list.count, 1)
        compare(list.model.get(0).resourceTypeLabel, "Video collection")
    }
}
