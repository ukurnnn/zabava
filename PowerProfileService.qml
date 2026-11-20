pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    visible: false
    width: 0
    height: 0

    property bool available: false
    property string current: ""
    property var profiles: []
    property bool busy: false

    function labelFor(p) {
        if (p === "power-saver") return "Экономия"
        if (p === "balanced") return "Сбалансированный"
        if (p === "performance") return "Производительность"
        return p || ""
    }

    function iconFor(p) {
        if (p === "power-saver") return "󰌪"
        if (p === "balanced") return "󰗑"
        if (p === "performance") return "󱐋"
        return "󰾅"
    }

    function refresh() {
        getProc.running = true
        listProc.running = true
    }

    function setProfile(p) {
        if (!available || !p || busy) return
        busy = true
        setProc.command = ["powerprofilesctl", "set", p]
        setProc.running = true
    }

    Process {
        id: getProc
        command: ["bash", "-lc", "command -v powerprofilesctl >/dev/null 2>&1 && powerprofilesctl get || true"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var v = (this.text || "").trim()
                if (v === "power-saver" || v === "balanced" || v === "performance") {
                    root.available = true
                    root.current = v
                } else if (v === "") {
                    // could still be available but failed; listProc will clarify
                } else {
                    root.current = v
                }
            }
        }
    }

    Process {
        id: listProc
        command: ["bash", "-lc", "command -v powerprofilesctl >/dev/null 2>&1 && powerprofilesctl list 2>/dev/null | awk '/^[[:space:]]*[* ]?[[:space:]]*(power-saver|balanced|performance):/{gsub(/^[*[:space:]]+/,\"\",$1); sub(/:$/, \"\", $1); print $1}' || true"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = (this.text || "").trim().split("\n")
                var out = []
                for (var i = 0; i < lines.length; i++) {
                    var l = (lines[i] || "").trim()
                    if (l === "power-saver" || l === "balanced" || l === "performance") out.push(l)
                }
                if (out.length > 0) {
                    root.profiles = out
                    root.available = true
                } else if ((root.current || "") !== "") {
                    root.available = true
                    root.profiles = [root.current]
                } else {
                    root.available = false
                    root.profiles = []
                }
            }
        }
    }

    Process {
        id: setProc
        command: ["true"]
        running: false
        onExited: (code, status) => {
            root.busy = false
            root.refresh()
        }
    }

    Component.onCompleted: refresh()
}
