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

    implicitWidth: 620
    implicitHeight: 240
    visible: false
    color: "transparent"

    property var anchorItem: null
    property var player: null
    property var playersList: []
    property string pinnedId: ""          // плеер, выбранный пользователем вручную
    property string trackText: ""
    property string artistText: ""
    property string albumText: ""
    property string albumArt: ""
    property real position: 0
    property real length: 0
    property real volume: 0
    property bool shuffle: false
    property int loopState: 0             // MprisLoopState.None
    property bool dragging: false
    property real dragPos: 0

    IpcHandler {
        target: "playerpopup"
        function toggle(): void { root.visible = !root.visible }
    }

    function formatTime(sec) {
        if (!sec || sec <= 0) return "0:00"
        var m = Math.floor(sec / 60)
        var s = Math.floor(sec % 60)
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    function selectPlayer(identity) {
        root.pinnedId = identity
        retryTimer1.restart()
    }

    function seekTo(ratio) {
        if (!root.player || root.length <= 0) return
        if (root.player.canSeek === false) return
        var target = Math.max(0, Math.min(root.length, ratio * root.length))
        root.player.seek(target - (root.player.position || 0))
        root.position = target
    }

    function cycleLoop() {
        if (!root.player || root.player.loopSupported === false) return
        // 0 = None, 1 = Track, 2 = Playlist (MprisLoopState)
        if (root.loopState === 0) root.player.loopState = 1
        else if (root.loopState === 1) root.player.loopState = 2
        else root.player.loopState = 0
    }

    function updatePlayer() {
        var players = Mpris.players.values
        root.playersList = players || []

        var chosen = null

        // 1. закреплённый пользователем плеер, если ещё жив
        if (root.pinnedId !== "" && players) {
            for (var p = 0; p < players.length; p++) {
                if (players[p].identity === root.pinnedId) { chosen = players[p]; break }
            }
            if (!chosen) root.pinnedId = ""   // плеер исчез — снимаем закрепление
        }

        // 2. играющий плеер
        if (!chosen && players) {
            for (var i = 0; i < players.length; i++) {
                if (players[i].isPlaying) { chosen = players[i]; break }
            }
        }

        // 3. первый с валидным треком
        if (!chosen && players) {
            for (var j = 0; j < players.length; j++) {
                if (players[j].trackTitle && players[j].trackTitle !== "") {
                    chosen = players[j]; break
                }
            }
        }

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

    onTrackTextChanged: trackPulse.restart()

    onVisibleChanged: {
        if (visible) {
            updatePlayer()
            retryTimer1.restart()
            retryTimer2.restart()
        }
    }

    Connections {
        target: Mpris.players
        function onValuesChanged() { root.updatePlayer() }
    }

    Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onPostTrackChanged() {
            retryTimer1.restart()
            retryTimer2.restart()
        }
        function onIsPlayingChanged() { root.updatePlayer() }
        function onTrackArtUrlChanged() { root.updatePlayer() }
        function onPositionChanged() { if (!root.dragging && root.player) root.position = root.player.position || 0 }
        function onLengthChanged() { root.length = root.player ? root.player.length || 0 : 0 }
        function onVolumeChanged() { if (root.player && !volumeSlider.pressed) root.volume = root.player.volume || 0 }
        function onShuffleChanged() { if (root.player) root.shuffle = root.player.shuffle }
        function onLoopStateChanged() { if (root.player) root.loopState = root.player.loopState }
    }

    Timer {
        id: retryTimer1
        interval: 400
        repeat: false
        onTriggered: root.updatePlayer()
    }

    Timer {
        id: retryTimer2
        interval: 900
        repeat: false
        onTriggered: root.updatePlayer()
    }

    // плавное обновление позиции, пока попап открыт и играет
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

    Timer {
        interval: 1000
        running: root.player && root.player.isPlaying
        repeat: true
        onTriggered: {
            if (root.player) {
                root.position = root.player.position || 0
                root.length = root.player.length || 0
            }
        }
    }

    CloseHandler {
        target: root
    }

    Rectangle {
        id: playerCard
        anchors.fill: parent
        radius: 24
        color: Theme.bg
        border.color: Theme.surface
        border.width: 1

        // анимация появления/скрытия
        opacity: root.visible ? 1 : 0
        scale: root.visible ? 1 : 0.95
        transformOrigin: Item.Center
        Behavior on opacity { NumberAnimation { duration: 160 } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

        MouseArea { anchors.fill: parent; onClicked: {} }

        // ===== обложка =====
        Rectangle {
            id: coverBox
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 20
            width: 168
            height: 168
            radius: 18
            color: Theme.surface
            clip: true

            // мягкая подложка под fallback
            Rectangle {
                anchors.fill: parent
                radius: 18
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25) }
                    GradientStop { position: 1.0; color: Theme.surface }
                }
                visible: root.albumArt === ""
            }

            Image {
                anchors.fill: parent
                source: root.albumArt
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: root.albumArt !== ""
            }

            Text {
                anchors.centerIn: parent
                text: "󰎈"
                color: Theme.fgMuted
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 56
                visible: root.albumArt === ""
            }

            // тонкая рамка поверх обложки
            Rectangle {
                anchors.fill: parent
                radius: 18
                color: "transparent"
                border.color: root.albumArt !== "" ? Theme.surface1 : "transparent"
                border.width: 1
            }
        }

        // ===== правая колонка =====
        Column {
            id: infoCol
            anchors.left: coverBox.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: 18
            anchors.rightMargin: 20
            anchors.topMargin: 18
            anchors.bottomMargin: 18
            spacing: 10

            // шапка: переключатель плееров / имя плеера
            Row {
                width: parent.width
                spacing: 6

                Row {
                    id: playerChips
                    spacing: 6
                    visible: root.playersList.length > 1

                    Repeater {
                        model: root.playersList

                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            width: chipLabel.implicitWidth + 20
                            height: 24
                            radius: 12
                            color: root.player === modelData ? Theme.accent : Theme.surface
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                id: chipLabel
                                anchors.centerIn: parent
                                text: modelData.identity || "player"
                                color: root.player === modelData ? Theme.bg : Theme.fgMuted
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                font.bold: root.player === modelData
                                elide: Text.ElideRight
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectPlayer(modelData.identity || "")
                            }
                        }
                    }
                }

                Rectangle {
                    visible: root.playersList.length <= 1 && root.player !== null
                    width: idLabel.implicitWidth + 26
                    height: 24
                    radius: 12
                    color: Theme.surface

                    Text {
                        id: idLabel
                        anchors.centerIn: parent
                        text: root.player ? (root.player.identity || "player") : ""
                        color: Theme.fgMuted
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                    }
                }

                Item { Layout.fillWidth: true; width: 1; height: 1 }

                // регулятор громкости
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    visible: root.player !== null && root.player.volumeSupported !== false

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.volume <= 0 ? "󰝟" : (root.volume < 0.5 ? "󰕿" : "󰕾")
                        color: Theme.fgMuted
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                    }

                    Item {
                        id: volumeSlider
                        property bool pressed: false
                        width: 80
                        height: 24
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 5
                            radius: 2.5
                            color: Theme.surface

                            Rectangle {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width * Math.max(0, Math.min(1, root.volume))
                                height: parent.height
                                radius: 2.5
                                color: Theme.teal
                                Behavior on width { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
                            }
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.max(0, Math.min(parent.width - width,
                                volumeSlider.width * Math.max(0, Math.min(1, root.volume)))) - 4.5
                            width: 9
                            height: 9
                            radius: 4.5
                            color: Theme.teal
                            visible: volumeArea.containsMouse || volumeSlider.pressed
                        }

                        MouseArea {
                            id: volumeArea
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: (mouse) => {
                                volumeSlider.pressed = true
                                root.volume = Math.max(0, Math.min(1, mouse.x / volumeSlider.width))
                                if (root.player) root.player.volume = root.volume
                            }
                            onPositionChanged: (mouse) => {
                                if (pressed) {
                                    root.volume = Math.max(0, Math.min(1, mouse.x / volumeSlider.width))
                                    if (root.player) root.player.volume = root.volume
                                }
                            }
                            onReleased: volumeSlider.pressed = false
                            onWheel: (wheel) => {
                                if (!root.player) return
                                root.volume = Math.max(0, Math.min(1,
                                    root.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05)))
                                root.player.volume = root.volume
                            }
                        }
                    }
                }
            }

            // ===== название / исполнитель / альбом =====
            Text {
                width: parent.width
                visible: root.player !== null
                text: root.trackText !== "" ? root.trackText : "Ничего не играет"
                color: Theme.fg
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 19
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: root.artistText + (root.albumText !== "" ? "  ·  " + root.albumText : "")
                color: Theme.fgMuted
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                elide: Text.ElideRight
                visible: text !== ""
            }

            // пульсация текста при смене трека
            SequentialAnimation {
                id: trackPulse
                running: false
                NumberAnimation { target: infoCol; property: "opacity"; from: 0.25; to: 1; duration: 320; easing.type: Easing.OutQuad }
            }


            // ===== перемотка =====
            Item {
                id: seekBar
                width: parent.width
                height: 18
                visible: root.player !== null
                enabled: root.length > 0 && root.player !== null && root.player.canSeek !== false
                opacity: root.length > 0 ? 1 : 0.35

                property real shownRatio: root.length > 0
                    ? Math.max(0, Math.min(1, root.dragging ? root.dragPos / root.length : root.position / root.length))
                    : 0

                // фоновая дорожка
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: seekArea.containsMouse || root.dragging ? 8 : 6
                    radius: height / 2
                    color: Theme.surface
                    Behavior on height { NumberAnimation { duration: 100 } }

                    // заполнение
                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width * seekBar.shownRatio
                        height: parent.height
                        radius: height / 2
                        color: Theme.accent

                        Behavior on width { NumberAnimation { duration: root.dragging ? 0 : 250 } }
                    }

                    // ручка
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.max(0, Math.min(parent.width - width, parent.width * seekBar.shownRatio)) - 6
                        width: 12
                        height: 12
                        radius: 6
                        color: Theme.accent2
                        border.color: Theme.bg
                        border.width: 2
                        visible: seekArea.containsMouse || root.dragging
                    }
                }

                MouseArea {
                    id: seekArea
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    enabled: root.length > 0 && root.player !== null && root.player.canSeek !== false
                    cursorShape: Qt.PointingHandCursor

                    onPressed: (mouse) => {
                        root.dragging = true
                        root.dragPos = Math.max(0, Math.min(root.length, (mouse.x / seekBar.width) * root.length))
                    }
                    onPositionChanged: (mouse) => {
                        if (pressed)
                            root.dragPos = Math.max(0, Math.min(root.length, (mouse.x / seekBar.width) * root.length))
                    }
                    onReleased: {
                        root.seekTo(root.dragPos / root.length)
                        root.dragging = false
                    }
                    onWheel: (wheel) => {
                        if (!root.player) return
                        root.seekTo(Math.max(0, Math.min(1, seekBar.shownRatio + (wheel.angleDelta.y > 0 ? 0.02 : -0.02))))
                    }
                }
            }

            // время
            Row {
                width: parent.width
                visible: root.player !== null

                Text {
                    text: root.formatTime(root.dragging ? root.dragPos : root.position)
                    color: Theme.fgMuted
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                }

                Item { Layout.fillWidth: true; width: 1; height: 1 }

                Text {
                    text: root.length > 0 ? root.formatTime(root.length) : "--:--"
                    color: Theme.fgMuted
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                }
            }

            // ===== транспорт =====
            Item {
                width: parent.width
                height: 48
                visible: root.player !== null

                Row {
                    anchors.centerIn: parent
                    spacing: 16

                    // перемешивание
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰒳"
                        color: root.shuffle ? Theme.accent : (shuffleArea.containsMouse ? Theme.fg : Theme.fgMuted)
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 17
                        visible: root.player === null || root.player.shuffleSupported !== false
                        Behavior on color { ColorAnimation { duration: 150 } }

                        MouseArea {
                            id: shuffleArea
                            anchors.fill: parent
                            anchors.margins: -8
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: root.player !== null && root.player.shuffleSupported !== false
                            onClicked: {
                                if (!root.player) return
                                root.player.shuffle = !root.player.shuffle
                                root.shuffle = root.player.shuffle
                            }
                        }
                    }

                    // предыдущий
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰒮"
                        color: (root.player && root.player.canGoPrevious === false) ? Theme.surface1
                               : (prevArea.containsMouse ? Theme.accent : Theme.fg)
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 24
                        Behavior on color { ColorAnimation { duration: 150 } }

                        MouseArea {
                            id: prevArea
                            anchors.fill: parent
                            anchors.margins: -8
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { if (root.player && root.player.canGoPrevious !== false) root.player.previous() }
                        }
                    }

                    // play / pause
                    Item {
                        width: 48
                        height: 48
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            anchors.centerIn: parent
                            width: 46
                            height: 46
                            radius: 23
                            color: playArea.containsMouse ? Theme.accent2 : Theme.accent
                            scale: playArea.containsMouse ? 1.08 : 1
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on scale { NumberAnimation { duration: 120 } }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: root.player && root.player.isPlaying ? "󰏤" : "󰐊"
                            color: Theme.bg
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 26
                        }

                        MouseArea {
                            id: playArea
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { if (root.player) root.player.togglePlaying() }
                        }
                    }

                    // следующий
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰒭"
                        color: (root.player && root.player.canGoNext === false) ? Theme.surface1
                               : (nextArea.containsMouse ? Theme.accent : Theme.fg)
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 24
                        Behavior on color { ColorAnimation { duration: 150 } }

                        MouseArea {
                            id: nextArea
                            anchors.fill: parent
                            anchors.margins: -8
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { if (root.player && root.player.canGoNext !== false) root.player.next() }
                        }
                    }

                    // повтор: выкл / трек / очередь
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.loopState === 1 ? "󰑘" : (root.loopState === 2 ? "󰑓" : "󰑗")
                        color: root.loopState !== 0 ? Theme.accent : (repeatArea.containsMouse ? Theme.fg : Theme.fgMuted)
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 17
                        visible: root.player === null || root.player.loopSupported !== false
                        Behavior on color { ColorAnimation { duration: 150 } }

                        MouseArea {
                            id: repeatArea
                            anchors.fill: parent
                            anchors.margins: -8
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: root.player !== null && root.player.loopSupported !== false
                            onClicked: root.cycleLoop()
                        }
                    }
                }
            }
        }

        // ===== пустое состояние =====
        Column {
            anchors.centerIn: parent
            spacing: 10
            visible: root.player === null
            z: 10

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "󰎆"
                color: Theme.overlay
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 44
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Ничего не играет"
                color: Theme.fgMuted
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 15
            }
        }
    }
}
