import QtQuick
import QtTest
import "../../qml/components"
import "../../qml/components/Theme.js" as Theme
import "../../qml/pages"

TestCase {
    id: testCase

    name: "SharedComponents"
    when: windowShown

    width: 720
    height: 560

    Window {
        id: testWindow
        width: testCase.width
        height: testCase.height
        visible: true

        Item {
            id: stage
            anchors.fill: parent
        }
    }

    Component {
        id: folderCardComponent

        FolderCard {
            width: 280
            folderId: 42
            title: "Daily mix"
            itemCount: 7
        }
    }

    Component {
        id: appButtonComponent

        AppButton {
            width: 180
            height: 40
            text: "Action"
            checkable: true
        }
    }

    Component {
        id: mediaItemComponent

        MediaListItem {
            width: 480
            mediaId: "BV-invalid"
            title: "Unavailable track"
            uploader: "Creator"
            resourceTypeLabel: "Video"
            duration: "03:21"
        }
    }

    Component {
        id: pageHeaderComponent

        PageHeader {
            width: 520
            title: "Favorites"
            subtitle: "Saved folders"
        }
    }

    Component {
        id: errorStateComponent

        ErrorState {
            width: 420
            height: 220
            message: "Network unavailable"
        }
    }

    Component {
        id: emptyStateComponent

        EmptyState {
            width: 420
            height: 220
            title: "No favorites"
            message: "Save media to see it here"
        }
    }

    Component {
        id: skeletonListComponent

        SkeletonList {
            width: 480
            count: 100
        }
    }

    Component {
        id: fakeMusicServiceComponent

        QtObject {
            property int loadCount: 0
            property int lastPage: -1
            property int lastPageSize: -1
            signal musicRankLoaded(bool success, string json, string error)
            function loadMusicRank(page, pageSize) {
                ++loadCount
                lastPage = page
                lastPageSize = pageSize
            }
        }
    }

    Component {
        id: fakeMediaResolverComponent

        QtObject {
            property int resolveCount: 0
            property int taggedResolveCount: 0
            property var lastId
            property int lastType: 0
            property string lastOwnerToken: ""
            signal mediaResolved(bool success, string url, string title,
                                 string cover, int duration, string error)
            signal mediaResolvedForOwner(string ownerToken, bool success,
                                         string url, string title, string cover,
                                         int duration, string error)
            function resolve(mediaId, mediaType) {
                ++resolveCount
                lastId = mediaId
                lastType = mediaType
            }
            function resolveForOwner(ownerToken, mediaId, mediaType) {
                ++taggedResolveCount
                lastOwnerToken = ownerToken
                lastId = mediaId
                lastType = mediaType
            }
        }
    }

    Component {
        id: fakePlayerControllerComponent

        QtObject {
            property string mediaTitle: ""
            property string mediaCover: ""
            property string source: ""
            property int playCount: 0
            function play() { ++playCount }
        }
    }

    Component {
        id: fakeAuthServiceComponent

        QtObject {
            property bool isLoggedIn: false
            property string userName: "Test user"
            property string qrImageUrl: ""
            property string qrStatus: ""
            property bool qrLoginActive: false
            property int importCount: 0
            property int logoutCount: 0
            property int startQrCount: 0
            property int stopQrCount: 0
            property string lastImportedCookie: ""
            signal loginChecked(bool success, string userName)
            signal loginStateChanged()
            function importCookie(cookie) {
                ++importCount
                lastImportedCookie = cookie
            }
            function logout() { ++logoutCount }
            function startQrLogin() { ++startQrCount }
            function stopQrLogin() { ++stopQrCount }
        }
    }

    Component {
        id: homePageComponent

        HomePage {
            width: 640
            height: 480
        }
    }

    Component {
        id: loginPageComponent

        LoginPage {
            width: 640
            height: 480
        }
    }

    function test_folderCardOpenedCarriesFolderId() {
        const card = createTemporaryObject(folderCardComponent, stage)
        verify(card !== null)
        const spy = signalSpy.createObject(card, {
            target: card,
            signalName: "opened"
        })

        verify(card.width >= 40)
        verify(card.height >= 40)
        mouseClick(card, card.width / 2, card.height / 2)

        compare(spy.count, 1)
        compare(spy.signalArguments[0][0], 42)
    }

    function test_appButtonExposesDistinctInteractionStatesAndKeyboardFocus() {
        const button = createTemporaryObject(appButtonComponent, stage)
        verify(button !== null)
        const background = findChild(button, "appButtonBackground")
        verify(background !== null)

        testWindow.requestActivate()
        tryVerify(function() { return testWindow.active })
        const normalColor = background.color
        verify(button.colorForState(true, false, false, true) !== normalColor,
               "hover color must differ")
        verify(button.colorForState(true, true, false, false) !== normalColor,
               "pressed color must differ")

        button.checked = true
        tryCompare(background, "color", button.checkedColor)
        verify(button.checkedColor !== button.bgColor,
               "checked color must differ from default")
        button.enabled = false
        tryCompare(background, "color", Theme.colors.controlDisabled)

        button.enabled = true
        button.forceActiveFocus()
        tryVerify(function() { return button.activeFocus })
        verify(background.border.width > 0, "keyboard focus ring must be visible")
        compare(background.border.color, Theme.colors.borderFocus)
    }

    function test_appButtonFlatModeRetainsStateFeedback() {
        const button = createTemporaryObject(appButtonComponent, stage, {
            flatButton: true
        })
        verify(button !== null)
        const background = findChild(button, "appButtonBackground")
        compare(background.color, Theme.colors.transparent)
        button.checked = true
        verify(background.color !== Theme.colors.transparent)
    }

    function test_invalidMediaCannotActivateWithMouseOrKeyboard() {
        const item = createTemporaryObject(mediaItemComponent, stage)
        verify(item !== null)
        const spy = signalSpy.createObject(item, {
            target: item,
            signalName: "activated"
        })

        verify(item.width >= 40)
        verify(item.height >= 40)
        testWindow.requestActivate()
        tryVerify(function() { return testWindow.active })
        item.forceActiveFocus()
        tryVerify(function() { return item.activeFocus })
        item.invalid = true
        mouseClick(item, item.width / 2, item.height / 2)
        keyClick(Qt.Key_Return)
        keyClick(Qt.Key_Space)

        compare(spy.count, 0)
    }

    function test_validMediaActivatesOnceFromKeyboard() {
        const item = createTemporaryObject(mediaItemComponent, stage)
        verify(item !== null)
        const spy = signalSpy.createObject(item, {
            target: item,
            signalName: "activated"
        })

        testWindow.requestActivate()
        tryVerify(function() { return testWindow.active })
        item.forceActiveFocus()
        tryVerify(function() { return item.activeFocus })
        keyClick(Qt.Key_Return)

        compare(spy.count, 1)
        compare(spy.signalArguments[0][0], "BV-invalid")
    }

    function test_invalidMediaExposesDisabledAccessibleState() {
        const item = createTemporaryObject(mediaItemComponent, stage, {
            invalid: true
        })
        verify(item !== null)

        verify(!item.enabled)
        compare(item.Accessible.description, "Unavailable")
    }

    function test_mediaBackgroundUsesTransparentThemeToken() {
        const item = createTemporaryObject(mediaItemComponent, stage)
        verify(item !== null)
        verify(Theme.colors.transparent !== undefined)
        const background = findChild(item, "mediaBackground")
        verify(background !== null)
        compare(background.color, Theme.colors.transparent)
    }

    function test_mediaItemRendersCoverUploaderTypeAndFormattedDuration() {
        const item = createTemporaryObject(mediaItemComponent, stage, {
            coverUrl: "https://example.test/cover.jpg",
            uploader: "Uploader",
            resourceTypeLabel: "Video",
            duration: "02:05"
        })
        verify(item !== null)
        compare(findChild(item, "mediaCover").coverUrl,
                "https://example.test/cover.jpg")
        compare(findChild(item, "mediaUploaderLabel").text, "Uploader")
        compare(findChild(item, "mediaTypeLabel").text, "Video")
        compare(findChild(item, "mediaDurationLabel").text, "02:05")
    }

    function test_hiddenBackButtonDoesNotOccupySpace() {
        const withBack = createTemporaryObject(pageHeaderComponent, stage, {
            showBack: true
        })
        const withoutBack = createTemporaryObject(pageHeaderComponent, stage, {
            showBack: false
        })
        verify(withBack !== null)
        verify(withoutBack !== null)

        const visibleButton = findChild(withBack, "backButton")
        const hiddenButton = findChild(withoutBack, "backButton")
        const shiftedTitle = findChild(withBack, "titleBlock")
        const unshiftedTitle = findChild(withoutBack, "titleBlock")
        verify(visibleButton !== null)
        verify(hiddenButton !== null)
        verify(shiftedTitle !== null)
        verify(unshiftedTitle !== null)
        verify(visibleButton.width >= 40)
        verify(visibleButton.height >= 40)
        verify(visibleButton.visible)
        verify(!hiddenButton.visible)
        verify(unshiftedTitle.x < shiftedTitle.x)
    }

    function test_errorRetryEmitsExactlyOnce() {
        const errorState = createTemporaryObject(errorStateComponent, stage)
        verify(errorState !== null)
        const retryButton = findChild(errorState, "retryButton")
        verify(retryButton !== null)
        verify(retryButton.width >= 40)
        verify(retryButton.height >= 40)
        const spy = signalSpy.createObject(errorState, {
            target: errorState,
            signalName: "retryRequested"
        })

        mouseClick(retryButton, retryButton.width / 2, retryButton.height / 2)

        compare(spy.count, 1)
    }

    function test_emptyStateAggregatesAccessibleTextOnce() {
        const emptyState = createTemporaryObject(emptyStateComponent, stage)
        verify(emptyState !== null)
        const titleLabel = findChild(emptyState, "emptyTitleLabel")
        const messageLabel = findChild(emptyState, "emptyMessageLabel")
        verify(titleLabel !== null)
        verify(messageLabel !== null)
        verify(titleLabel.Accessible.ignored)
        verify(messageLabel.Accessible.ignored)
    }

    function test_errorStateAggregatesAccessibleTextOnce() {
        const errorState = createTemporaryObject(errorStateComponent, stage)
        verify(errorState !== null)
        const messageLabel = findChild(errorState, "errorMessageLabel")
        verify(messageLabel !== null)
        verify(messageLabel.Accessible.ignored)
    }

    function test_skeletonCountIsCapped() {
        const skeleton = createTemporaryObject(skeletonListComponent, stage)
        verify(skeleton !== null)
        compare(skeleton.effectiveCount, 12)
    }

    function test_homePageUsesInjectedServicesAndResolvesClickedMedia() {
        const musicService = createTemporaryObject(fakeMusicServiceComponent, stage)
        const mediaResolver = createTemporaryObject(fakeMediaResolverComponent, stage)
        const playerController = createTemporaryObject(fakePlayerControllerComponent, stage)
        verify(musicService !== null)
        verify(mediaResolver !== null)
        verify(playerController !== null)

        const page = createTemporaryObject(homePageComponent, stage, {
            musicService: musicService,
            mediaResolver: mediaResolver,
            playerController: playerController
        })
        verify(page !== null)
        tryCompare(musicService, "loadCount", 1)
        compare(musicService.lastPage, 1)
        compare(musicService.lastPageSize, 6)

        musicService.musicRankLoaded(true, JSON.stringify([{
            id: 987,
            title: "Injected track",
            artist: "Injected artist",
            cover: "cover.jpg",
            duration: 125
        }]), "")

        const mediaList = findChild(page, "homeMediaList")
        verify(mediaList !== null)
        tryCompare(mediaList, "count", 1)
        tryVerify(function() { return mediaList.itemAtIndex(0) !== null })
        const item = mediaList.itemAtIndex(0)
        mouseClick(item, item.width / 2, item.height / 2)

        compare(mediaResolver.resolveCount, 0)
        compare(mediaResolver.taggedResolveCount, 1)
        compare(mediaResolver.lastId, 987)
        compare(mediaResolver.lastType, 12)
        compare(playerController.mediaTitle, "Injected track")
        compare(playerController.mediaCover, "cover.jpg")

        mediaResolver.mediaResolvedForOwner(page.resolverOwnerToken, true,
                                            "https://media.test/track.m4a",
                                            "", "", 0, "")
        compare(playerController.source, "https://media.test/track.m4a")
        compare(playerController.playCount, 1)

        mediaResolver.mediaResolvedForOwner(page.resolverOwnerToken, true,
                                            "https://media.test/stale.m4a",
                                            "", "", 0, "")
        compare(playerController.source, "https://media.test/track.m4a")
        compare(playerController.playCount, 1)
    }

    function test_homePagePreservesLoadErrorsAndRetriesExactRequest() {
        const musicService = createTemporaryObject(fakeMusicServiceComponent, stage)
        const mediaResolver = createTemporaryObject(fakeMediaResolverComponent, stage)
        const playerController = createTemporaryObject(fakePlayerControllerComponent, stage)
        const page = createTemporaryObject(homePageComponent, stage, {
            musicService: musicService,
            mediaResolver: mediaResolver,
            playerController: playerController
        })
        verify(page !== null)
        tryCompare(musicService, "loadCount", 1)

        musicService.musicRankLoaded(false, "", "Service unavailable")
        compare(page.viewState, "error")
        compare(page.errorMessage, "Service unavailable")
        const errorState = findChild(page, "homeErrorState")
        const retryButton = findChild(errorState, "retryButton")
        verify(errorState.visible)
        mouseClick(retryButton, retryButton.width / 2, retryButton.height / 2)
        compare(musicService.loadCount, 2)
        compare(musicService.lastPage, 1)
        compare(musicService.lastPageSize, 6)

        musicService.musicRankLoaded(true, "{not-an-array}", "")
        compare(page.viewState, "error")
        compare(page.errorMessage, "Invalid music response")
    }

    function test_homePageSerializesSingleTrackResolveAndRecoversFromFailure() {
        const musicService = createTemporaryObject(fakeMusicServiceComponent, stage)
        const mediaResolver = createTemporaryObject(fakeMediaResolverComponent, stage)
        const playerController = createTemporaryObject(fakePlayerControllerComponent, stage)
        const page = createTemporaryObject(homePageComponent, stage, {
            musicService: musicService,
            mediaResolver: mediaResolver,
            playerController: playerController
        })
        verify(page !== null)
        musicService.musicRankLoaded(true, JSON.stringify([
            { id: 1, title: "First", cover: "first.jpg" },
            { id: 2, title: "Second", cover: "second.jpg" }
        ]), "")

        page.playMedia(1)
        page.playMedia(2)
        compare(mediaResolver.resolveCount, 0)
        compare(mediaResolver.taggedResolveCount, 1)
        compare(mediaResolver.lastId, 1)

        mediaResolver.mediaResolvedForOwner(page.resolverOwnerToken, false,
                                            "", "", "", 0, "Resolve failed")
        compare(playerController.playCount, 0)
        compare(page.playbackError, "Resolve failed")

        page.playMedia(2)
        compare(mediaResolver.resolveCount, 0)
        compare(mediaResolver.taggedResolveCount, 2)
        compare(mediaResolver.lastId, 2)
        mediaResolver.mediaResolvedForOwner(page.resolverOwnerToken, true,
                                            "https://media.test/second.m4a",
                                            "", "", 0, "")
        compare(playerController.source, "https://media.test/second.m4a")
        compare(playerController.playCount, 1)
        compare(page.playbackError, "")
    }

    function test_homePageIgnoresExternalLegacyAndWrongOwnerCompletions() {
        const musicService = createTemporaryObject(fakeMusicServiceComponent, stage)
        const mediaResolver = createTemporaryObject(fakeMediaResolverComponent, stage)
        const playerController = createTemporaryObject(fakePlayerControllerComponent, stage)
        const page = createTemporaryObject(homePageComponent, stage, {
            musicService: musicService,
            mediaResolver: mediaResolver,
            playerController: playerController
        })
        verify(page !== null)
        musicService.musicRankLoaded(true, JSON.stringify([
            { id: 77, title: "Home track", cover: "home.jpg" }
        ]), "")

        page.playMedia(77)
        compare(mediaResolver.taggedResolveCount, 1)
        verify(mediaResolver.lastOwnerToken.length > 0)

        mediaResolver.mediaResolved(true, "https://media.test/playlist.m4a",
                                    "", "", 0, "")
        compare(playerController.source, "")
        compare(playerController.playCount, 0)
        verify(page._resolvePending)

        mediaResolver.mediaResolvedForOwner("another-owner", true,
                                            "https://media.test/other.m4a",
                                            "", "", 0, "")
        compare(playerController.source, "")
        compare(playerController.playCount, 0)
        verify(page._resolvePending)

        mediaResolver.mediaResolvedForOwner(page.resolverOwnerToken, true,
                                            "https://media.test/home.m4a",
                                            "", "", 0, "")
        compare(playerController.source, "https://media.test/home.m4a")
        compare(playerController.playCount, 1)
        verify(!page._resolvePending)
    }

    function test_loginPageUsesInjectedServiceAndShowsOnlySelectedForm() {
        const authService = createTemporaryObject(fakeAuthServiceComponent, stage)
        verify(authService !== null)
        const page = createTemporaryObject(loginPageComponent, stage, {
            authService: authService
        })
        verify(page !== null)

        const cookieForm = findChild(page, "cookieLoginForm")
        const qrForm = findChild(page, "qrLoginForm")
        const cookieButton = findChild(page, "cookieModeButton")
        const qrButton = findChild(page, "qrModeButton")
        verify(cookieForm !== null)
        verify(qrForm !== null)
        verify(cookieButton !== null)
        verify(qrButton !== null)
        verify(cookieButton.checkable)
        verify(qrButton.checkable)
        verify(cookieButton.checked)
        verify(!qrButton.checked)
        verify(cookieForm.visible)
        verify(!qrForm.visible)

        mouseClick(qrButton, qrButton.width / 2, qrButton.height / 2)
        verify(!cookieForm.visible)
        verify(qrForm.visible)
        verify(!cookieButton.checked)
        verify(qrButton.checked)

        mouseClick(cookieButton, cookieButton.width / 2, cookieButton.height / 2)
        verify(cookieForm.visible)
        verify(!qrForm.visible)
        verify(cookieButton.checked)
        verify(!qrButton.checked)
    }

    function test_loginPageCookieActionsAndLogoutUseInjectedService() {
        const authService = createTemporaryObject(fakeAuthServiceComponent, stage)
        const page = createTemporaryObject(loginPageComponent, stage, {
            authService: authService
        })
        verify(page !== null)
        const input = findChild(page, "cookieInput")
        const importButton = findChild(page, "importCookieButton")
        const visibilityButton = findChild(page, "cookieVisibilityButton")
        verify(input !== null)
        verify(importButton !== null)
        verify(visibilityButton !== null)
        compare(input.echoMode, TextInput.Password)

        input.text = "  SESSDATA=test; bili_jct=csrf  "
        mouseClick(visibilityButton, visibilityButton.width / 2,
                   visibilityButton.height / 2)
        compare(input.echoMode, TextInput.Normal)
        mouseClick(importButton, importButton.width / 2, importButton.height / 2)
        compare(authService.importCount, 1)
        compare(authService.lastImportedCookie, "SESSDATA=test; bili_jct=csrf")
        compare(input.text, "")

        authService.isLoggedIn = true
        const logoutButton = findChild(page, "logoutButton")
        verify(logoutButton !== null)
        mouseClick(logoutButton, logoutButton.width / 2, logoutButton.height / 2)
        compare(authService.logoutCount, 1)
    }

    function test_loginPageQrActionsAndRenderedStates() {
        const authService = createTemporaryObject(fakeAuthServiceComponent, stage)
        const page = createTemporaryObject(loginPageComponent, stage, {
            authService: authService
        })
        verify(page !== null)
        const qrButton = findChild(page, "qrModeButton")
        mouseClick(qrButton, qrButton.width / 2, qrButton.height / 2)
        const startButton = findChild(page, "qrStartButton")
        const stopButton = findChild(page, "qrStopButton")
        const skeleton = findChild(page, "qrGeneratingState")
        const visual = findChild(page, "qrVisualState")
        const errorState = findChild(page, "qrErrorState")
        const statusLabel = findChild(page, "qrStatusLabel")
        verify(startButton !== null)
        verify(stopButton !== null)
        verify(skeleton !== null)
        verify(visual !== null)
        verify(errorState !== null)

        mouseClick(startButton, startButton.width / 2, startButton.height / 2)
        compare(authService.startQrCount, 1)
        authService.qrLoginActive = true
        compare(page.qrState, "generating")
        verify(skeleton.visible)
        verify(!visual.visible)

        authService.qrImageUrl = "data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw=="
        authService.qrStatus = "请使用B站APP扫描二维码"
        compare(page.qrState, "waitingScan")
        verify(visual.visible)
        compare(statusLabel.text, "Waiting for scan")
        authService.qrStatus = "已扫码，请在手机上确认登录"
        compare(page.qrState, "waitingConfirm")
        compare(statusLabel.text, "Waiting for confirmation")
        authService.qrStatus = "扫码登录成功！"
        compare(page.qrState, "success")
        compare(statusLabel.text, "Login successful")
        authService.qrStatus = "二维码已过期，点击刷新重新生成"
        compare(page.qrState, "expired")
        compare(statusLabel.text, "QR code expired")

        authService.qrLoginActive = true
        mouseClick(stopButton, stopButton.width / 2, stopButton.height / 2)
        compare(authService.stopQrCount, 1)
        authService.qrStatus = "网络错误: timeout"
        compare(page.qrState, "networkError")
        verify(errorState.visible)
        verify(!statusLabel.visible)
        const retryButton = findChild(errorState, "retryButton")
        mouseClick(retryButton, retryButton.width / 2, retryButton.height / 2)
        compare(authService.startQrCount, 2)
    }

    function test_loginPageDistinguishesAccountAndQrStates() {
        const authService = createTemporaryObject(fakeAuthServiceComponent, stage)
        const page = createTemporaryObject(loginPageComponent, stage, {
            authService: authService
        })
        verify(authService !== null)
        verify(page !== null)

        const forms = findChild(page, "loginForms")
        const accountPanel = findChild(page, "loggedInPanel")
        verify(forms !== null)
        verify(accountPanel !== null)
        authService.isLoggedIn = true
        verify(!forms.visible)
        verify(accountPanel.visible)

        authService.isLoggedIn = false
        authService.qrLoginActive = true
        authService.qrStatus = ""
        compare(page.qrState, "generating")
        authService.qrImageUrl = "data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw=="
        authService.qrStatus = "请使用B站APP扫描二维码"
        compare(page.qrState, "waitingScan")
        authService.qrStatus = "已扫码，请在手机上确认登录"
        compare(page.qrState, "waitingConfirm")
        authService.qrStatus = "扫码登录成功！"
        compare(page.qrState, "success")
        authService.qrStatus = "二维码已过期，点击刷新重新生成"
        compare(page.qrState, "expired")
        authService.qrStatus = "网络错误: timeout"
        compare(page.qrState, "networkError")
    }

    Component {
        id: signalSpy

        SignalSpy {}
    }
}
