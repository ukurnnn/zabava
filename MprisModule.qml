import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Item {
    id: root
    implicitWidth: contentRow.implicitWidth + 4
    implicitHeight: 40

    property var player: null
    property string trackText: ""
    property string artistText: ""
    property string albumArt: ""
    property bool wasPlaying: false

    // для прогресс-полосы внизу острова
    property real position: 0
    property real length: 0
    property real progress: (length > 0 && position >= 0) ? Math.min(1, position / length) : 0

    Component.onCompleted: updatePlayer()

    function updatePlayer() {
        var players = Mpris.players.values
        var chosen = null

        if (players && players.length > 0) {
            for (var i = 0; i < players.length; i++) {
                if (players[i].isPlaying) { chosen = players[i]; break }
            }
            if (!chosen) {
                for (var j = 0; j < players.length; j++) {
                    if (players[j].trackTitle && players[j].trackTitle !== "") {
                        chosen = players[j]; break
                    }
                }
            }
        }

        // ЗАЩИТА: если плеер пропал, но текст уже был — не сбрасываем сразу
        if (!chosen && root.trackText !== "") {
            retryTimer.restart()
            return
        }

        root.player = chosen

        if (!chosen) {
            root.trackText = ""
            root.artistText = ""
            root.albumArt = ""
            root.position = 0
            root.length = 0
            return
        }

        // ЗАЩИТА: если trackTitle пустой, но плеер есть — ждём
        var title = chosen.trackTitle || ""
        var artist = chosen.trackArtist || ""

        if (title === "" && artist === "") {
            // Плеер есть, но метаданные ещё не пришли — не трогаем trackText
            retryTimer.restart()
            return
        }

        root.trackText = title
        root.artistText = artist
        root.albumArt = chosen.trackArtUrl || ""
        root.length = chosen.length || 0
        root.position = chosen.position || 0
    }

    Connections {
        target: Mpris.players
        function onValuesChanged() { root.updatePlayer() }
    }

    Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onPostTrackChanged() {
            retryTimer.restart()
        }
        function onIsPlayingChanged() { root.updatePlayer() }
        function onTrackArtUrlChanged() { root.updatePlayer() }
        function onPositionChanged() {
            if (root.player) root.position = root.player.position || 0
        }
        function onLengthChanged() { root.length = root.player ? root.player.length || 0 : 0 }
    }

    // плавное обновление позиции, пока играет
    Timer {
        interval: 1000
        running: root.player !== null && root.player.isPlaying
        repeat: true
        onTriggered: {
            if (root.player) {
                root.position = root.player.position || 0
                root.length = root.player.length || 0
            }
        }
    }

    Timer {
        id: retryTimer
        interval: 400
        repeat: false
        onTriggered: root.updatePlayer()
    }

    // Второй таймер на случай, если первый не догнал
    Timer {
        id: retryTimer2
        interval: 900
        repeat: false
        onTriggered: root.updatePlayer()
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 9

        // миниатюра обложки
        Rectangle {
            id: coverThumb
            anchors.verticalCenter: parent.verticalCenter
            width: 28
            height: 28
            radius: 7
            color: Theme.surface
            clip: true

            Image {
                anchors.fill: parent
                source: root.albumArt
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: root.albumArt !== ""
            }

            Text {
                anchors.centerIn: parent
                text: root.player && root.player.isPlaying ? "󰎈" : "󰎆"
                color: Theme.fgMuted
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 15
                visible: root.albumArt === ""
            }

            MouseArea {
                id: coverArea
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: playerPopup.visible = !playerPopup.visible
            }
        }

        // заголовок + исполнитель в две строки
        Item {
            id: textWrap
            width: textCol.implicitWidth
            height: textCol.implicitHeight
            anchors.verticalCenter: parent.verticalCenter

            Column {
                id: textCol
                anchors.centerIn: parent
                spacing: 1

                Text {
                    text: root.trackText !== "" ? root.trackText : (root.player ? (root.player.identity || "") : "Ничего не играет")
                    color: root.trackText !== "" ? (trackArea.containsMouse ? Theme.yellow : Theme.fg) : Theme.fgMuted
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    font.bold: root.trackText !== ""
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, 220)
                }

                Text {
                    text: root.artistText
                    visible: root.artistText !== ""
                    color: Theme.fgMuted
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, 220)
                }
            }

            MouseArea {
                id: trackArea
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: playerPopup.visible = !playerPopup.visible
                onWheel: (wheel) => {
                    if (!root.player) return
                    if (wheel.angleDelta.y > 0) root.player.next()
                    else root.player.previous()
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.player && root.player.isPlaying ? "󰏤" : "󰐊"
            color: playArea.containsMouse ? Theme.accent : Theme.fg
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 15
            Behavior on color { ColorAnimation { duration: 150 } }

            MouseArea {
                id: playArea
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.player) root.player.togglePlaying()
                }
            }
        }
    }

    // прогресс-полоса внизу острова
    Rectangle {
        id: barProgress
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        height: 3
        radius: 1.5
        color: Theme.surface
        visible: root.length > 0

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * root.progress
            height: parent.height
            radius: 1.5
            color: Theme.accent
            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }
        }
    }

    onTrackTextChanged: {
        if (trackText !== "") {
            retryTimer2.restart()
        }
    }
}
