import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Io

PopupWindow {
    id: root

    anchor.window: mainPanel
    anchor.rect.x: anchorItem
        ? Math.max(8, Math.min(mainPanel.width - width - 8,
            anchorItem.mapToItem(mainPanel.contentItem, 0, 0).x + anchorItem.width / 2 - width / 2))
        : (mainPanel.width - width) / 2
    anchor.rect.y: 48
    anchor.rect.width: 1
    anchor.rect.height: 1

    implicitWidth: 660
    implicitHeight: player ? 272 : 210
    visible: false
    color: "transparent"

    property var anchorItem: null
    property var player: null
    property var playersList: []
    property string pinnedId: ""

    property string trackText: ""
    property string artistText: ""
    property string albumText: ""
    property string albumArt: ""
    property real position: 0
    property real length: 0
    property real volume: 0
    property bool shuffle: false
    property int loopState: 0
    property bool dragging: false
    property real dragPos: 0

    readonly property real shownPos: dragging ? dragPos : position
    readonly property real progress: length > 0 ? Math.max(0, Math.min(1, shownPos / length)) : 0
    readonly property string playerName: player ? (player.identity || "Плеер") : ""
    readonly property bool canSeekNow: player !== null && length > 0 && player.canSeek !== false
    readonly property string statusText: !player ? "Нет активного плеера" : (player.isPlaying ? "Сейчас играет" : "Пауза")
    readonly property string loopLabel: loopState === 1 ? "Трек" : (loopState === 2 ? "Плейлист" : "Выкл")

    IpcHandler {
        target: "playerpopup"
        function toggle(): void { root.visible = !root.visible }
    }

    function formatTime(sec) {
        if (sec === undefined || sec === null || isNaN(sec) || sec < 0) sec = 0
        var total = Math.floor(sec)
        var h = Math.floor(total / 3600)
        var m = Math.floor((total % 3600) / 60)
        var s = total % 60
        if (h > 0) return h + ":" + (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    function selectPlayer(identity) {
        root.pinnedId = identity
        retryTimer1.restart()
    }

    function seekTo(ratio) {
        if (!canSeekNow) return
        seekToPosition(ratio * length)
    }

    function seekBy(seconds) {
        if (!canSeekNow) return
        seekToPosition((player.position || position || 0) + seconds)
    }

    function seekToPosition(target) {
        if (!root.player || !canSeekNow) return
        target = Math.max(0, Math.min(length, target))
        var cur = root.player.position || 0
        try {
            if (typeof root.player.seek === "function") root.player.seek(target - cur)
            else root.player.position = target
        } catch (e) {
            try { root.player.position = target } catch (e2) {}
        }
        root.position = target
    }

    function cycleLoop() {
        if (!root.player || root.player.loopSupported === false) return
        if (root.loopState === 0) root.player.loopState = 1
        else if (root.loopState === 1) root.player.loopState = 2
        else root.player.loopState = 0
    }

    function updatePlayer() {
        var players = Mpris.players ? Mpris.players.values : []
        root.playersList = players || []

        var chosen = null
        if (root.pinnedId !== "" && players) {
            for (var p = 0; p < players.length; p++) {
                if (players[p].identity === root.pinnedId) { chosen = players[p]; break }
            }
            if (!chosen) root.pinnedId = ""
        }
        if (!chosen && players) {
            for (var i = 0; i < players.length; i++) {
                if (players[i].isPlaying) { chosen = players[i]; break }
            }
        }
        if (!chosen && players) {
            for (var j = 0; j < players.length; j++) {
                if ((players[j].trackTitle && players[j].trackTitle !== "") || (players[j].trackArtist && players[j].trackArtist !== "")) {
                    chosen = players[j]; break
                }
            }
        }
        if (!chosen && players && players.length > 0) chosen = players[0]

        if (!chosen && root.trackText !== "") {
            retryTimer1.restart()
            retryTimer2.restart()
            return
        }

        root.player = chosen
        if (!chosen) {
            root.trackText = ""
            root.artistText = ""
            root.albumText = ""
            root.albumArt = ""
            root.position = 0
            root.length = 0
            root.volume = 0
            root.shuffle = false
            root.loopState = 0
            return
        }

        var title = chosen.trackTitle || ""
        var artist = chosen.trackArtist || ""
        if (title === "" && artist === "") {
            retryTimer1.restart()
            retryTimer2.restart()
            return
        }

        root.trackText = title
        root.artistText = artist
        root.albumText = chosen.trackAlbum || ""
        root.albumArt = chosen.trackArtUrl || ""
        root.length = chosen.length || 0
        root.position = chosen.position || 0
        root.volume = chosen.volume || 0
        root.shuffle = chosen.shuffle === true
        root.loopState = chosen.loopState !== undefined ? chosen.loopState : 0
    }

    Component.onCompleted: updatePlayer()

    onTrackTextChanged: {
        trackPulse.restart()
        if (trackText !== "") retryTimer2.restart()
    }

    onVisibleChanged: {
        if (visible) {
            updatePlayer()
            retryTimer1.restart()
            retryTimer2.restart()
            keyCatcher.forceActiveFocus()
        }
    }

    Connections {
        target: Mpris.players
        function onValuesChanged() { root.updatePlayer() }
    }

    Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onPostTrackChanged() { retryTimer1.restart(); retryTimer2.restart(); root.updatePlayer() }
        function onIsPlayingChanged() { root.updatePlayer() }
        function onTrackArtUrlChanged() { root.updatePlayer() }
        function onTrackTitleChanged() { root.updatePlayer() }
        function onTrackArtistChanged() { root.updatePlayer() }
        function onTrackAlbumChanged() { root.updatePlayer() }
        function onPositionChanged() { if (!root.dragging && root.player) root.position = root.player.position || 0 }
        function onLengthChanged() { root.length = root.player ? (root.player.length || 0) : 0 }
        function onVolumeChanged() { if (root.player && !volumeSlider.pressed) root.volume = root.player.volume || 0 }
        function onShuffleChanged() { if (root.player) root.shuffle = root.player.shuffle }
        function onLoopStateChanged() { if (root.player) root.loopState = root.player.loopState }
    }

    Timer { id: retryTimer1; interval: 350; repeat: false; onTriggered: root.updatePlayer() }
    Timer { id: retryTimer2; interval: 900; repeat: false; onTriggered: root.updatePlayer() }

    Timer {
        interval: 500
        running: root.visible && root.player !== null && root.player.isPlaying
        repeat: true
        onTriggered: {
            if (root.player && !root.dragging) {
                root.position = root.player.position || 0
                root.length = root.player.length || 0
            }
        }
    }

    CloseHandler { target: root }

    Rectangle {
        id: playerCard
        anchors.fill: parent
        radius: 24
        color: Theme.glassPanel
        border.color: root.player && root.player.isPlaying ? Theme.accent : Theme.glassBorderStrong
        border.width: 1

        opacity: root.visible ? 1 : 0
        scale: root.visible ? 1 : 0.96
        transformOrigin: Item.Center
        Behavior on opacity { NumberAnimation { duration: 150 } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on border.color { ColorAnimation { duration: 200 } }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 1
            height: Math.max(0, parent.height * 0.24)
            radius: Math.max(0, parent.radius - 1)
            z: 0
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.glassHighlight }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        Item {
            id: keyCatcher
            anchors.fill: parent
            focus: true
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) { root.visible = false; event.accepted = true; return }
                if (!root.player) { event.accepted = true; return }

                if (event.key === Qt.Key_Space || event.key === Qt.Key_K) {
                    root.player.togglePlaying(); event.accepted = true
                } else if (event.key === Qt.Key_Right && (event.modifiers & Qt.ShiftModifier)) {
                    if (root.player.canGoNext !== false) root.player.next(); event.accepted = true
                } else if (event.key === Qt.Key_Left && (event.modifiers & Qt.ShiftModifier)) {
                    if (root.player.canGoPrevious !== false) root.player.previous(); event.accepted = true
                } else if (event.key === Qt.Key_Right) {
                    root.seekBy(5); event.accepted = true
                } else if (event.key === Qt.Key_Left) {
                    root.seekBy(-5); event.accepted = true
                } else if (event.key === Qt.Key_Up) {
                    if (root.player.volumeSupported !== false) { root.volume = Math.min(1, root.volume + 0.05); root.player.volume = root.volume }
                    event.accepted = true
                } else if (event.key === Qt.Key_Down) {
                    if (root.player.volumeSupported !== false) { root.volume = Math.max(0, root.volume - 0.05); root.player.volume = root.volume }
                    event.accepted = true
                } else if (event.key === Qt.Key_L) {
                    root.cycleLoop(); event.accepted = true
                } else if (event.key === Qt.Key_S) {
                    if (root.player.shuffleSupported !== false) { root.player.shuffle = !root.player.shuffle; root.shuffle = root.player.shuffle }
                    event.accepted = true
                }
            }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 18
            visible: root.player !== null

            Rectangle {
                id: coverBox
                Layout.preferredWidth: 196
                Layout.preferredHeight: 196
                Layout.alignment: Qt.AlignVCenter
                radius: 18
                color: Theme.surface
                clip: true
                border.color: root.albumArt !== "" ? Theme.surface1 : "transparent"
                border.width: 1

                Rectangle {
                    anchors.fill: parent
                    visible: root.albumArt === ""
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.28) }
                        GradientStop { position: 0.55; color: Qt.rgba(Theme.accent2.r, Theme.accent2.g, Theme.accent2.b, 0.12) }
                        GradientStop { position: 1.0; color: Theme.surface }
                    }
                }

                Image {
                    anchors.fill: parent
                    source: root.albumArt
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: root.albumArt !== ""
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 56
                    visible: root.albumArt !== ""
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.45) }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: root.player && root.player.isPlaying ? "󰝚" : "󰎈"
                    color: Theme.fgMuted
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 58
                    visible: root.albumArt === ""
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: 10
                    height: 24
                    width: artStatusRow.implicitWidth + 14
                    radius: 12
                    color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.72)
                    border.color: Theme.surface1
                    border.width: 1
                    visible: root.player !== null

                    Row {
                        id: artStatusRow
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.player && root.player.isPlaying ? "󰐊" : "󰏤"
                            color: root.player && root.player.isPlaying ? Theme.green : Theme.fg
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.formatTime(root.shownPos)
                            color: Theme.fg
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10
                        }
                    }
                }
            }

            ColumnLayout {
                id: infoCol
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Row {
                        spacing: 6
                        visible: root.playersList.length > 1
                        Repeater {
                            model: root.playersList
                            delegate: Rectangle {
                                required property var modelData
                                width: chipText.implicitWidth + 18
                                height: 24
                                radius: 12
                                color: root.player === modelData ? Theme.accent : Theme.surface
                                border.color: root.player === modelData ? Theme.accent : Theme.surface1
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Text {
                                    id: chipText
                                    anchors.centerIn: parent
                                    text: modelData.identity || "player"
                                    color: root.player === modelData ? Theme.bg : Theme.fgMuted
                                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11
                                    font.bold: root.player === modelData
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.selectPlayer(modelData.identity || "") }
                            }
                        }
                    }

                    Rectangle {
                        visible: root.playersList.length <= 1
                        height: 24
                        width: idBadge.implicitWidth + 16
                        radius: 12
                        color: Theme.surface
                        border.color: Theme.surface1
                        border.width: 1
                        Text {
                            id: idBadge
                            anchors.centerIn: parent
                            text: root.playerName !== "" ? root.playerName : "MPRIS"
                            color: Theme.fgMuted
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11
                        }
                    }

                    Rectangle {
                        height: 24
                        width: statusRow.implicitWidth + 16
                        radius: 12
                        color: root.player && root.player.isPlaying ? Qt.rgba(Theme.green.r, Theme.green.g, Theme.green.b, 0.18) : Theme.surface
                        border.color: root.player && root.player.isPlaying ? Qt.rgba(Theme.green.r, Theme.green.g, Theme.green.b, 0.4) : Theme.surface1
                        border.width: 1
                        Row {
                            id: statusRow
                            anchors.centerIn: parent
                            spacing: 5
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.player && root.player.isPlaying ? "󰝚" : "󰏤"
                                color: root.player && root.player.isPlaying ? Theme.green : Theme.fgMuted
                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.statusText
                                color: root.player && root.player.isPlaying ? Theme.green : Theme.fgMuted
                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Row {
                        spacing: 6
                        visible: root.player !== null && root.player.volumeSupported !== false
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.volume <= 0.001 ? "󰝟" : (root.volume < 0.5 ? "󰖀" : "󰕾")
                            color: Theme.fgMuted
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13
                            MouseArea {
                                anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor
                                onClicked: { if (root.player) { root.volume = root.volume > 0 ? 0 : 0.5; root.player.volume = root.volume } }
                            }
                        }
                        Item {
                            id: volumeSlider
                            property bool pressed: false
                            width: 86; height: 22
                            anchors.verticalCenter: parent.verticalCenter
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width; height: 6; radius: 3; color: Theme.surface
                                Rectangle {
                                    width: parent.width * Math.max(0, Math.min(1, root.volume))
                                    height: parent.height; radius: 3; color: Theme.teal
                                    Behavior on width { NumberAnimation { duration: 90 } }
                                }
                            }
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                x: Math.max(0, Math.min(parent.width - width, parent.width * Math.max(0, Math.min(1, root.volume)))) - 5
                                width: 10; height: 10; radius: 5; color: Theme.teal
                                visible: volumeArea.containsMouse || volumeSlider.pressed
                            }
                            MouseArea {
                                id: volumeArea
                                anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onPressed: (mouse) => { volumeSlider.pressed = true; root.volume = Math.max(0, Math.min(1, mouse.x / volumeSlider.width)); if (root.player) root.player.volume = root.volume }
                                onPositionChanged: (mouse) => { if (pressed) { root.volume = Math.max(0, Math.min(1, mouse.x / volumeSlider.width)); if (root.player) root.player.volume = root.volume } }
                                onReleased: volumeSlider.pressed = false
                                onWheel: (wheel) => { if (!root.player) return; root.volume = Math.max(0, Math.min(1, root.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))); root.player.volume = root.volume }
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 34
                            horizontalAlignment: Text.AlignRight
                            text: Math.round(root.volume * 100) + "%"
                            color: Theme.fgMuted
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        Layout.fillWidth: true
                        text: root.trackText !== "" ? root.trackText : "Неизвестный трек"
                        color: Theme.fg
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 20
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.artistText !== "" ? root.artistText : "Неизвестный исполнитель"
                        color: Theme.fgMuted
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: root.albumText !== ""
                        text: "󰀥  " + root.albumText
                        color: Theme.fgMuted
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        elide: Text.ElideRight
                        opacity: 0.9
                    }
                }

                SequentialAnimation {
                    id: trackPulse
                    running: false
                    NumberAnimation { target: infoCol; property: "opacity"; from: 0.35; to: 1.0; duration: 260; easing.type: Easing.OutQuad }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Item {
                        id: seekBar
                        Layout.fillWidth: true
                        height: 20
                        opacity: root.length > 0 ? 1 : 0.4

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: seekArea.containsMouse || root.dragging ? 8 : 6
                            radius: height / 2
                            color: Theme.surface
                            Behavior on height { NumberAnimation { duration: 100 } }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width * root.progress
                                height: parent.height
                                radius: height / 2
                                color: root.canSeekNow ? Theme.accent : Theme.overlay
                                Behavior on width { NumberAnimation { duration: root.dragging ? 0 : 220 } }
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                x: Math.max(0, Math.min(parent.width - width, parent.width * root.progress)) - 6
                                width: 12; height: 12; radius: 6
                                color: Theme.accent2
                                border.color: Theme.bg
                                border.width: 2
                                visible: root.canSeekNow && (seekArea.containsMouse || root.dragging)
                            }
                        }

                        MouseArea {
                            id: seekArea
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            enabled: root.canSeekNow
                            cursorShape: root.canSeekNow ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onPressed: (mouse) => { if (!root.canSeekNow) return; root.dragging = true; root.dragPos = Math.max(0, Math.min(root.length, (mouse.x / seekBar.width) * root.length)) }
                            onPositionChanged: (mouse) => { if (pressed && root.canSeekNow) root.dragPos = Math.max(0, Math.min(root.length, (mouse.x / seekBar.width) * root.length)) }
                            onReleased: { if (root.dragging) { root.seekTo(root.dragPos / root.length); root.dragging = false } }
                            onWheel: (wheel) => { if (!root.canSeekNow) return; var delta = wheel.angleDelta.y > 0 ? 0.03 : -0.03; root.seekTo(Math.max(0, Math.min(1, root.progress + delta))) }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: root.formatTime(root.shownPos)
                            color: Theme.fg
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            visible: root.length > 0
                            text: "-" + root.formatTime(Math.max(0, root.length - root.shownPos)) + "  ·  " + Math.round(root.progress * 100) + "%"
                            color: Theme.fgMuted
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: root.length > 0 ? root.formatTime(root.length) : "--:--"
                            color: Theme.fg
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        width: 34; height: 34; radius: 17
                        color: shuffleBtn.containsMouse ? Theme.surface1 : "transparent"
                        border.color: root.shuffle ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.5) : "transparent"
                        border.width: 1
                        opacity: (root.player && root.player.shuffleSupported === false) ? 0.35 : 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text { anchors.centerIn: parent; text: "󰒟"; color: root.shuffle ? Theme.accent : Theme.fgMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15 }
                        MouseArea {
                            id: shuffleBtn
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            enabled: root.player && root.player.shuffleSupported !== false
                            onClicked: { if (!root.player) return; root.player.shuffle = !root.player.shuffle; root.shuffle = root.player.shuffle }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Row {
                        spacing: 10
                        Rectangle {
                            width: 40; height: 40; radius: 20
                            anchors.verticalCenter: parent.verticalCenter
                            color: prevBtn.containsMouse ? Theme.surface1 : Theme.surface
                            opacity: (root.player && root.player.canGoPrevious === false) ? 0.4 : 1
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Text { anchors.centerIn: parent; text: "󰒮"; color: Theme.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 20 }
                            MouseArea {
                                id: prevBtn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                enabled: root.player && root.player.canGoPrevious !== false
                                onClicked: { if (root.player) root.player.previous() }
                            }
                        }

                        Rectangle {
                            width: 52; height: 52; radius: 26
                            color: playBtn.containsMouse ? Theme.accent2 : Theme.accent
                            scale: playBtn.pressed ? 0.96 : 1
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on scale { NumberAnimation { duration: 90 } }
                            Text {
                                anchors.centerIn: parent
                                anchors.horizontalCenterOffset: (root.player && root.player.isPlaying) ? 0 : 1
                                text: root.player && root.player.isPlaying ? "󰏤" : "󰐊"
                                color: Theme.bg
                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 24
                            }
                            MouseArea {
                                id: playBtn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { if (root.player) root.player.togglePlaying() }
                            }
                        }

                        Rectangle {
                            width: 40; height: 40; radius: 20
                            anchors.verticalCenter: parent.verticalCenter
                            color: nextBtn.containsMouse ? Theme.surface1 : Theme.surface
                            opacity: (root.player && root.player.canGoNext === false) ? 0.4 : 1
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Text { anchors.centerIn: parent; text: "󰒭"; color: Theme.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 20 }
                            MouseArea {
                                id: nextBtn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                enabled: root.player && root.player.canGoNext !== false
                                onClicked: { if (root.player) root.player.next() }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        width: 34; height: 34; radius: 17
                        color: loopBtn.containsMouse ? Theme.surface1 : "transparent"
                        border.color: root.loopState !== 0 ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.5) : "transparent"
                        border.width: 1
                        opacity: (root.player && root.player.loopSupported === false) ? 0.35 : 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            anchors.centerIn: parent
                            text: root.loopState === 1 ? "󰑘" : (root.loopState === 2 ? "󰑖" : "󰑗")
                            color: root.loopState !== 0 ? Theme.accent : Theme.fgMuted
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15
                        }
                        MouseArea {
                            id: loopBtn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            enabled: root.player && root.player.loopSupported !== false
                            onClicked: root.cycleLoop()
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        visible: root.shuffle || root.loopState !== 0
                        text: (root.shuffle ? "󰒟 Перемешивание" : "") + (root.shuffle && root.loopState !== 0 ? "  ·  " : "") + (root.loopState !== 0 ? ("󰑖 Повтор: " + root.loopLabel) : "")
                        color: Theme.fgMuted
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Item { Layout.fillWidth: true; visible: !(root.shuffle || root.loopState !== 0) }
                    Text {
                        text: "Space — пауза  ·  ←/→ — перемотка  ·  Shift+←/→ — трек  ·  ↑/↓ — громкость"
                        color: Theme.overlay
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9
                        elide: Text.ElideRight
                    }
                }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 10
            visible: root.player === null
            z: 10

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 72; height: 72; radius: 36
                color: Theme.surface
                border.color: Theme.surface1; border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: "󰎆"
                    color: Theme.fgMuted
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 30
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Ничего не играет"
                color: Theme.fg
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16; font.bold: true
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Запустите музыку или видео в любом MPRIS-плеере"
                color: Theme.fgMuted
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
            }
        }
    }
}
