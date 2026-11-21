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

    property bool ddcutilInstalled: false
    property bool i2cPresent: false
    property var ddcMonitors: []
    property string statusMessage: ""

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
            var disp = devicePath !== "" ? " --bus " + devicePath : ""
            cmd = "ddcutil" + disp + " getvcp 10 --brief 2>/dev/null | awk '{print $4}'"
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
            var dispSet = devicePath !== "" ? " --bus " + devicePath : ""
            cmd = "if command -v ddcutil >/dev/null 2>&1; then ddcutil" + dispSet + " setvcp 10 " + val + "; fi"
        }
        setProc.command = ["bash", "-lc", cmd]
        setProc.running = true
        current = val
    }

    function step(deltaPercent) {
        setPercent(percent + deltaPercent)
    }

    function statusText() {
        if (available) return "Устройство: " + (device || backend || "backlight")
        if (!ready) return "Определение устройства..."
        if (ddcutilInstalled && !i2cPresent) return "DDC/CI: ddcutil установлен, но нет /dev/i2c-* (нужен i2c-dev и права/перезагрузка)"
        if (ddcutilInstalled && i2cPresent && ddcMonitors.length === 0) return "DDC/CI: ddcutil и i2c есть, но мониторы не обнаружены (включите DDC/CI в OSD)"
        if (ddcutilInstalled) return "DDC/CI: ddcutil найден, но яркость недоступна"
        return "Устройство подсветки не найдено (backlight/brightnessctl/ddcutil)"
    }

    Process {
        id: detectProc
        command: ["bash", "-lc",
            "i2c=0; ls /dev/i2c-* >/dev/null 2>&1 && i2c=1; " +
            "ddc=0; command -v ddcutil >/dev/null 2>&1 && ddc=1; " +
            "d=$(ls -1 /sys/class/backlight 2>/dev/null | head -n 1); " +
            "if [ -n \"$d\" ] && [ -f \"/sys/class/backlight/$d/brightness\" ] && [ -f \"/sys/class/backlight/$d/max_brightness\" ]; then " +
            "  printf 'sysfs\t%s\t/sys/class/backlight/%s\t%s\t%s\t%s\t%s\t\n' \"$d\" \"$d\" \"$(cat /sys/class/backlight/$d/brightness 2>/dev/null)\" \"$(cat /sys/class/backlight/$d/max_brightness 2>/dev/null)\" \"$ddc\" \"$i2c\"; exit 0; " +
            "fi; " +
            "if command -v brightnessctl >/dev/null 2>&1; then " +
            "  line=$(brightnessctl -m -c backlight 2>/dev/null | head -n 1); " +
            "  if [ -n \"$line\" ]; then " +
            "    dev=$(printf '%s' \"$line\" | awk -F, '{print $1}'); " +
            "    cur=$(printf '%s' \"$line\" | awk -F, '{print $3}'); " +
            "    max=$(printf '%s' \"$line\" | awk -F, '{print $5}'); " +
            "    [ -z \"$max\" ] && max=100; " +
            "    printf 'brightnessctl\t%s\t\t%s\t%s\t%s\t%s\t\n' \"$dev\" \"$cur\" \"$max\" \"$ddc\" \"$i2c\"; exit 0; " +
            "  fi; " +
            "fi; " +
            "if command -v light >/dev/null 2>&1; then " +
            "  cur=$(light -G 2>/dev/null | tr -d '\n'); " +
            "  if [ -n \"$cur\" ]; then printf 'light\tlight\t\t%s\t100\t%s\t%s\t\n' \"$cur\" \"$ddc\" \"$i2c\"; exit 0; fi; " +
            "fi; " +
            "if [ \"$ddc\" = \"1\" ]; then " +
            "  mons=$(ddcutil detect --brief 2>/dev/null | awk '/I2C bus:/{gsub(/.*\\/dev\\/i2c-/,\"\"); gsub(/[^0-9].*/,\"\"); if($0!=\"\") print $0}' | paste -sd, -); " +
            "  first=$(printf '%s' \"$mons\" | tr ',' '\n' | head -n 1); " +
            "  if [ -n \"$first\" ]; then " +
            "    out=$(ddcutil --bus \"$first\" getvcp 10 --brief 2>/dev/null | head -n 1); " +
            "    if [ -n \"$out\" ]; then " +
            "      cur=$(printf '%s' \"$out\" | awk '{print $4}'); " +
            "      max=$(printf '%s' \"$out\" | awk '{print $5}'); " +
            "      [ -z \"$max\" ] && max=100; " +
            "      if [ -n \"$cur\" ]; then printf 'ddcutil\tDDC/CI bus %s\t%s\t%s\t%s\t%s\t%s\t%s\n' \"$first\" \"$first\" \"$cur\" \"$max\" \"$ddc\" \"$i2c\" \"$mons\"; exit 0; fi; " +
            "    fi; " +
            "  fi; " +
            "  printf 'none\t\t\t0\t100\t%s\t%s\t%s\n' \"$ddc\" \"$i2c\" \"$mons\"; exit 0; " +
            "fi; " +
            "printf 'none\t\t\t0\t100\t%s\t%s\t\n' \"$ddc\" \"$i2c\""]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var txt = (this.text || "").trim()
                var p = txt === "" ? [] : txt.split("\t")
                var backend = p[0] || "none"
                root.ddcutilInstalled = (p[5] || "0") === "1"
                root.i2cPresent = (p[6] || "0") === "1"
                var monsRaw = (p[7] || "").trim()
                var mons = []
                if (monsRaw !== "") {
                    var parts = monsRaw.split(",")
                    for (var i = 0; i < parts.length; i++) {
                        var m = (parts[i] || "").trim()
                        if (m !== "") mons.push(m)
                    }
                }
                root.ddcMonitors = mons

                if (backend === "none" || backend === "") {
                    root.available = false
                    root.backend = ""
                    root.device = ""
                    root.devicePath = ""
                    root.current = 0
                    root.maximum = 100
                    root.ready = true
                    root.statusMessage = root.statusText()
                    return
                }

                root.backend = backend
                root.device = p[1] || ""
                root.devicePath = p[2] || ""
                var cur = parseFloat(p[3] || "0")
                var max = parseFloat(p[4] || "100")
                root.current = isNaN(cur) ? 0 : Math.round(cur)
                root.maximum = isNaN(max) || max <= 0 ? 100 : Math.round(max)
                root.available = true
                root.ready = true
                root.statusMessage = root.statusText()
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
