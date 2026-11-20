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
    property string device: ""
    property string devicePath: ""
    property int current: 0
    property int maximum: 100
    property int percent: maximum > 0 ? Math.round(current * 100 / maximum) : 0
    property bool ready: false

    function refresh() {
        detectProc.running = true
    }

    function setPercent(p) {
        if (!available || maximum <= 0) return
        var target = Math.max(0, Math.min(100, Math.round(p)))
        var val = Math.round(target * maximum / 100)
        if (val < 1 && target > 0) val = 1
        setProc.command = ["bash", "-lc",
            "if [ -n '" + devicePath + "' ] && [ -w '" + devicePath + "/brightness' ]; then " +
            "  echo " + val + " > '" + devicePath + "/brightness'; " +
            "elif command -v brightnessctl >/dev/null 2>&1; then " +
            "  brightnessctl -q s " + target + "%; " +
            "fi"]
        setProc.running = true
        current = val
    }

    function step(deltaPercent) {
        setPercent(percent + deltaPercent)
    }

    Process {
        id: detectProc
        command: ["bash", "-lc",
            "d=$(ls -1 /sys/class/backlight 2>/dev/null | head -n 1); " +
            "if [ -n \"$d\" ] && [ -f \"/sys/class/backlight/$d/brightness\" ] && [ -f \"/sys/class/backlight/$d/max_brightness\" ]; then " +
            "  printf '%s\\t%s\\t%s\\n' \"$d\" \"$(cat /sys/class/backlight/$d/brightness 2>/dev/null)\" \"$(cat /sys/class/backlight/$d/max_brightness 2>/dev/null)\"; " +
            "fi"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var txt = (this.text || "").trim()
                if (txt === "") {
                    root.available = false
                    root.device = ""
                    root.devicePath = ""
                    root.ready = true
                    return
                }
                var p = txt.split("\t")
                root.device = p[0] || ""
                root.devicePath = "/sys/class/backlight/" + root.device
                root.current = parseInt(p[1] || "0") || 0
                root.maximum = parseInt(p[2] || "100") || 100
                root.available = root.device !== ""
                root.ready = true
            }
        }
    }

    Process { id: setProc; command: ["bash", "-c", "true"]; running: false; onExited: root.refresh() }

    Process {
        id: readProc
        command: ["bash", "-lc",
            "if [ -n '" + root.devicePath + "' ] && [ -f '" + root.devicePath + "/brightness' ]; then cat '" + root.devicePath + "/brightness'; fi"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var v = parseInt((this.text || "").trim())
                if (!isNaN(v)) root.current = v
            }
        }
    }

    Timer {
        interval: 1500
        running: root.available
        repeat: true
        onTriggered: readProc.running = true
    }

    Component.onCompleted: refresh()
}
