pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../components"
import "../components/Theme.js" as Theme

Item {
    id: root

    required property var authService

    property int loginMode: 0
    property bool cookieVisible: false
    property string loginResult: ""
    readonly property string qrState: classifyQrState()

    function classifyQrState() {
        const status = authService.qrStatus || ""
        if (status.includes("成功"))
            return "success"
        if (status.includes("过期"))
            return "expired"
        if (status.includes("网络") || status.includes("失败"))
            return "networkError"
        if (status.includes("确认") || status.includes("已扫码"))
            return "waitingConfirm"
        if (status.includes("扫描") || status.includes("扫码"))
            return "waitingScan"
        if (authService.qrLoginActive && !authService.qrImageUrl)
            return "generating"
        return "idle"
    }

    function qrStatusText() {
        switch (qrState) {
        case "generating": return qsTr("Generating QR code…")
        case "waitingScan": return qsTr("Waiting for scan")
        case "waitingConfirm": return qsTr("Waiting for confirmation")
        case "success": return qsTr("Login successful")
        case "expired": return qsTr("QR code expired")
        case "networkError": return authService.qrStatus || qsTr("Network error")
        default: return qsTr("Generate a QR code to sign in")
        }
    }

    function qrStatusColor() {
        if (qrState === "success")
            return Theme.colors.accent
        if (qrState === "expired" || qrState === "networkError")
            return Theme.colors.error
        return Theme.colors.textTertiary
    }

    Connections {
        target: root.authService

        function onLoginChecked(success, userName) {
            root.loginResult = success
                    ? qsTr("Login successful. Welcome, %1").arg(userName)
                    : qsTr("Login failed. Check whether the cookie is valid.")
        }
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
                    title: qsTr("Login")
                    subtitle: root.authService.isLoggedIn
                              ? qsTr("Your account is connected")
                              : qsTr("Sign in to sync favorites and personalized content")
                }

                Rectangle {
                    objectName: "loggedInPanel"
                    Layout.fillWidth: true
                    Layout.preferredHeight: accountLayout.implicitHeight + 2 * Theme.spacing.lg
                    visible: root.authService.isLoggedIn
                    color: Theme.colors.surfaceRaised
                    radius: Theme.radius.card

                    RowLayout {
                        id: accountLayout
                        anchors.fill: parent
                        anchors.margins: Theme.spacing.lg
                        spacing: Theme.spacing.md

                        AppIcon {
                            Layout.preferredWidth: Theme.sizes.loginAccountIcon
                            Layout.preferredHeight: Theme.sizes.loginAccountIcon
                            source: "qrc:/qt/qml/cursor_music/icon/log-in.svg"
                            iconSize: Theme.sizes.loginAccountIcon
                            iconColor: Theme.colors.accent
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacing.xs

                            Label {
                                Layout.fillWidth: true
                                text: root.authService.userName || qsTr("Signed-in user")
                                color: Theme.colors.textPrimary
                                font.pixelSize: Theme.fontSizes.h2
                                font.bold: true
                            }

                            Label {
                                Layout.fillWidth: true
                                text: qsTr("Signed in")
                                color: Theme.colors.accent
                                font.pixelSize: Theme.fontSizes.caption
                            }
                        }

                        AppButton {
                            objectName: "logoutButton"
                            text: qsTr("Logout")
                            bgColor: Theme.colors.surfaceHover
                            btnWidth: Theme.sizes.loginLogoutButtonWidth
                            onClicked: root.authService.logout()
                        }
                    }
                }

                ColumnLayout {
                    objectName: "loginForms"
                    Layout.fillWidth: true
                    visible: !root.authService.isLoggedIn
                    spacing: Theme.spacing.xl

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: Theme.spacing.sm

                        AppButton {
                            objectName: "cookieModeButton"
                            checkable: true
                            flatButton: true
                            checked: root.loginMode === 0
                            autoExclusive: true
                            Accessible.role: Accessible.RadioButton
                            text: qsTr("Cookie login")
                            bgColor: root.loginMode === 0
                                     ? Theme.colors.accent : Theme.colors.surfaceRaised
                            textColor: root.loginMode === 0
                                       ? Theme.colors.textPrimary : Theme.colors.textTertiary
                            btnWidth: Theme.sizes.loginModeButtonWidth
                            onClicked: root.loginMode = 0
                        }

                        AppButton {
                            objectName: "qrModeButton"
                            checkable: true
                            flatButton: true
                            checked: root.loginMode === 1
                            autoExclusive: true
                            Accessible.role: Accessible.RadioButton
                            text: qsTr("QR login")
                            bgColor: root.loginMode === 1
                                     ? Theme.colors.accent : Theme.colors.surfaceRaised
                            textColor: root.loginMode === 1
                                       ? Theme.colors.textPrimary : Theme.colors.textTertiary
                            btnWidth: Theme.sizes.loginModeButtonWidth
                            onClicked: root.loginMode = 1
                        }
                    }

                    StackLayout {
                        Layout.fillWidth: true
                        currentIndex: root.loginMode

                        Rectangle {
                            objectName: "cookieLoginForm"
                            Layout.fillWidth: true
                            Layout.preferredHeight: cookieLayout.implicitHeight + 2 * Theme.spacing.xl
                            color: Theme.colors.surfaceRaised
                            radius: Theme.radius.card

                            ColumnLayout {
                                id: cookieLayout
                                anchors.fill: parent
                                anchors.margins: Theme.spacing.xl
                                spacing: Theme.spacing.lg

                                Label {
                                    Layout.fillWidth: true
                                    text: qsTr("Paste the cookie copied from your browser developer tools")
                                    color: Theme.colors.textTertiary
                                    font.pixelSize: Theme.fontSizes.caption
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.Wrap
                                }

                                TextField {
                                    id: cookieInput
                                    objectName: "cookieInput"
                                    Layout.fillWidth: true
                                    Layout.maximumWidth: Theme.sizes.loginInputMaxWidth
                                    Layout.alignment: Qt.AlignHCenter
                                    placeholderText: qsTr("SESSDATA=xxx; bili_jct=xxx; …")
                                    color: Theme.colors.textSecondary
                                    placeholderTextColor: Theme.colors.textDisabled
                                    echoMode: root.cookieVisible ? TextInput.Normal : TextInput.Password
                                    rightPadding: Theme.sizes.loginInputTrailingPadding
                                    selectByMouse: true

                                    background: Rectangle {
                                        color: Theme.colors.controlInset
                                        radius: Theme.radius.control
                                        border.width: cookieInput.activeFocus ? 1 : 0
                                        border.color: Theme.colors.borderFocus
                                    }

                                    IconButton {
                                        objectName: "cookieVisibilityButton"
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        iconSource: root.cookieVisible
                                                    ? "qrc:/qt/qml/cursor_music/icon/eye-off.svg"
                                                    : "qrc:/qt/qml/cursor_music/icon/eye.svg"
                                        accessibleName: root.cookieVisible
                                                        ? qsTr("Hide cookie") : qsTr("Show cookie")
                                        onTriggered: root.cookieVisible = !root.cookieVisible
                                    }
                                }

                                AppButton {
                                    objectName: "importCookieButton"
                                    Layout.alignment: Qt.AlignHCenter
                                    text: qsTr("Import Cookie")
                                    enabled: cookieInput.text.trim().length > 0
                                    btnWidth: Theme.sizes.loginPrimaryButtonWidth
                                    onClicked: {
                                        root.authService.importCookie(cookieInput.text.trim())
                                        cookieInput.clear()
                                    }
                                }

                                Label {
                                    Layout.fillWidth: true
                                    visible: root.loginResult.length > 0
                                    text: root.loginResult
                                    color: root.loginResult.startsWith(qsTr("Login successful"))
                                           ? Theme.colors.accent : Theme.colors.error
                                    font.pixelSize: Theme.fontSizes.caption
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.Wrap
                                }
                            }
                        }

                        Rectangle {
                            objectName: "qrLoginForm"
                            Layout.fillWidth: true
                            Layout.preferredHeight: qrLayout.implicitHeight + 2 * Theme.spacing.xl
                            color: Theme.colors.surfaceRaised
                            radius: Theme.radius.card

                            ColumnLayout {
                                id: qrLayout
                                anchors.fill: parent
                                anchors.margins: Theme.spacing.xl
                                spacing: Theme.spacing.lg

                                Label {
                                    Layout.fillWidth: true
                                    text: qsTr("Scan with the Bilibili app")
                                    color: Theme.colors.textTertiary
                                    font.pixelSize: Theme.fontSizes.caption
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                SkeletonList {
                                    objectName: "qrGeneratingState"
                                    Layout.fillWidth: true
                                    Layout.maximumWidth: Theme.sizes.loginQrSkeletonMaxWidth
                                    Layout.alignment: Qt.AlignHCenter
                                    visible: root.qrState === "generating"
                                    count: 3
                                }

                                Rectangle {
                                    objectName: "qrVisualState"
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.preferredWidth: Theme.sizes.loginQrFrameSize
                                    Layout.preferredHeight: Theme.sizes.loginQrFrameSize
                                    visible: root.qrState !== "generating"
                                             && root.qrState !== "networkError"
                                    color: Theme.colors.qrSurface
                                    radius: Theme.radius.card

                                    Label {
                                        anchors.centerIn: parent
                                        width: parent.width - Theme.sizes.loginQrLabelInset
                                        visible: !qrImage.visible
                                        text: root.qrStatusText()
                                        color: Theme.colors.textDisabled
                                        font.pixelSize: Theme.fontSizes.caption
                                        horizontalAlignment: Text.AlignHCenter
                                        wrapMode: Text.Wrap
                                    }

                                    Image {
                                        id: qrImage
                                        anchors.centerIn: parent
                                        width: Theme.sizes.loginQrImageSize
                                        height: Theme.sizes.loginQrImageSize
                                        sourceSize.width: Theme.sizes.loginQrImageSize
                                        sourceSize.height: Theme.sizes.loginQrImageSize
                                        source: root.authService.qrImageUrl
                                        visible: root.authService.qrImageUrl.length > 0
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                        cache: false
                                    }
                                }

                                ErrorState {
                                    objectName: "qrErrorState"
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Theme.sizes.statePanelHeight
                                    visible: root.qrState === "networkError"
                                    message: root.authService.qrStatus || qsTr("Network error")
                                    onRetryRequested: root.authService.startQrLogin()
                                }

                                Label {
                                    objectName: "qrStatusLabel"
                                    Layout.fillWidth: true
                                    visible: root.qrState !== "networkError"
                                    text: root.qrStatusText()
                                    color: root.qrStatusColor()
                                    font.pixelSize: Theme.fontSizes.caption
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.Wrap
                                }

                                RowLayout {
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: Theme.spacing.sm

                                    AppButton {
                                        objectName: "qrStartButton"
                                        text: root.qrState === "generating"
                                              ? qsTr("Generating…") : qsTr("Get QR code")
                                        enabled: !root.authService.qrLoginActive
                                        btnWidth: Theme.sizes.loginPrimaryButtonWidth
                                        onClicked: root.authService.startQrLogin()
                                    }

                                    AppButton {
                                        objectName: "qrStopButton"
                                        text: qsTr("Cancel")
                                        visible: root.authService.qrLoginActive
                                        bgColor: Theme.colors.surfaceHover
                                        btnWidth: Theme.sizes.loginSecondaryButtonWidth
                                        onClicked: root.authService.stopQrLogin()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
