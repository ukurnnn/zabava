import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Item {
    id: root
    implicitWidth: contentRow.implicitWidth + 8
    implicitHeight: 40

    property var player: null
    property string trackText: ""
    property string artistText: ""
    property string albumText: ""
    property string albumArt: ""
    property real position: 0
    property real length: 0
    property string mediaAccentHex: ""
    readonly property real progress: (length > 0 && position >= 0) ? Math.max(0, Math.min(1, position / length)) : 0
    readonly property bool playing: player ? player.isPlaying : false
    readonly property bool hasTrack: trackText !== "" || artistText !== ""

    function formatTime(sec) {
        if (sec === undefined || sec === null || isNaN(sec) || sec < 0) sec = 0
        var total = Math.floor(sec)
        var h = Math.floor(total / 3600)
        var m = Math.floor((total % 3600) / 60)
        var s = total % 60
        if (h > 0) return h + ":" + (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    Component.onCompleted: updatePlayer()

    function artFilePath(url) {
        if (!url) return ""
        var p = url.toString()
        if (p.indexOf("file://") === 0) p = p.substring(7)
        try { p = decodeURIComponent(p) } catch (e) {}
        return p
    }

    function updateMediaAccentState() {
        if (root.playing && root.mediaAccentHex !== "") {
            Theme.setMediaAccent(root.mediaAccentHex, true)
        } else {
            Theme.setMediaAccent(Theme.accent, false)
        }
    }

    function updatePlayer() {
        var players = Mpris.players ? Mpris.players.values : []
        var chosen = null

        if (players && players.length > 0) {
            for (var i = 0; i < players.length; i++) {
                if (players[i].isPlaying) { chosen = players[i]; break }
            }
            if (!chosen) {
                for (var j = 0; j < players.length; j++) {
                    if ((players[j].trackTitle && players[j].trackTitle !== "") || (players[j].trackArtist && players[j].trackArtist !== "")) {
                        chosen = players[j]; break
                    }
                }
            }
            if (!chosen) chosen = players[0]
        }

        if (!chosen && root.trackText !== "") {
            retryTimer.restart()
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
            root.mediaAccentHex = ""
            updateMediaAccentState()
            return
        }

        var title = chosen.trackTitle || ""
        var artist = chosen.trackArtist || ""
        if (title === "" && artist === "") {
            retryTimer.restart()
            return
        }

        root.trackText = title
        root.artistText = artist
        root.albumText = chosen.trackAlbum || ""
        root.albumArt = chosen.trackArtUrl || ""
        root.length = chosen.length || 0
        root.position = chosen.position || 0
        updateMediaAccentState()
    }


    onAlbumArtChanged: {
        var p = artFilePath(root.albumArt)
        if (p !== "" && p.indexOf("/") !== -1) {
            artColorProc.path = p
            artColorProc.command = ["python3", "-c", "import colorsys,sys;from PIL import Image;im=Image.open(sys.argv[1]).convert('RGB').resize((24,24));px=list(im.getdata());n=len(px);r=sum(p[0] for p in px)/n;g=sum(p[1] for p in px)/n;b=sum(p[2] for p in px)/n;h,l,s=colorsys.rgb_to_hls(r/255,g/255,b/255);s=min(1,max(0.35,s*1.35));l=max(0.35,min(0.62,l));rr,gg,bb=colorsys.hls_to_rgb(h,l,s);print('#%02x%02x%02x'%(int(rr*255),int(gg*255),int(bb*255)))", p]
            artColorProc.running = true
        } else {
            root.mediaAccentHex = ""
            updateMediaAccentState()
        }
    }

    onPlayingChanged: updateMediaAccentState()

    Connections {
        target: Mpris.players
        function onValuesChanged() { root.updatePlayer() }
    }

    Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onPostTrackChanged() { retryTimer.restart(); retryTimer2.restart() }
        function onIsPlayingChanged() { root.updatePlayer() }
        function onTrackArtUrlChanged() { root.updatePlayer() }
        function onTrackTitleChanged() { root.updatePlayer() }
        function onTrackArtistChanged() { root.updatePlayer() }
        function onPositionChanged() { if (root.player) root.position = root.player.position || 0 }
        function onLengthChanged() { root.length = root.player ? (root.player.length || 0) : 0 }
    }

    Timer {
        interval: 1000
        running: root.player !== null && root.playing
        repeat: true
        onTriggered: {
            if (root.player) {
                root.position = root.player.position || 0
                root.length = root.player.length || 0
            }
        }
    }

    Timer { id: retryTimer; interval: 350; repeat: false; onTriggered: root.updatePlayer() }
    Timer { id: retryTimer2; interval: 900; repeat: false; onTriggered: root.updatePlayer() }

    Process {
        id: artColorProc
        property string path: ""
        command: ["bash", "-c", "true"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var c = (this.text || "").trim()
                if (/^#[0-9a-fA-F]{6}$/.test(c)) root.mediaAccentHex = c
                else root.mediaAccentHex = ""
                root.updateMediaAccentState()
            }
        }
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 8

        Rectangle {
            id: coverThumb
            anchors.verticalCenter: parent.verticalCenter
            width: 28
            height: 28
            radius: 8
            color: Theme.surface
            clip: true
            border.color: (coverArea.containsMouse && root.player) ? Theme.accent : Theme.surface1
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: 150 } }

            Image {
                anchors.fill: parent
                source: root.albumArt
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: root.albumArt !== ""
            }

            Text {
                anchors.centerIn: parent
                text: root.playing ? "󰎈" : "󰎆"
                color: root.playing ? Theme.accent : Theme.fgMuted
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
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

        Item {
            id: textWrap
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: textCol.implicitWidth
            implicitHeight: textCol.implicitHeight
            width: implicitWidth
            height: implicitHeight
            clip: true

            Column {
                id: textCol
                spacing: 1
                width: Math.max(titleText.implicitWidth, metaRow.visible ? metaRow.implicitWidth : 0, 1)

                Text {
                    id: titleText
                    width: Math.min(implicitWidth, 220)
                    text: root.trackText !== "" ? root.trackText : (root.player ? (root.player.identity || "Медиа") : "Ничего не играет")
                    color: root.hasTrack ? (trackArea.containsMouse ? Theme.accent : Theme.fg) : Theme.fgMuted
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    font.bold: root.hasTrack
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                Row {
                    id: metaRow
                    spacing: 5
                    visible: root.artistText !== "" || (root.length > 0 && root.hasTrack)

                    Text {
                        width: visible ? Math.min(implicitWidth, 140) : 0
                        text: root.artistText
                        visible: root.artistText !== ""
                        color: Theme.fgMuted
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    Text {
                        visible: root.artistText !== "" && root.length > 0
                        text: "·"
                        color: Theme.overlay
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                    }

                    Text {
                        visible: root.length > 0
                        text: root.formatTime(root.position) + " / " + root.formatTime(root.length)
                        color: Theme.fgMuted
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                    }
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
                    if (wheel.angleDelta.y > 0) { if (root.player.canGoNext !== false) root.player.next() }
                    else { if (root.player.canGoPrevious !== false) root.player.previous() }
                }
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 24; height: 24; radius: 12
            color: playArea.containsMouse ? Theme.surface1 : "transparent"
            opacity: root.player ? 1 : 0.35
            Behavior on color { ColorAnimation { duration: 120 } }
            Text {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: root.playing ? 0 : 1
                text: root.playing ? "󰏤" : "󰐊"
                color: playArea.containsMouse ? Theme.accent : Theme.fg
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                Behavior on color { ColorAnimation { duration: 120 } }
            }
            MouseArea {
                id: playArea
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: root.player !== null
                onClicked: { if (root.player) root.player.togglePlaying() }
            }
        }
    }

    Rectangle {
        id: barProgress
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.bottomMargin: 1
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
            color: root.playing ? Theme.accent : Theme.overlay
            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }
            Behavior on color { ColorAnimation { duration: 200 } }
        }
    }

    onTrackTextChanged: {
        if (trackText !== "") retryTimer2.restart()
    }
}
