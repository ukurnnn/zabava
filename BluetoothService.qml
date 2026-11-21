pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    visible: false; width: 0; height: 0

    property bool available: false
    property bool powered: false
    property bool busy: false
    property var devices: [] // {mac,name,connected,paired,icon,battery}
    property string statusMessage: ""

    function refresh() { if (!detectProc.running) detectProc.running = true }
    function refreshDevices() { if (available && !listProc.running) listProc.running = true }

    function togglePower() {
        if (!available || busy) return
        busy = true
        setProc.command = ["bash", "-lc", "bluetoothctl power " + (powered ? "off" : "on")]
        setProc.running = true
    }
    function connect(mac) {
        if (!available || busy || !mac) return
        busy = true
        setProc.command = ["bash", "-lc", "bluetoothctl connect " + mac]
        setProc.running = true
    }
    function disconnect(mac) {
        if (!available || busy || !mac) return
        busy = true
        setProc.command = ["bash", "-lc", "bluetoothctl disconnect " + mac]
        setProc.running = true
    }

    function iconFor(d) {
        var n = ((d.name || "") + " " + (d.icon || "")).toLowerCase()
        if (n.indexOf("head") !== -1 || n.indexOf("audio") !== -1) return "󰋋"
        if (n.indexOf("phone") !== -1) return "󰄜"
        if (n.indexOf("keyboard") !== -1) return "󰌌"
        if (n.indexOf("mouse") !== -1) return "󰍽"
        return "󰂯"
    }

    Process {
        id: detectProc
        command: ["bash", "-lc", "command -v bluetoothctl >/dev/null 2>&1 || { echo unavailable; exit 0; }; bluetoothctl show 2>/dev/null | awk -F': ' '/Powered:/{p=$2} END{if(p==\"\") print \"unavailable\"; else print \"ok\\t\" p}'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var txt = (this.text || "").trim()
                if (txt === "" || txt === "unavailable") {
                    root.available = false; root.powered = false; root.devices = []
                    root.statusMessage = "Bluetooth недоступен (bluetoothctl/bluez не найден)"
                    return
                }
                var p = txt.split("\t")
                root.available = p[0] === "ok"
                root.powered = (p[1] || "").trim() === "yes"
                root.statusMessage = root.available ? (root.powered ? "Bluetooth включён" : "Bluetooth выключен") : "Bluetooth недоступен"
                if (root.available && root.powered) root.refreshDevices()
                else if (!root.powered) root.devices = []
            }
        }
    }

    Process {
        id: listProc
        command: ["bash", "-lc",
            "bluetoothctl devices 2>/dev/null | while read -r _ mac rest; do " +
            "  [ -n \"$mac\" ] || continue; " +
            "  info=$(bluetoothctl info \"$mac\" 2>/dev/null); " +
            "  name=$(printf '%s\\n' \"$info\" | awk -F': ' '/Name:/{print $2; exit}'); " +
            "  [ -n \"$name\" ] || name=\"$rest\"; " +
            "  icon=$(printf '%s\\n' \"$info\" | awk -F': ' '/Icon:/{print $2; exit}'); " +
            "  conn=$(printf '%s\\n' \"$info\" | awk -F': ' '/Connected:/{print $2; exit}'); " +
            "  pair=$(printf '%s\\n' \"$info\" | awk -F': ' '/Paired:/{print $2; exit}'); " +
            "  bat=$(printf '%s\\n' \"$info\" | awk -F'[()]' '/Battery Percentage:/{gsub(/[^0-9]/,\"\",$2); print $2; exit}'); " +
            "  printf '%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n' \"$mac\" \"$name\" \"$conn\" \"$pair\" \"$icon\" \"$bat\"; " +
            "done"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = (this.text || "").trim().split("\n")
                var out = []
                for (var i = 0; i < lines.length; i++) {
                    var line = (lines[i] || "").trim()
                    if (line === "") continue
                    var p = line.split("\t")
                    var d = {
                        mac: p[0] || "", name: p[1] || p[0] || "", connected: (p[2] || "") === "yes",
                        paired: (p[3] || "") === "yes", icon: p[4] || "", battery: parseInt(p[5] || "") || -1
                    }
                    d.iconGlyph = root.iconFor(d)
                    out.push(d)
                }
                out.sort(function(a,b) { return (b.connected?1:0)-(a.connected?1:0) || (b.paired?1:0)-(a.paired?1:0) })
                root.devices = out
            }
        }
    }

    Process {
        id: setProc
        command: ["true"]; running: false
        onExited: { root.busy = false; root.refresh() }
    }

    Timer {
        interval: 8000
        running: root.available && root.powered
        repeat: true
        onTriggered: root.refreshDevices()
    }

    Component.onCompleted: refresh()
}
