pragma ComponentBehavior: Bound

import QtQuick

ListView {
    id: root

    property var currentMediaId

    signal mediaActivated(var mediaId)

    spacing: 4
    reuseItems: true

    delegate: MediaListItem {
        required property var model

        width: ListView.view.width
        mediaId: model.mediaId
        title: model.title
        coverUrl: model.coverUrl
        uploader: model.uploader
        resourceTypeLabel: model.resourceTypeLabel
        duration: model.duration
        invalid: model.invalid
        current: mediaId === root.currentMediaId
        onActivated: function(activatedMediaId) {
            root.mediaActivated(activatedMediaId)
        }
    }
}
