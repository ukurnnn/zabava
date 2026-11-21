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
    property string current: ""
    property var profiles: []
    property bool busy: false
    property string statusMessage: ""

    function backendLabel() {
        if (backend === "powerprofilesctl") return "powerprofilesctl"
        if (backend === "governor") return "cpufreq governor"
        return backend || "не найден"
    }

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
        detectProc.running = true
    }

    function setProfile(p) {
        if (!available || !p || busy) return
        busy = true
        if (backend === "powerprofilesctl") {
            setProc.command = ["bash", "-lc", "command -v powerprofilesctl >/dev/null 2>&1 && powerprofilesctl set " + p]
        } else if (backend === "governor") {
            var gov = "schedutil"
            if (p === "power-saver") gov = "powersave"
            else if (p === "performance") gov = "performance"
            else if (p === "balanced") gov = "balanced"

            var script = "gov='" + gov + "'; " +
                "if [ \"$gov\" = balanced ]; then " +
                "  avail=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors 2>/dev/null); " +
                "  if echo \"$avail\" | grep -qw schedutil; then gov=schedutil; " +
                "  elif echo \"$avail\" | grep -qw ondemand; then gov=ondemand; " +
                "  elif echo \"$avail\" | grep -qw conservative; then gov=conservative; " +
                "  elif echo \"$avail\" | grep -qw powersave; then gov=powersave; " +
                "  else gov=performance; fi; " +
                "fi; " +
                "fail=0; for f in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_governor; do [ -f \"$f\" ] || continue; echo \"$gov\" > \"$f\" 2>/dev/null || fail=1; done; " +
                "if [ \"$fail\" -ne 0 ] && command -v pkexec >/dev/null 2>&1; then " +
                "  pkexec sh -c 'g=\"$1\"; for f in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_governor; do [ -f \"$f\" ] && echo \"$g\" > \"$f\"; done' sh \"$gov\"; " +
                "fi"
            setProc.command = ["bash", "-lc", script]
        } else {
            busy = false
            return
        }
        setProc.running = true
    }

    Process {
        id: detectProc
        command: ["bash", "-lc",
            "if command -v powerprofilesctl >/dev/null 2>&1; then " +
            "  cur=$(powerprofilesctl get 2>/dev/null | tr -d '\\n'); " +
            "  profs=$(powerprofilesctl list 2>/dev/null | awk '/^[[:space:]]*[* ]?[[:space:]]*(power-saver|balanced|performance):/{gsub(/^[*[:space:]]+/,\"\",$1); sub(/:$/, \"\", $1); print $1}' | paste -sd, -); " +
            "  if [ -n \"$cur\" ] || [ -n \"$profs\" ]; then printf 'powerprofilesctl\\t%s\\t%s\\n' \"$cur\" \"$profs\"; exit 0; fi; " +
            "fi; " +
            "if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors ]; then " +
            "  avail=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors 2>/dev/null); " +
            "  curg=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null | tr -d '\\n'); " +
            "  profs=\"\"; " +
            "  echo \"$avail\" | grep -qw powersave && profs=\"power-saver\"; " +
            "  if echo \"$avail\" | grep -Eqw 'schedutil|ondemand|conservative'; then [ -n \"$profs\" ] && profs=\"$profs,\"; profs=\"${profs}balanced\"; fi; " +
            "  echo \"$avail\" | grep -qw performance && { [ -n \"$profs\" ] && profs=\"$profs,\"; profs=\"${profs}performance\"; }; " +
            "  curp=\"\"; " +
            "  case \"$curg\" in powersave) curp=\"power-saver\";; performance) curp=\"performance\";; schedutil|ondemand|conservative) curp=\"balanced\";; esac; " +
            "  if [ -n \"$profs\" ]; then printf 'governor\\t%s\\t%s\\n' \"$curp\" \"$profs\"; exit 0; fi; " +
            "fi"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var txt = (this.text || "").trim()
                if (txt === "") {
                    root.available = false
                    root.backend = ""
                    root.current = ""
                    root.profiles = []
                    root.statusMessage = "Профили питания недоступны (нет powerprofilesctl и cpufreq)"
                    return
                }
                var p = txt.split("\t")
                root.backend = p[0] || ""
                root.current = (p[1] || "").trim()
                var out = []
                var parts = (p[2] || "").split(",")
                for (var i = 0; i < parts.length; i++) {
                    var l = (parts[i] || "").trim()
                    if (l === "power-saver" || l === "balanced" || l === "performance") out.push(l)
                }
                root.profiles = out
                root.available = root.backend !== "" && out.length > 0
                if (root.available) {
                    root.statusMessage = "Backend: " + root.backendLabel() + (root.backend === "governor" ? " (может потребоваться pkexec)" : "")
                } else {
                    root.statusMessage = "Профили питания недоступны"
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
