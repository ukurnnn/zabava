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
    property string backend: ""
    property string device: ""
    property string devicePath: ""
    property int current: 0
    property int maximum: 100
    property int percent: maximum > 0 ? Math.round(current * 100 / maximum) : 0
    property bool ready: false

    function refresh() {
        detectProc.running = true
    }

    function refreshCurrent() {
        if (!available) return
        var cmd = "true"
        if (backend === "sysfs" && devicePath !== "") {
            cmd = "if [ -f '" + devicePath + "/brightness' ]; then cat '" + devicePath + "/brightness'; fi"
        } else if (backend === "brightnessctl" && device !== "") {
            var dev = device.replace(/'/g, "'\\''")
            cmd = "brightnessctl -m -d '" + dev + "' 2>/dev/null | awk -F, '{print $3}'"
        } else if (backend === "light") {
            cmd = "light -G 2>/dev/null"
        } else if (backend === "ddcutil") {
            cmd = "ddcutil getvcp 10 --brief 2>/dev/null | awk '{print $4}'"
        }
        readProc.command = ["bash", "-lc", cmd]
        readProc.running = true
    }

    function setPercent(p) {
        if (!available || maximum <= 0) return
        var target = Math.max(0, Math.min(100, Math.round(p)))
        var val = Math.round(target * maximum / 100)
        if (val < 1 && target > 0) val = 1
        var cmd = "true"
        var devArg = device !== "" ? "-d '" + device.replace(/'/g, "'\\''") + "' " : ""
        if (backend === "sysfs" && devicePath !== "") {
            cmd = "if [ -w '" + devicePath + "/brightness' ]; then echo " + val + " > '" + devicePath + "/brightness'; " +
                  "elif command -v brightnessctl >/dev/null 2>&1; then brightnessctl " + devArg + "-q s " + target + "%; fi"
        } else if (backend === "brightnessctl") {
            cmd = "if command -v brightnessctl >/dev/null 2>&1; then brightnessctl " + devArg + "-q s " + target + "%; fi"
        } else if (backend === "light") {
            cmd = "if command -v light >/dev/null 2>&1; then light -S " + target + "; fi"
        } else if (backend === "ddcutil") {
            cmd = "if command -v ddcutil >/dev/null 2>&1; then ddcutil setvcp 10 " + val + "; fi"
        }
        setProc.command = ["bash", "-lc", cmd]
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
            "  printf 'sysfs\\t%s\\t/sys/class/backlight/%s\\t%s\\t%s\\n' \"$d\" \"$d\" \"$(cat /sys/class/backlight/$d/brightness 2>/dev/null)\" \"$(cat /sys/class/backlight/$d/max_brightness 2>/dev/null)\"; exit 0; " +
            "fi; " +
            "if command -v brightnessctl >/dev/null 2>&1; then " +
            "  line=$(brightnessctl -m -c backlight 2>/dev/null | head -n 1); " +
            "  if [ -n \"$line\" ]; then " +
            "    dev=$(printf '%s' \"$line\" | awk -F, '{print $1}'); " +
            "    cur=$(printf '%s' \"$line\" | awk -F, '{print $3}'); " +
            "    max=$(printf '%s' \"$line\" | awk -F, '{print $5}'); " +
            "    [ -z \"$max\" ] && max=100; " +
            "    printf 'brightnessctl\\t%s\\t\\t%s\\t%s\\n' \"$dev\" \"$cur\" \"$max\"; exit 0; " +
            "  fi; " +
            "fi; " +
            "if command -v light >/dev/null 2>&1; then " +
            "  cur=$(light -G 2>/dev/null | tr -d '\\n'); " +
            "  if [ -n \"$cur\" ]; then printf 'light\\tlight\\t\\t%s\\t100\\n' \"$cur\"; exit 0; fi; " +
            "fi; " +
            "if command -v ddcutil >/dev/null 2>&1; then " +
            "  out=$(ddcutil getvcp 10 --brief 2>/dev/null | head -n 1); " +
            "  if [ -n \"$out\" ]; then " +
            "    cur=$(printf '%s' \"$out\" | awk '{print $4}'); " +
            "    max=$(printf '%s' \"$out\" | awk '{print $5}'); " +
            "    [ -z \"$max\" ] && max=100; " +
            "    if [ -n \"$cur\" ]; then printf 'ddcutil\\tddcutil\\t\\t%s\\t%s\\n' \"$cur\" \"$max\"; exit 0; fi; " +
            "  fi; " +
            "fi"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var txt = (this.text || "").trim()
                if (txt === "") {
                    root.available = false
                    root.backend = ""
                    root.device = ""
                    root.devicePath = ""
                    root.ready = true
                    return
                }
                var p = txt.split("\t")
                root.backend = p[0] || ""
                root.device = p[1] || ""
                root.devicePath = p[2] || ""
                var cur = parseFloat(p[3] || "0")
                var max = parseFloat(p[4] || "100")
                root.current = isNaN(cur) ? 0 : Math.round(cur)
                root.maximum = isNaN(max) || max <= 0 ? 100 : Math.round(max)
                root.available = root.backend !== ""
                root.ready = true
            }
        }
    }

    Process { id: setProc; command: ["bash", "-c", "true"]; running: false; onExited: root.refreshCurrent() }

    Process {
        id: readProc
        command: ["bash", "-c", "true"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var v = parseFloat((this.text || "").trim())
                if (!isNaN(v)) root.current = Math.round(v)
            }
        }
    }

    Timer {
        interval: root.backend === "ddcutil" ? 10000 : 1500
        running: root.available
        repeat: true
        onTriggered: root.refreshCurrent()
    }

    Component.onCompleted: refresh()
}
