import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    implicitWidth: contentRow.implicitWidth
    implicitHeight: 24

    property var popup: null

    property string connType: "none"
    property string ssid: ""
    property int signal: -1

    // Один вызов вместо двух отдельных nmcli-процессов
    Process {
        id: netProc
        command: ["bash", "-c",
            "nmcli -t -f TYPE,CONNECTION,STATE device | grep ':connected$' | head -1; " +
            "nmcli -t -f IN-USE,SIGNAL dev wifi | grep '^\\*' | head -1 | cut -d: -f2"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n").filter(l => l !== "")
                var line = (lines[0] || "").trim()
                root.signal = (lines[1] !== undefined && lines[1] !== "" && !isNaN(parseInt(lines[1]))) ? parseInt(lines[1]) : -1

                if (line === "") {
                    root.connType = "none"
                    root.ssid = ""
                    return
                }
                var parts = line.split(":")
                var type = parts[0] || ""
                if (type.indexOf("wifi") !== -1) {
                    root.connType = "wifi"
                    root.ssid = parts[1] || ""
                } else if (type.indexOf("ethernet") !== -1) {
                    root.connType = "ethernet"
                    root.ssid = ""
                } else {
                    root.connType = "none"
                    root.ssid = ""
                }
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: netProc.running = true
    }

    readonly property string icon: {
        if (root.connType === "none") return "󰖪"
        if (root.connType === "ethernet") return "󰈀"
        if (root.signal >= 75) return "󰤨"
        if (root.signal >= 50) return "󰤥"
        if (root.signal >= 25) return "󰤢"
        return "󰤟"
    }

    readonly property color stateColor: {
        if (root.connType === "none") return Theme.red
        if (root.connType === "ethernet") return Theme.accent
        return Theme.green
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 6

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            color: mouseArea.containsMouse || (root.popup && root.popup.visible) ? Theme.yellow : root.stateColor
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 15
            Behavior on color { ColorAnimation { duration: 300 } }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: {
                if (root.connType === "none") return "Offline"
                if (root.connType === "ethernet") return "Ethernet"
                return root.ssid !== "" ? root.ssid : "Wi-Fi"
            }
            color: mouseArea.containsMouse || (root.popup && root.popup.visible) ? Theme.yellow : Theme.fg
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            elide: Text.ElideRight
            width: Math.min(implicitWidth, 150)
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.popup) root.popup.visible = !root.popup.visible
        }
    }
}
