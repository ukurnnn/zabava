//@ pragma UseQApplication

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Services.Mpris
import Quickshell.Io
import "."

ShellRoot {
    id: root

    property string password: ""
    property string errorMessage: ""
    property bool authenticating: false
    property string currentWallpaper: ""

    property var player: null
    property string trackText: ""
    property string artistText: ""
    property string albumArt: ""
    property real position: 0
    property real length: 0

    Process {
        id: wallpaperQuery
        command: ["bash", "-c", "awww query | grep -oP '(?<=currently displaying: image: ).*' | head -1"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var path = this.text.trim()
                if (path !== "") root.currentWallpaper = "file://" + path
            }
        }
    }

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
        if (!chosen && root.trackText !== "") {
            retryTimer1.restart()
            retryTimer2.restart()
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
        var title = chosen.trackTitle || ""
        var artist = chosen.trackArtist || ""
        if (title === "" && artist === "") {
            retryTimer1.restart()
            retryTimer2.restart()
            return
        }
        root.trackText = title
        root.artistText = artist
        root.albumArt = chosen.trackArtUrl || ""
        root.length = chosen.length || 0
        root.position = chosen.position || 0
    }

    Component.onCompleted: updatePlayer()

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
        function onPositionChanged() { root.position = root.player ? root.player.position : 0 }
        function onLengthChanged() { root.length = root.player ? root.player.length : 0 }
    }

    Timer { id: retryTimer1; interval: 400; repeat: false; onTriggered: root.updatePlayer() }
    Timer { id: retryTimer2; interval: 900; repeat: false; onTriggered: root.updatePlayer() }

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

    function formatTime(sec) {
        if (!sec || sec <= 0) return "0:00"
        var m = Math.floor(sec / 60)
        var s = Math.floor(sec % 60)
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    PamContext {
        id: pam
        config: "login"
        user: Quickshell.env("USER")

        onPamMessage: {
            if (responseRequired && root.authenticating) {
                pam.respond(root.password)
            }
        }

        onCompleted: (result) => {
            if (result === PamResult.Success) {
                lock.locked = false
                Qt.quit()
            } else {
                root.errorMessage = "Неверный пароль"
                root.password = ""
                root.authenticating = false
                passwordInput.text = ""
                passwordInput.forceActiveFocus()
            }
        }
    }

    // ВАЖНО: WlSessionLockSurface НАПРЯМУЮ, без Component, без Loader, без BackgroundEffect
    WlSessionLock {
        id: lock
        locked: true

        WlSessionLockSurface {
            id: lockSurface
            color: Theme.bg

            Image {
                anchors.fill: parent
                source: root.currentWallpaper
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: root.currentWallpaper !== ""
            }

            Rectangle {
                anchors.fill: parent
                color: Theme.bg
                opacity: 0.75
            }

            Item {
                anchors.fill: parent
                focus: true

                Column {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -200
                    spacing: 8

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(new Date(), "HH:mm")
                        color: Theme.fg
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 110
                        font.bold: true
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(new Date(), "dddd, d MMMM")
                        color: Theme.fgMuted
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 22
                    }
                }

                Rectangle {
                    id: playerCard
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 260
                    width: 520
                    height: 140
                    radius: 20
                    color: Theme.surface
                    opacity: root.trackText !== "" ? 0.95 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 300 } }

                    Rectangle {
                        id: coverBox
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 16
                        width: 100
                        height: 100
                        radius: 12
                        color: Theme.surface1
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
                            text: "󰎆"
                            color: Theme.fgMuted
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 40
                            visible: root.albumArt === ""
                        }
                    }

                    Column {
                        anchors.left: coverBox.right
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        anchors.topMargin: 16
                        anchors.bottomMargin: 14
                        spacing: 6

                        Text {
                            width: parent.width
                            text: root.trackText
                            color: Theme.fg
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 18
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: root.artistText
                            color: Theme.fgMuted
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                            elide: Text.ElideRight
                        }

                        Item {
                            width: parent.width
                            height: 16
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: 4
                                radius: 2
                                color: Theme.surface1
                                Rectangle {
                                    width: root.length > 0 ? parent.width * (root.position / root.length) : 0
                                    height: parent.height
                                    radius: 2
                                    color: Theme.accent
                                    Behavior on width { NumberAnimation { duration: 250 } }
                                }
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: 8

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.formatTime(root.position)
                                color: Theme.fgMuted
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                            }

                            Item { width: parent.width - 160; height: 1 }

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 18

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "󰒮"
                                    color: prevArea.containsMouse ? Theme.accent : Theme.fg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 22
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    MouseArea {
                                        id: prevArea
                                        anchors.fill: parent
                                        anchors.margins: -6
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { if (root.player) root.player.previous() }
                                    }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.player && root.player.isPlaying ? "󰏤" : "󰐊"
                                    color: playArea.containsMouse ? Theme.accent : Theme.fg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 28
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    MouseArea {
                                        id: playArea
                                        anchors.fill: parent
                                        anchors.margins: -6
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { if (root.player) root.player.togglePlaying() }
                                    }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "󰒭"
                                    color: nextArea.containsMouse ? Theme.accent : Theme.fg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 22
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    MouseArea {
                                        id: nextArea
                                        anchors.fill: parent
                                        anchors.margins: -6
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { if (root.player) root.player.next() }
                                    }
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.formatTime(root.length)
                                color: Theme.fgMuted
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                            }
                        }
                    }
                }

                Column {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 120
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12

                    Rectangle {
                        width: 360
                        height: 54
                        radius: 16
                        color: Theme.surface
                        border.color: passwordInput.activeFocus ? Theme.accent : Theme.surface1
                        border.width: 2
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        TextInput {
                            id: passwordInput
                            anchors.fill: parent
                            anchors.margins: 14
                            echoMode: TextInput.Password
                            color: Theme.fg
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 18
                            focus: true
                            selectByMouse: true
                            passwordCharacter: "•"

                            onTextChanged: {
                                root.password = text
                                root.errorMessage = ""
                            }

                            onAccepted: {
                                if (root.authenticating) return
                                root.authenticating = true
                                pam.start()
                            }
                        }

                        Text {
                            anchors.fill: parent
                            anchors.margins: 14
                            text: "Введите пароль..."
                            color: Theme.fgMuted
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 16
                            visible: passwordInput.text === ""
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.authenticating ? "Проверка..." : root.errorMessage
                        color: root.authenticating ? Theme.yellow : Theme.red
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        visible: root.authenticating || root.errorMessage !== ""
                    }
                }
            }

            Component.onCompleted: {
                passwordInput.forceActiveFocus()
            }
        }
    }
}
