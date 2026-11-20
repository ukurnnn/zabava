import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris

PanelWindow {
    id: root

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    visible: false
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-controlcenter"
    WlrLayershell.keyboardFocus: root.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property var panelWindow: null
    property var appLauncher: null
    property var clipboardMenu: null
    property var calendarPopup: null
    property var weatherPopup: null
    property var themeMenu: null
    property var powerMenu: null
    property var audioPopup: null
    property var networkPopup: null
    property var playerPopup: null
    property var caffeineModule: null
    property var networkModule: null
    property var weatherModule: null

    property string currentPage: "network"
    property string navZone: "sidebar"
    property int contentFocusIndex: 0
    property var sink: Pipewire.defaultAudioSink
    property var sinkAudio: sink ? sink.audio : null
    property var source: Pipewire.defaultAudioSource
    property var sourceAudio: source ? source.audio : null
    property var headphoneBatteries: []
    readonly property var nodes: {
        var n = Pipewire.nodes
        if (!n) return []
        var v = n.values !== undefined ? n.values : n
        return v || []
    }

    PwObjectTracker {
        objects: {
            var list = [root.sink, root.source]
            var n = root.nodes || []
            for (var i = 0; i < n.length; i++) list.push(n[i])
            return list
        }
    }
    property string netConnType: "none"
    property string netSsid: ""
    property int netSignal: -1
    property string netDevice: ""
    property string netIpAddr: ""
    property var netWifiNetworks: []
    property bool netScanning: false
    property bool netWifiEnabled: true
    property var player: null
    property string mediaTitle: ""
    property string mediaArtist: ""
    property string mediaArt: ""
    property bool mediaPlaying: false
    property string activeColorPreset: ""
    property string wallpaperColorMode: "dark"
    readonly property string colorPresetsFile: Quickshell.env("HOME") + "/.config/quickshell/color-presets.json"
    readonly property var stonePalette: {"bg": "#2d3033", "surface": "#36393d", "surface1": "#41454a", "overlay": "#949494", "fg": "#e8e8e6", "fgMuted": "#bdbdb8", "accent": "#6f9eb0", "accent2": "#aba884", "green": "#8faa84", "yellow": "#aba884", "orange": "#949494", "red": "#c07a7a", "mauve": "#6f9eb0"}
    readonly property var colorPresets: [
        { id: "wallpaper",        name: "Из обоев",           mode: "dynamic", kind: "wallpaper", seed: "#7aa2f7" },
        { id: "stone-trio",       name: "Stone Trio",         mode: "dark",    kind: "custom",   seed: "#6f9eb0", palette: {"bg": "#2d3033", "surface": "#36393d", "surface1": "#41454a", "overlay": "#949494", "fg": "#e8e8e6", "fgMuted": "#bdbdb8", "accent": "#6f9eb0", "accent2": "#aba884", "green": "#8faa84", "yellow": "#aba884", "orange": "#949494", "red": "#c07a7a", "mauve": "#6f9eb0"} },
        { id: "catppuccin-mocha", name: "Catppuccin Mocha",   mode: "dark",    seed: "#89b4fa" },
        { id: "nord",             name: "Nord",               mode: "dark",    seed: "#88c0d0" },
        { id: "gruvbox",          name: "Gruvbox",            mode: "dark",    seed: "#d79921" },
        { id: "rose-pine",        name: "Rosé Pine",          mode: "dark",    seed: "#c4a7e7" },
        { id: "dracula",          name: "Dracula",            mode: "dark",    seed: "#bd93f9" },
        { id: "tokyo-night",      name: "Tokyo Night",        mode: "dark",    seed: "#7aa2f7" },
        { id: "everforest",       name: "Everforest",         mode: "dark",    seed: "#a7c080" },
        { id: "solarized-dark",   name: "Solarized",          mode: "dark",    seed: "#268bd2" },
        { id: "peach",            name: "Peach",              mode: "dark",    seed: "#fab387" },
        { id: "red",              name: "Red",                mode: "dark",    seed: "#f38ba8" },
        { id: "mono",             name: "Monochrome",         mode: "dark",    seed: "#808080", type: "scheme-monochrome" },
        { id: "catppuccin-latte", name: "Catppuccin Latte",   mode: "light",   seed: "#1e66f5" },
        { id: "rose-pine-dawn",   name: "Rosé Pine Dawn",     mode: "light",   seed: "#907aa9" },
        { id: "gruvbox-light",    name: "Gruvbox Light",      mode: "light",   seed: "#d79921" },
        { id: "solarized-light",  name: "Solarized Light",    mode: "light",   seed: "#268bd2" },
        { id: "nord-light",       name: "Nord Light",         mode: "light",   seed: "#5e81ac" },
        { id: "peach-light",      name: "Peach Light",        mode: "light",   seed: "#fe640b" }
    ]

    readonly property var pages: [
        { id: "network", icon: "󰖩", label: "Сеть" },
        { id: "audio", icon: "󰕾", label: "Звук" },
        { id: "notifications", icon: "󰂚", label: "Уведомления" },
        { id: "bar", icon: "󰕰", label: "Бар" },
        { id: "colors", icon: "󰏘", label: "Цвета" },
        { id: "power", icon: "󰐥", label: "Питание" },
        { id: "general", icon: "󰒓", label: "Общие" }
    ]

    IpcHandler {
        target: "controlcenter"
        function toggle(): void { root.visible = !root.visible }
    }

    function openAndClose(target) {
        if (target) target.visible = true
        root.visible = false
    }

    function pageTitle(id) {
        for (var i = 0; i < pages.length; i++) if (pages[i].id === id) return pages[i].label
        return "Настройки"
    }

    function pageIndex(id) {
        for (var i = 0; i < pages.length; i++) if (pages[i].id === id) return i
        return 0
    }

    function netItemCount() { return 3 + (netWifiNetworks ? netWifiNetworks.length : 0) }
    function audioItemCount() { return 5 + outputNodes().length + inputNodes().length }
    function notifItemCount() { return 2 + (NotificationService.history ? NotificationService.history.count : 0) }
    function barItemCount() { return 3 + BarConfig.allPresets().length + 1 }
    function colorsItemCount() { return 2 + colorPresetsByMode("dark").length + colorPresetsByMode("light").length }

    function contentCount(pageId) {
        if (pageId === "network") return netItemCount()
        if (pageId === "audio") return audioItemCount()
        if (pageId === "notifications") return notifItemCount()
        if (pageId === "bar") return barItemCount()
        if (pageId === "colors") return colorsItemCount()
        if (pageId === "power") return 5
        if (pageId === "general") return 8
        return 0
    }

    function clampContentFocus() {
        var c = contentCount(currentPage)
        if (c <= 0) { contentFocusIndex = 0; return }
        if (contentFocusIndex < 0) contentFocusIndex = 0
        if (contentFocusIndex >= c) contentFocusIndex = c - 1
    }

    function moveSidebar(delta) {
        var i = pageIndex(currentPage) + delta
        if (i < 0) i = pages.length - 1
        if (i >= pages.length) i = 0
        currentPage = pages[i].id
        contentFocusIndex = 0
        navZone = "sidebar"
    }

    function activateFocused() {
        var idx = contentFocusIndex
        if (currentPage === "network") {
            if (idx === 0) refreshNetwork()
            else if (idx === 1) toggleWifiRadio()
            else if (idx === 2) openAndClose(networkPopup)
            else {
                var ni = idx - 3
                if (ni >= 0 && ni < netWifiNetworks.length) {
                    var n = netWifiNetworks[ni]
                    if (n.inUse) netActionProc.command = ["bash", "-lc", "nmcli device disconnect " + (root.netDevice || "wlan0")]
                    else {
                        var ssid = (n.ssid || "").replace(/'/g, "'\\''")
                        netActionProc.command = ["bash", "-lc", "nmcli dev wifi connect '" + ssid + "' || nm-connection-editor >/dev/null 2>&1 &"]
                    }
                    netActionProc.running = true
                }
            }
        } else if (currentPage === "audio") {
            var outs = outputNodes()
            var ins = inputNodes()
            var inMuteIdx = 3 + outs.length
            var inStart = inMuteIdx + 1
            var openIdx = inStart + ins.length
            if (idx === 0) { if (sinkAudio) sinkAudio.muted = !sinkAudio.muted }
            else if (idx === 1) openAndClose(audioPopup)
            else if (idx >= 2 && idx < 2 + outs.length) setDefaultSink(outs[idx - 2])
            else if (idx === inMuteIdx) Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_SOURCE@", "toggle"])
            else if (idx >= inStart && idx < openIdx) setDefaultSource(ins[idx - inStart])
            else if (idx === openIdx) openAndClose(playerPopup)
        } else if (currentPage === "notifications") {
            if (idx === 0) NotificationService.toggleDnd()
            else if (idx === 1) NotificationService.dismissAll()
            else {
                var ni = idx - 2
                if (NotificationService.history && ni >= 0 && ni < NotificationService.history.count)
                    NotificationService.dismiss(NotificationService.history.get(ni).id)
            }
        } else if (currentPage === "bar") {
            if (idx === 0) BarConfig.setStyle("islands")
            else if (idx === 1) BarConfig.setStyle("monolithic")
            else if (idx === 2) BarConfig.setStyle("full")
            else {
                var presets = BarConfig.allPresets()
                var pi = idx - 3
                if (pi >= 0 && pi < presets.length) BarConfig.applyPreset(presets[pi].id)
                else if (pi === presets.length) BarConfig.saveCurrentAsMyPreset()
            }
        } else if (currentPage === "colors") {
            var dyn = colorPresetsByMode("dynamic")
            var darks = colorPresetsByMode("dark")
            var lights = colorPresetsByMode("light")
            if (idx === 0 && dyn.length > 0) applyColorPreset(dyn[0])
            else if (idx === 1) {
                wallpaperColorMode = (wallpaperColorMode === "dark" ? "light" : "dark")
                saveColorPresets()
                if (activeColorPreset === "wallpaper" && dyn.length > 0) applyColorPreset(dyn[0])
            } else {
                var ci = idx - 2
                if (ci >= 0 && ci < darks.length) applyColorPreset(darks[ci])
                else if (ci >= darks.length && ci < darks.length + lights.length) applyColorPreset(lights[ci - darks.length])
            }
        } else if (currentPage === "power") {
            var cmds = [
                ["loginctl", "lock-session"],
                ["niri", "msg", "action", "quit", "-s"],
                ["systemctl", "suspend"],
                ["systemctl", "reboot"],
                ["systemctl", "poweroff"]
            ]
            if (idx >= 0 && idx < cmds.length) { root.visible = false; Quickshell.execDetached(cmds[idx]) }
        } else if (currentPage === "general") {
            if (idx === 0) { if (caffeineModule) caffeineModule.toggle() }
            else if (idx === 1) Quickshell.execDetached(["niri", "msg", "action", "switch-layout", "next"])
            else if (idx === 2) openAndClose(appLauncher)
            else if (idx === 3) openAndClose(clipboardMenu)
            else if (idx === 4) openAndClose(calendarPopup)
            else if (idx === 5) currentPage = "colors"
            else if (idx === 6) openAndClose(playerPopup)
            else if (idx === 7) openAndClose(powerMenu)
        }
    }

    onVisibleChanged: {
        if (visible) {
            navZone = "sidebar"
            contentFocusIndex = 0
            keyHandler.forceActiveFocus()
            if (currentPage === "network") refreshNetwork()
            if (currentPage === "audio") refreshBatteries()
        }
    }

    onCurrentPageChanged: {
        contentFocusIndex = 0
        if (!visible) return
        if (currentPage === "network") refreshNetwork()
        if (currentPage === "audio") refreshBatteries()
    }
    function batteryIcon(percent) {
        var p = Math.max(0, Math.min(100, percent))
        if (p >= 95) return "󰥈"
        if (p >= 85) return "󰥆"
        if (p >= 75) return "󰥅"
        if (p >= 65) return "󰥄"
        if (p >= 55) return "󰥃"
        if (p >= 45) return "󰥂"
        if (p >= 35) return "󰥁"
        if (p >= 25) return "󰥀"
        if (p >= 15) return "󰤿"
        if (p >= 5)  return "󰤾"
        return "󰥇"
    }
    function batteryColor(percent) {
        if (percent <= 15) return Theme.red
        if (percent <= 30) return Theme.orange
        return Theme.green
    }
    function refreshBatteries() { batteryProc.running = true }
    function nodeName(node) {
        if (!node) return "Unknown device"
        return node.description || node.nickname || node.name || "Unknown device"
    }
    function isOutputNode(node) {
        if (!node) return false
        var t = (node.type || "").toString()
        var n = (node.name || "").toString().toLowerCase()
        return t.indexOf("Sink") !== -1 || n.indexOf("sink") !== -1
    }
    function isInputNode(node) {
        if (!node) return false
        var t = (node.type || "").toString()
        var n = (node.name || "").toString().toLowerCase()
        return t.indexOf("Source") !== -1 || n.indexOf("source") !== -1
    }
    function outputNodes() {
        var out = [], list = root.nodes || []
        for (var i = 0; i < list.length; i++) {
            var n = list[i]
            if (isOutputNode(n) && !isInputNode(n)) out.push(n)
        }
        return out
    }
    function inputNodes() {
        var out = [], list = root.nodes || []
        for (var i = 0; i < list.length; i++) {
            var n = list[i]
            if (isInputNode(n) && !isOutputNode(n)) out.push(n)
        }
        return out
    }
    function setDefaultSink(node) {
        if (!node) return
        try { if (Pipewire.preferredDefaultAudioSink !== undefined) { Pipewire.preferredDefaultAudioSink = node; return } } catch (e) {}
        try { if (node.isDefault !== undefined) node.isDefault = true } catch (e2) {}
    }
    function setDefaultSource(node) {
        if (!node) return
        try { if (Pipewire.preferredDefaultAudioSource !== undefined) { Pipewire.preferredDefaultAudioSource = node; return } } catch (e) {}
        try { if (node.isDefault !== undefined) node.isDefault = true } catch (e2) {}
    }
    function netSignalIcon(sig) {
        if (sig >= 75) return "󰤨"
        if (sig >= 50) return "󰤥"
        if (sig >= 25) return "󰤢"
        if (sig >= 0) return "󰤟"
        return "󰤯"
    }
    function refreshNetwork() {
        netStatusProc.running = true
        netScanProc.running = true
        root.netScanning = true
    }
    function toggleWifiRadio() {
        wifiToggleProc.command = ["bash", "-lc", "nmcli radio wifi " + (root.netWifiEnabled ? "off" : "on")]
        wifiToggleProc.running = true
    }
    function applyColorPreset(preset) {
        if (!preset) return
        root.activeColorPreset = preset.id || ""
        var out = Quickshell.env("HOME") + "/.config/quickshell/matugen-colors.json"
        if (preset.kind === "custom" && preset.palette) {
            try {
                var jsonPal = JSON.stringify(preset.palette).replace(/'/g, "'\\''")
                matugenApplyProc.command = ["bash", "-lc", "mkdir -p \"$HOME/.config/quickshell\" && printf '%s' '" + jsonPal + "' > " + out]
                matugenApplyProc.running = true
            } catch (e) {}
        } else if (preset.kind === "wallpaper") {
            var mode = root.wallpaperColorMode || "dark"
            var cmdStr = "cfg=\"$HOME/.config/waypaper/config.ini\"; wp=''; " +
                         "if [ -f \"$cfg\" ]; then " +
                         "  wp=$(grep -E '^[[:space:]]*wallpaper[[:space:]]*=' \"$cfg\" 2>/dev/null | tail -n1 | sed 's/^[^=]*=//;s/^[[:space:]]*//;s/[[:space:]]*$//'); " +
                         "fi; " +
                         "case \"$wp\" in \"~/\"*) wp=\"$HOME/${wp#~/}\";; '~') wp=\"$HOME\";; esac; " +
                         "if [ -z \"$wp\" ] || [ ! -f \"$wp\" ]; then " +
                         "  wp=$(find \"$HOME/Pictures/wallpapers\" \"$HOME/Pictures/Wallpapers\" \"$HOME/Загрузки/Wallpapers\" \"$HOME/wallpapers\" -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) 2>/dev/null | head -n 1); " +
                         "fi; " +
                         "if [ -n \"$wp\" ] && [ -f \"$wp\" ]; then matugen image \"$wp\" -m " + mode + " --source-color-index 0; fi"
            matugenApplyProc.command = ["bash", "-lc", cmdStr]
            matugenApplyProc.running = true
        } else {
            var cmd = ["matugen", "color", "hex", preset.seed, "-m", (preset.mode || "dark")]
            if (preset.type) cmd = cmd.concat(["-t", preset.type])
            matugenApplyProc.command = cmd
            matugenApplyProc.running = true
        }
        saveColorPresets()
    }

    function saveColorPresets() {
        try {
            var json = JSON.stringify({ active: root.activeColorPreset, wallpaperMode: root.wallpaperColorMode }).replace(/'/g, "'\\''")
            colorPresetSaveProc.command = ["bash", "-lc", "mkdir -p \"$HOME/.config/quickshell\" && printf '%s' '" + json + "' > " + colorPresetsFile]
            colorPresetSaveProc.running = true
        } catch (e) {}
    }

    function colorPresetsByMode(m) {
        var out = []
        var list = root.colorPresets || []
        for (var i = 0; i < list.length; i++) {
            if ((list[i].mode || "dark") === m) out.push(list[i])
        }
        return out
    }
    function updatePlayer() {
        var players = Mpris.players ? Mpris.players.values : []
        var chosen = null
        if (players) {
            for (var i = 0; i < players.length; i++) {
                if (players[i].isPlaying) { chosen = players[i]; break }
            }
            if (!chosen) {
                for (var j = 0; j < players.length; j++) {
                    if (players[j].trackTitle && players[j].trackTitle !== "") { chosen = players[j]; break }
                }
            }
        }
        root.player = chosen
        if (!chosen) {
            root.mediaTitle = ""; root.mediaArtist = ""; root.mediaArt = ""; root.mediaPlaying = false
            return
        }
        root.mediaTitle = chosen.trackTitle || ""
        root.mediaArtist = chosen.trackArtist || ""
        root.mediaArt = chosen.trackArtUrl || ""
        root.mediaPlaying = chosen.isPlaying === true
    }

    Component.onCompleted: updatePlayer()

    Connections {
        target: Mpris.players
        function onValuesChanged() { root.updatePlayer() }
    }
    Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onIsPlayingChanged() { root.updatePlayer() }
        function onPostTrackChanged() { root.updatePlayer() }
        function onTrackArtUrlChanged() { root.updatePlayer() }
    }
    Process {
        id: batteryProc
        command: ["bash", "-lc",
            "out=''; " +
            "def_sink=$(pactl get-default-sink 2>/dev/null || pactl info 2>/dev/null | awk -F': ' '/Default Sink:/{print $2; exit}'); " +
            "out=$(pactl list sinks 2>/dev/null | awk -v def=\"$def_sink\" ' " +
            "  $1==\"Sink\"{inb=0} " +
            "  $1==\"Name:\"{inb=1; sname=$2; desc=sname; pr=(sname==def?0:1)} " +
            "  inb && $1==\"Description:\"{sub(/^.*Description: /,\"\"); desc=$0} " +
            "  inb && index($0,\"battery\") && $0 ~ /%/{ " +
            "    line=$0; gsub(/^[ \\t]+/,\"\",line); " +
            "    if (match(line,/([0-9]{1,3})%/,m)) pct=m[1]; else pct=\"\"; " +
            "    sub(/:.*/,\"\",line); lbl=line; " +
            "    gsub(/bluetooth\\.battery\\.percentage|\\.percentage|\\.battery/,\"\",lbl); " +
            "    gsub(/[_\\.]+/,\" \",lbl); gsub(/^[ \\t]+|[ \\t]+$/,\"\",lbl); " +
            "    if (lbl==\"\") lbl=\"Battery\"; " +
            "    if (pct!=\"\") print pr \"\\t\" desc \"\\t\" lbl \"\\t\" pct; " +
            "  } " +
            "' | sort -n | cut -f2-); " +
            "if [ -n \"$out\" ]; then printf '%s\\n' \"$out\"; exit 0; fi; " +
            "if command -v headsetcontrol >/dev/null 2>&1; then " +
            "  hc=$(headsetcontrol -b 2>/dev/null || true); " +
            "  pct=$(printf '%s\\n' \"$hc\" | awk 'match($0,/([0-9]{1,3})%/,m){print m[1]; exit}'); " +
            "  if [ -n \"$pct\" ]; then printf '%s\\t%s\\t%s\\n' \"Headset\" \"\" \"$pct\"; exit 0; fi; " +
            "fi; " +
            "for dev in $(upower -e 2>/dev/null); do " +
            "  info=$(upower -i \"$dev\" 2>/dev/null) || continue; " +
            "  pct=$(printf '%s\\n' \"$info\" | awk '/^[[:space:]]*percentage:/{gsub(/%/,\"\",$2); print $2; exit}'); " +
            "  [ -z \"$pct\" ] && continue; " +
            "  model=$(printf '%s\\n' \"$info\" | awk -F: '/^[[:space:]]*model:/{sub(/^[^:]*:/,\"\",$0); gsub(/^[ \\t]+|[ \\t]+$/, \"\", $0); print $0; exit}'); " +
            "  icon=$(printf '%s\\n' \"$info\" | awk -F: '/^[[:space:]]*icon-name:/{sub(/^[^:]*:/,\"\",$0); gsub(/^[ \\t]+|[ \\t]+$/, \"\", $0); print $0; exit}'); " +
            "  np=$(printf '%s\\n' \"$info\" | awk -F: '/^[[:space:]]*native-path:/{sub(/^[^:]*:/,\"\",$0); gsub(/^[ \\t]+|[ \\t]+$/, \"\", $0); print $0; exit}'); " +
            "  low=$(printf '%s' \"$dev $model $icon $np\" | tr '[:upper:]' '[:lower:]'); " +
            "  case \"$low\" in *displaydevice*|*line_power*|*/ac*|*battery_bat*) continue ;; esac; " +
            "  case \"$low\" in *headset*|*headphone*|*earbud*|*airpod*|*buds*|*handsfree*|*audio-head*|*headset_dev*|*audio*) " +
            "      name=\"$model\"; [ -z \"$name\" ] && name=$(basename \"$dev\"); " +
            "      printf '%s\\t%s\\t%s\\n' \"$name\" \"\" \"${pct%.*}\" ;; esac; " +
            "done | awk -F'\\t' '!seen[$1\"\\t\"$3]++'"
        ]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = (this.text || "").trim().split("\n")
                var out = []
                for (var i = 0; i < lines.length; i++) {
                    var line = (lines[i] || "").trim()
                    if (line === "") continue
                    var parts = line.split("\t")
                    var name = (parts[0] || "Headphones").trim()
                    var label = ""
                    var pct = NaN
                    if (parts.length >= 3) { label = (parts[1] || "").trim(); pct = parseInt(parts[2]) }
                    else { pct = parseInt(parts[1]) }
                    if (isNaN(pct)) continue
                    var shownName = label && label !== "" && label.toLowerCase() !== "battery" ? name + " (" + label + ")" : name
                    out.push({ name: shownName, percent: pct })
                }
                root.headphoneBatteries = out
            }
        }
    }

    Process {
        id: netStatusProc
        command: ["bash", "-c",
            "nmcli -t -f TYPE,DEVICE,CONNECTION,STATE dev status | awk -F: '$4==\"connected\"{print $1\":\"$2\":\"$3; exit}'; " +
            "echo '---'; " +
            "nmcli -t -f IN-USE,SIGNAL dev wifi list --rescan no 2>/dev/null | awk -F: '$1==\"*\"{print $2; exit}'; " +
            "echo '---'; " +
            "ip -4 -o addr show scope global 2>/dev/null | awk '{print $4; exit}'; " +
            "echo '---'; " +
            "nmcli -t -f WIFI g 2>/dev/null | head -n 1"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.split("---")
                var line = ((parts[0] || "").trim().split("\n")[0] || "").trim()
                var sigLine = ((parts[1] || "").trim().split("\n")[0] || "").trim()
                root.netIpAddr = ((parts[2] || "").trim().split("\n")[0] || "").trim()
                var wifiState = ((parts[3] || "").trim().split("\n")[0] || "").toLowerCase()
                if (wifiState.indexOf("disabled") !== -1 || wifiState === "off") root.netWifiEnabled = false
                else if (wifiState.indexOf("enabled") !== -1 || wifiState === "on") root.netWifiEnabled = true
                root.netSignal = (sigLine !== "" && !isNaN(parseInt(sigLine))) ? parseInt(sigLine) : -1

                if (line === "") {
                    root.netConnType = "none"; root.netDevice = ""; root.netSsid = ""; return
                }
                var p = line.split(":")
                var type = p[0] || ""
                root.netDevice = p[1] || ""
                if (type.indexOf("wifi") !== -1) { root.netConnType = "wifi"; root.netSsid = p[2] || "" }
                else if (type.indexOf("ethernet") !== -1) { root.netConnType = "ethernet"; root.netSsid = "" }
                else { root.netConnType = "other"; root.netSsid = p[2] || "" }
            }
        }
    }

    Process {
        id: netScanProc
        command: ["bash", "-c", "nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list --rescan auto 2>/dev/null | head -n 12"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.netScanning = false
                var lines = this.text.split("\n")
                var seen = {}, out = []
                for (var i = 0; i < lines.length; i++) {
                    var line = (lines[i] || "").trim()
                    if (line === "") continue
                    var parts = line.split(":")
                    var inUse = parts[0] === "*"
                    var ssid = parts[1] || ""
                    var sig = parseInt(parts[2] || "0")
                    if (isNaN(sig)) sig = 0
                    var sec = parts.slice(3).join(":") || ""
                    if (ssid === "") ssid = "Hidden network"
                    var key = ssid + "|" + sig + "|" + sec
                    if (seen[key]) continue
                    seen[key] = true
                    out.push({ inUse: inUse, ssid: ssid, signal: sig, security: sec })
                }
                out.sort(function(a, b) { if (a.inUse !== b.inUse) return a.inUse ? -1 : 1; return b.signal - a.signal })
                root.netWifiNetworks = out
            }
        }
    }

    Process { id: netActionProc; command: ["bash", "-c", "true"]; running: false; onExited: root.refreshNetwork() }
    Process { id: wifiToggleProc; command: ["bash", "-lc", "nmcli radio wifi on"]; running: false; onExited: root.refreshNetwork() }

    FileView {
        id: colorPresetsView
        path: root.colorPresetsFile
        preload: true
        watchChanges: false
        printErrors: false
        onLoaded: {
            var txt = colorPresetsView.text().trim()
            if (txt === "") return
            try {
                var obj = JSON.parse(txt)
                if (obj && obj.active) root.activeColorPreset = obj.active
                if (obj && obj.wallpaperMode) root.wallpaperColorMode = obj.wallpaperMode
            } catch (e) {}
        }
    }

    Process { id: matugenApplyProc; command: ["true"]; running: false }
    Process { id: colorPresetSaveProc; command: ["bash", "-c", "true"]; running: false }

    Timer {
        interval: 15000
        running: root.visible && root.currentPage === "audio"
        repeat: true
        onTriggered: root.refreshBatteries()
    }
    Item {
        id: keyHandler
        anchors.fill: parent
        focus: true
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                root.visible = false
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier)) {
                root.moveSidebar(1)
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                root.moveSidebar(-1)
                event.accepted = true
                return
            }

            if (root.navZone === "sidebar") {
                if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                    root.moveSidebar(-1); event.accepted = true
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                    root.moveSidebar(1); event.accepted = true
                } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space || event.key === Qt.Key_L) {
                    root.contentFocusIndex = 0
                    root.navZone = "content"
                    event.accepted = true
                } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                    event.accepted = true
                }
                return
            }

            var count = root.contentCount(root.currentPage)
            if (count <= 0) {
                if (event.key === Qt.Key_Left || event.key === Qt.Key_H) { root.navZone = "sidebar"; event.accepted = true }
                return
            }

            var idx = root.contentFocusIndex
            function clampIdx(i) { return Math.max(0, Math.min(count - 1, i)) }

            if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                if (root.currentPage === "network" && idx === 2) idx = 1
                else if (root.currentPage === "bar" && idx > 0 && idx <= 2) idx = idx - 1
                else if (root.currentPage === "bar" && idx >= 3) { root.navZone = "sidebar"; event.accepted = true; return }
                else if (root.currentPage === "colors" && idx === 1) idx = 0
                else if (root.currentPage === "colors" && idx >= 2) {
                    var dc = root.colorPresetsByMode("dark").length
                    var ci = idx - 2
                    if (ci < dc) { if (ci % 2 === 1) idx = idx - 1; else { root.navZone = "sidebar"; event.accepted = true; return } }
                    else { var li = ci - dc; if (li % 2 === 1) idx = idx - 1; else { root.navZone = "sidebar"; event.accepted = true; return } }
                } else if (root.currentPage === "general" && idx === 1) idx = 0
                else if (root.currentPage === "general" && idx >= 2) {
                    var gi = idx - 2
                    if (gi % 3 !== 0) idx = idx - 1
                    else { root.navZone = "sidebar"; event.accepted = true; return }
                } else if (root.currentPage === "audio") {
                    if (idx === 0) { root.navZone = "sidebar"; event.accepted = true; return }
                    else if (idx >= 1 && idx <= 1) idx = 0
                    else if (idx > 1) idx = idx - 1
                } else if (root.currentPage === "notifications" && idx === 1) idx = 0
                else { root.navZone = "sidebar"; event.accepted = true; return }
                root.contentFocusIndex = clampIdx(idx)
                event.accepted = true
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                if (root.currentPage === "network" && idx === 1) idx = 2
                else if (root.currentPage === "bar" && idx >= 0 && idx < 2) idx = idx + 1
                else if (root.currentPage === "colors" && idx === 0) idx = 1
                else if (root.currentPage === "colors" && idx >= 2) {
                    var dc2 = root.colorPresetsByMode("dark").length
                    var lc2 = root.colorPresetsByMode("light").length
                    var ci2 = idx - 2
                    if (ci2 < dc2) { if (ci2 % 2 === 0 && ci2 + 1 < dc2) idx = idx + 1 }
                    else { var li2 = ci2 - dc2; if (li2 % 2 === 0 && li2 + 1 < lc2) idx = idx + 1 }
                } else if (root.currentPage === "general" && idx === 0) idx = 1
                else if (root.currentPage === "general" && idx >= 2) {
                    var gi2 = idx - 2
                    if (gi2 % 3 !== 2 && idx + 1 < count) idx = idx + 1
                } else if (root.currentPage === "audio") {
                    idx = clampIdx(idx + 1)
                } else if (root.currentPage === "notifications" && idx === 0) idx = 1
                else idx = clampIdx(idx + 1)
                root.contentFocusIndex = clampIdx(idx)
                event.accepted = true
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                if (root.currentPage === "bar") {
                    if (idx <= 2) { root.navZone = "sidebar"; event.accepted = true; return }
                    else if (idx === 3) idx = 0
                    else idx = idx - 1
                } else if (root.currentPage === "colors") {
                    var dc3 = root.colorPresetsByMode("dark").length
                    if (idx <= 1) { root.navZone = "sidebar"; event.accepted = true; return }
                    else {
                        var ci3 = idx - 2
                        if (ci3 < dc3) {
                            if (ci3 < 2) idx = 0
                            else idx = idx - 2
                        } else {
                            var li3 = ci3 - dc3
                            if (li3 < 2) idx = 2 + Math.max(0, dc3 - 2 + (li3 % 2))
                            else idx = idx - 2
                        }
                    }
                } else if (root.currentPage === "general") {
                    if (idx <= 1) { root.navZone = "sidebar"; event.accepted = true; return }
                    else if (idx <= 4) idx = idx - 2
                    else idx = idx - 3
                } else if (root.currentPage === "network") {
                    if (idx === 0) { root.navZone = "sidebar"; event.accepted = true; return }
                    else if (idx <= 2) idx = 0
                    else if (idx === 3) idx = 1
                    else idx = idx - 1
                } else if (root.currentPage === "notifications") {
                    if (idx === 0) { root.navZone = "sidebar"; event.accepted = true; return }
                    else idx = idx - 1
                } else if (root.currentPage === "audio") {
                    if (idx === 0) { root.navZone = "sidebar"; event.accepted = true; return }
                    else idx = idx - 1
                } else {
                    if (idx === 0) { root.navZone = "sidebar"; event.accepted = true; return }
                    idx = idx - 1
                }
                root.contentFocusIndex = clampIdx(idx)
                event.accepted = true
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                if (root.currentPage === "bar") {
                    if (idx < 2) idx = 3
                    else idx = clampIdx(idx + 1)
                } else if (root.currentPage === "colors") {
                    var dc4 = root.colorPresetsByMode("dark").length
                    var lc4 = root.colorPresetsByMode("light").length
                    if (idx <= 1) idx = 2
                    else {
                        var ci4 = idx - 2
                        if (ci4 < dc4) {
                            if (ci4 + 2 < dc4) idx = idx + 2
                            else if (lc4 > 0) idx = 2 + dc4 + Math.min(ci4 % 2, lc4 - 1)
                            else idx = idx
                        } else {
                            var li4 = ci4 - dc4
                            if (li4 + 2 < lc4) idx = idx + 2
                        }
                    }
                } else if (root.currentPage === "general") {
                    if (idx <= 1) idx = idx + 2
                    else if (idx <= 4) idx = Math.min(count - 1, idx + 3)
                    else idx = clampIdx(idx + 1)
                } else if (root.currentPage === "network") {
                    if (idx === 0) idx = 1
                    else if (idx <= 2) idx = 3 < count ? 3 : idx
                    else idx = clampIdx(idx + 1)
                } else {
                    idx = clampIdx(idx + 1)
                }
                root.contentFocusIndex = clampIdx(idx)
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                root.activateFocused()
                event.accepted = true
            } else if (event.key === Qt.Key_Home) {
                root.contentFocusIndex = 0
                event.accepted = true
            } else if (event.key === Qt.Key_End) {
                root.contentFocusIndex = count - 1
                event.accepted = true
            }
        }
    }

    MouseArea { anchors.fill: parent; onClicked: root.visible = false }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Math.min(860, parent.width - 40)
        height: Math.min(640, parent.height - 40)
        radius: 20
        color: Theme.bg
        border.color: Theme.surface1
        border.width: 1
        opacity: root.visible ? 1 : 0
        scale: root.visible ? 1 : 0.97

        Behavior on opacity { NumberAnimation { duration: 160 } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: 180 } }

        MouseArea { anchors.fill: parent; onClicked: {} }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12
            Rectangle {
                Layout.preferredWidth: 190
                Layout.fillHeight: true
                radius: 14
                color: Theme.surface

                Column {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    Text {
                        text: "Центр управления"
                        color: Theme.fg
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        font.bold: true
                        leftPadding: 6
                        topPadding: 4
                        bottomPadding: 4
                    }

                    Rectangle { width: parent.width; height: 1; color: Theme.surface1 }

                    Repeater {
                        model: root.pages
                        delegate: Rectangle {
                            required property var modelData
                            width: parent.width
                            height: 40
                            radius: 10
                            color: root.currentPage === modelData.id ? Theme.accent : (sideMouse.containsMouse ? Theme.surface1 : "transparent")
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 10

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.icon
                                    color: root.currentPage === modelData.id ? Theme.bg : Theme.fg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 15
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.label
                                    color: root.currentPage === modelData.id ? Theme.bg : Theme.fg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                id: sideMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.currentPage = modelData.id
                            }
                        }
                    }

                    Item { width: 1; height: 8 }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 14
                color: "transparent"

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            Layout.fillWidth: true
                            text: root.pageTitle(root.currentPage)
                            color: Theme.fg
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 17
                            font.bold: true
                        }

                        Rectangle {
                            width: 28; height: 28; radius: 8
                            color: closeArea.containsMouse ? Theme.red : Theme.surface
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Text {
                                anchors.centerIn: parent
                                text: "󰅖"
                                color: closeArea.containsMouse ? Theme.bg : Theme.fgMuted
                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
                            }
                            MouseArea {
                                id: closeArea
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.visible = false
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.surface }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Flickable {
                            id: pageNetwork
                            anchors.fill: parent
                            opacity: root.currentPage === "network" ? 1 : 0
                            visible: opacity > 0
                            transform: Translate { x: root.currentPage === "network" ? 0 : 12 }
                            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.InOutQuad } }
                            clip: true
                            contentWidth: width
                            contentHeight: netCol.implicitHeight
                            boundsBehavior: Flickable.StopAtBounds

                            Column {
                                id: netCol
                                width: parent.width
                                spacing: 12

                                Rectangle {
                                    width: parent.width; radius: 12; color: Theme.surface
                                    implicitHeight: netStatusCol.implicitHeight + 20
                                    border.color: (root.navZone === "content" && root.contentFocusIndex === 0) ? Theme.accent : "transparent"
                                    border.width: (root.navZone === "content" && root.contentFocusIndex === 0) ? 1 : 0
                                    Column {
                                        id: netStatusCol
                                        anchors.fill: parent; anchors.margins: 10; spacing: 6
                                        Row {
                                            width: parent.width; spacing: 10
                                            Text {
                                                text: root.netConnType === "none" ? "󰖪" : (root.netConnType === "ethernet" ? "󰈀" : root.netSignalIcon(root.netSignal))
                                                color: root.netConnType === "none" ? Theme.red : Theme.green
                                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 22
                                            }
                                            Column {
                                                width: parent.width - 90; spacing: 2
                                                Text {
                                                    width: parent.width
                                                    text: root.netConnType === "none" ? "Нет подключения" : (root.netConnType === "ethernet" ? "Ethernet" : (root.netSsid !== "" ? root.netSsid : "Wi-Fi"))
                                                    color: Theme.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.bold: true; elide: Text.ElideRight
                                                }
                                                Text {
                                                    width: parent.width
                                                    text: {
                                                        if (root.netConnType === "none") return "Устройство не подключено"
                                                        var parts = []
                                                        if (root.netDevice !== "") parts.push(root.netDevice)
                                                        if (root.netIpAddr !== "") parts.push(root.netIpAddr)
                                                        if (root.netConnType === "wifi" && root.netSignal >= 0) parts.push(root.netSignal + "%")
                                                        return parts.join("  ·  ")
                                                    }
                                                    color: Theme.fgMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; elide: Text.ElideRight
                                                }
                                            }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: root.netScanning ? "󰑓" : "󰑐"
                                                color: netRefreshMouse.containsMouse ? Theme.accent : Theme.fgMuted
                                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16
                                                MouseArea { id: netRefreshMouse; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.refreshNetwork() }
                                            }
                                        }
                                    }
                                }

                                Row {
                                    width: parent.width; spacing: 8
                                    Rectangle {
                                        width: (parent.width - 8) / 2; height: 36; radius: 10
                                        color: root.netWifiEnabled ? Theme.accent : Theme.surface
                                        border.color: (root.navZone === "content" && root.contentFocusIndex === 1) ? Theme.accent : Theme.surface1
                                        border.width: (root.navZone === "content" && root.contentFocusIndex === 1) ? 2 : 1
                                        Text {
                                            anchors.centerIn: parent
                                            text: root.netWifiEnabled ? "󰖩 Wi-Fi: вкл" : "󰖪 Wi-Fi: выкл"
                                            color: root.netWifiEnabled ? Theme.bg : Theme.fg
                                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
                                        }
                                        MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleWifiRadio() }
                                    }
                                    Rectangle {
                                        width: (parent.width - 8) / 2; height: 36; radius: 10
                                        color: openNetMouse.containsMouse ? Theme.surface1 : Theme.surface
                                        border.color: (root.navZone === "content" && root.contentFocusIndex === 2) ? Theme.accent : Theme.surface1
                                        border.width: (root.navZone === "content" && root.contentFocusIndex === 2) ? 2 : 1
                                        Text { anchors.centerIn: parent; text: "󰒓 Открыть попап"; color: Theme.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
                                        MouseArea { id: openNetMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openAndClose(root.networkPopup) }
                                    }
                                }

                                Text { text: "Wi-Fi сети"; color: Theme.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.bold: true }

                                Column {
                                    width: parent.width; spacing: 6
                                    Repeater {
                                        model: root.netWifiNetworks
                                        delegate: Rectangle {
                                            required property var modelData
                                            required property int index
                                            width: netCol.width; height: 42; radius: 10
                                            color: modelData.inUse ? Theme.accent : (netItemMouse.containsMouse ? Theme.surface : Theme.surface1)
                                            border.color: (root.navZone === "content" && root.contentFocusIndex === index + 3) ? Theme.accent : (modelData.inUse ? Theme.accent : "transparent")
                                            border.width: (root.navZone === "content" && root.contentFocusIndex === index + 3) ? 2 : (modelData.inUse ? 1 : 0)
                                            Row {
                                                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
                                                Text { anchors.verticalCenter: parent.verticalCenter; text: root.netSignalIcon(modelData.signal); color: modelData.inUse ? Theme.bg : Theme.green; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14 }
                                                Column {
                                                    anchors.verticalCenter: parent.verticalCenter; width: parent.width - 110; spacing: 0
                                                    Text { width: parent.width; text: modelData.ssid; color: modelData.inUse ? Theme.bg : Theme.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; elide: Text.ElideRight }
                                                    Text { width: parent.width; text: modelData.security && modelData.security !== "--" ? modelData.security : "Open"; color: modelData.inUse ? Theme.bg : Theme.fgMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; elide: Text.ElideRight }
                                                }
                                                Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.inUse ? "Подключено" : modelData.signal + "%"; color: modelData.inUse ? Theme.bg : Theme.fgMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10 }
                                            }
                                            MouseArea {
                                                id: netItemMouse
                                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (modelData.inUse) {
                                                        netActionProc.command = ["bash", "-lc", "nmcli device disconnect " + (root.netDevice || "wlan0")]
                                                    } else {
                                                        var ssid = (modelData.ssid || "").replace(/'/g, "'\\''")
                                                        netActionProc.command = ["bash", "-lc", "nmcli dev wifi connect '" + ssid + "' || nm-connection-editor >/dev/null 2>&1 &"]
                                                    }
                                                    netActionProc.running = true
                                                }
                                            }
                                        }
                                    }
                                    Text {
                                        visible: root.netWifiNetworks.length === 0
                                        text: root.netScanning ? "Поиск сетей..." : "Сети не найдены"
                                        color: Theme.fgMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
                                    }
                                }
                            }
                        }
                        Flickable {
                            id: pageAudio
                            anchors.fill: parent
                            opacity: root.currentPage === "audio" ? 1 : 0
                            visible: opacity > 0
                            transform: Translate { x: root.currentPage === "audio" ? 0 : 12 }
                            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.InOutQuad } }
                            clip: true
                            contentWidth: width
                            contentHeight: audioCol.implicitHeight
                            boundsBehavior: Flickable.StopAtBounds

                            Column {
                                id: audioCol
                                width: parent.width
                                spacing: 12
                                Rectangle {
                                    width: parent.width
                                    radius: 14
                                    color: Theme.surface
                                    implicitHeight: npContent.implicitHeight + 24
                                    border.color: root.mediaPlaying ? Theme.accent : Theme.surface1
                                    border.width: 1

                                    Row {
                                        id: npContent
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 12
                                        spacing: 14

                                        Rectangle {
                                            width: 88
                                            height: 88
                                            radius: 12
                                            color: Theme.bg
                                            clip: true
                                            border.color: Theme.surface1
                                            border.width: root.mediaArt === "" ? 1 : 0

                                            Image {
                                                anchors.fill: parent
                                                source: root.mediaArt
                                                fillMode: Image.PreserveAspectCrop
                                                visible: root.mediaArt !== ""
                                                asynchronous: true
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰎈"
                                                color: Theme.fgMuted
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 30
                                                visible: root.mediaArt === ""
                                            }
                                        }

                                        Column {
                                            width: parent.width - 102
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 6

                                            Row {
                                                width: parent.width
                                                spacing: 6

                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: root.mediaPlaying ? "󰝚" : "󰎇"
                                                    color: root.mediaPlaying ? Theme.green : Theme.fgMuted
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 11
                                                }

                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: root.mediaPlaying ? "Сейчас играет" : "Медиа"
                                                    color: Theme.fgMuted
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 11
                                                }
                                            }

                                            Text {
                                                width: parent.width
                                                text: root.mediaTitle !== "" ? root.mediaTitle : "Ничего не играет"
                                                color: Theme.fg
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 14
                                                font.bold: true
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                width: parent.width
                                                text: root.mediaArtist !== "" ? root.mediaArtist : "Выберите трек в плеере"
                                                color: Theme.fgMuted
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 11
                                                elide: Text.ElideRight
                                            }

                                            Row {
                                                spacing: 8
                                                topPadding: 4

                                                Rectangle {
                                                    width: 32; height: 32; radius: 16
                                                    color: npPrevM.containsMouse ? Theme.surface1 : Theme.bg
                                                    Behavior on color { ColorAnimation { duration: 150 } }
                                                    Text { anchors.centerIn: parent; text: "󰒮"; color: Theme.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14 }
                                                    MouseArea { id: npPrevM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (root.player && root.player.canGoPrevious !== false) root.player.previous() } }
                                                }

                                                Rectangle {
                                                    width: 36; height: 36; radius: 18
                                                    color: npPlayM.containsMouse ? Theme.accent2 : Theme.accent
                                                    Behavior on color { ColorAnimation { duration: 150 } }
                                                    Text { anchors.centerIn: parent; text: root.mediaPlaying ? "󰏤" : "󰐊"; color: Theme.bg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16 }
                                                    MouseArea { id: npPlayM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (root.player) root.player.togglePlaying() } }
                                                }

                                                Rectangle {
                                                    width: 32; height: 32; radius: 16
                                                    color: npNextM.containsMouse ? Theme.surface1 : Theme.bg
                                                    Behavior on color { ColorAnimation { duration: 150 } }
                                                    Text { anchors.centerIn: parent; text: "󰒭"; color: Theme.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14 }
                                                    MouseArea { id: npNextM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (root.player && root.player.canGoNext !== false) root.player.next() } }
                                                }

                                                Rectangle {
                                                    height: 30
                                                    width: openPlayerLabel.implicitWidth + 18
                                                    radius: 15
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    color: npOpenM.containsMouse ? Theme.surface1 : "transparent"
                                                    border.color: Theme.surface1
                                                    border.width: 1
                                                    Behavior on color { ColorAnimation { duration: 150 } }
                                                    Behavior on border.color { ColorAnimation { duration: 150 } }

                                                    Text {
                                                        id: openPlayerLabel
                                                        anchors.centerIn: parent
                                                        text: "󰐾  Плеер"
                                                        color: Theme.fgMuted
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        font.pixelSize: 11
                                                    }

                                                    MouseArea { id: npOpenM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openAndClose(root.playerPopup) }
                                                }
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    width: parent.width; radius: 12; color: Theme.surface
                                    implicitHeight: outCol.implicitHeight + 20
                                    Column {
                                        id: outCol
                                        anchors.fill: parent; anchors.margins: 10; spacing: 8
                                        Row {
                                            width: parent.width; spacing: 8
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: root.sinkAudio && root.sinkAudio.muted ? "󰝟" : "󰕾"
                                                color: root.sinkAudio && root.sinkAudio.muted ? Theme.red : Theme.accent
                                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16
                                                MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: { if (root.sinkAudio) root.sinkAudio.muted = !root.sinkAudio.muted } }
                                            }
                                            Column {
                                                width: parent.width - 70; spacing: 2
                                                Text { width: parent.width; text: root.nodeName(root.sink); color: Theme.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; elide: Text.ElideRight }
                                                Text { text: "Вывод"; color: Theme.fgMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10 }
                                            }
                                            Text { anchors.verticalCenter: parent.verticalCenter; text: root.sinkAudio ? Math.round(root.sinkAudio.volume * 100) + "%" : "--"; color: Theme.fgMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
                                        }
                                        Item {
                                            width: parent.width; height: 18
                                            Rectangle {
                                                anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 6; radius: 3; color: Theme.bg
                                                Rectangle { width: parent.width * Math.max(0, Math.min(1, root.sinkAudio ? root.sinkAudio.volume : 0)); height: parent.height; radius: 3; color: root.sinkAudio && root.sinkAudio.muted ? Theme.fgMuted : Theme.accent; Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } } }
                                            }
                                            MouseArea {
                                                anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor
                                                onPressed: (mouse) => { if (root.sinkAudio) root.sinkAudio.volume = Math.max(0, Math.min(1, mouse.x / width)) }
                                                onPositionChanged: (mouse) => { if (pressed && root.sinkAudio) root.sinkAudio.volume = Math.max(0, Math.min(1, mouse.x / width)) }
                                                onWheel: (wheel) => { if (!root.sinkAudio) return; var step = 0.05; root.sinkAudio.volume = Math.max(0, Math.min(1, root.sinkAudio.volume + (wheel.angleDelta.y > 0 ? step : -step))) }
                                            }
                                        }
                                        Column {
                                            width: parent.width; spacing: 4; visible: root.headphoneBatteries.length > 0
                                            Repeater {
                                                model: root.headphoneBatteries
                                                delegate: Row {
                                                    required property var modelData
                                                    width: outCol.width; spacing: 8
                                                    Text { text: root.batteryIcon(modelData.percent); color: root.batteryColor(modelData.percent); font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14 }
                                                    Text { width: parent.width - 90; text: modelData.name; color: Theme.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; elide: Text.ElideRight }
                                                    Text { text: modelData.percent + "%"; color: Theme.fgMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11 }
                                                }
                                            }
                                        }
                                        Column {
                                            width: parent.width; spacing: 4; visible: root.outputNodes().length > 0
                                            Repeater {
                                                model: root.outputNodes()
                                                delegate: Rectangle {
                                                    required property var modelData
                                                    width: outCol.width; height: 30; radius: 8
                                                    color: (root.sink && root.sink === modelData) ? Theme.accent : (devMouse.containsMouse ? Theme.surface1 : Theme.bg)
                                                    border.color: (root.sink && root.sink === modelData) ? Theme.accent : Theme.surface1; border.width: 1
                                                    Behavior on color { ColorAnimation { duration: 150 } }
                                                    Behavior on border.color { ColorAnimation { duration: 150 } }
                                                    Row {
                                                        anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 8
                                                        Text { anchors.verticalCenter: parent.verticalCenter; text: (root.sink && root.sink === modelData) ? "󰄬" : "󰓃"; color: (root.sink && root.sink === modelData) ? Theme.bg : Theme.fgMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
                                                        Text { anchors.verticalCenter: parent.verticalCenter; width: parent.width - 28; text: root.nodeName(modelData); color: (root.sink && root.sink === modelData) ? Theme.bg : Theme.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; elide: Text.ElideRight }
                                                    }
                                                    MouseArea { id: devMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.setDefaultSink(modelData) }
                                                }
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    width: parent.width; radius: 12; color: Theme.surface
                                    implicitHeight: inCol.implicitHeight + 20
                                    Column {
                                        id: inCol
                                        anchors.fill: parent; anchors.margins: 10; spacing: 8
                                        Row {
                                            width: parent.width; spacing: 8
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: root.sourceAudio && root.sourceAudio.muted ? "󰍭" : "󰍬"
                                                color: root.sourceAudio && root.sourceAudio.muted ? Theme.red : Theme.accent
                                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16
                                                MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: { Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_SOURCE@", "toggle"]) } }
                                            }
                                            Column {
                                                width: parent.width - 70; spacing: 2
                                                Text { width: parent.width; text: root.nodeName(root.source); color: Theme.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; elide: Text.ElideRight }
                                                Text { text: "Микрофон"; color: Theme.fgMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10 }
                                            }
                                            Text { anchors.verticalCenter: parent.verticalCenter; text: root.sourceAudio ? Math.round(root.sourceAudio.volume * 100) + "%" : "--"; color: Theme.fgMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
                                        }
                                        Item {
                                            width: parent.width; height: 18
                                            Rectangle {
                                                anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 6; radius: 3; color: Theme.bg
                                                Rectangle { width: parent.width * Math.max(0, Math.min(1, root.sourceAudio ? root.sourceAudio.volume : 0)); height: parent.height; radius: 3; color: root.sourceAudio && root.sourceAudio.muted ? Theme.fgMuted : Theme.green; Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } } }
                                            }
                                            MouseArea {
                                                anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor
                                                onPressed: (mouse) => { if (root.sourceAudio) root.sourceAudio.volume = Math.max(0, Math.min(1, mouse.x / width)) }
                                                onPositionChanged: (mouse) => { if (pressed && root.sourceAudio) root.sourceAudio.volume = Math.max(0, Math.min(1, mouse.x / width)) }
                                                onWheel: (wheel) => { if (!root.sourceAudio) return; var step = 0.05; root.sourceAudio.volume = Math.max(0, Math.min(1, root.sourceAudio.volume + (wheel.angleDelta.y > 0 ? step : -step))) }
                                            }
                                        }
                                        Column {
                                            width: parent.width; spacing: 4; visible: root.inputNodes().length > 0
                                            Repeater {
                                                model: root.inputNodes()
                                                delegate: Rectangle {
                                                    required property var modelData
                                                    width: inCol.width; height: 30; radius: 8
                                                    color: (root.source && root.source === modelData) ? Theme.accent : (inDevMouse.containsMouse ? Theme.surface1 : Theme.bg)
                                                    border.color: (root.source && root.source === modelData) ? Theme.accent : Theme.surface1; border.width: 1
                                                    Behavior on color { ColorAnimation { duration: 150 } }
                                                    Behavior on border.color { ColorAnimation { duration: 150 } }
                                                    Row {
                                                        anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 8
                                                        Text { anchors.verticalCenter: parent.verticalCenter; text: (root.source && root.source === modelData) ? "󰄬" : "󰍬"; color: (root.source && root.source === modelData) ? Theme.bg : Theme.fgMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
                                                        Text { anchors.verticalCenter: parent.verticalCenter; width: parent.width - 28; text: root.nodeName(modelData); color: (root.source && root.source === modelData) ? Theme.bg : Theme.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; elide: Text.ElideRight }
                                                    }
                                                    MouseArea { id: inDevMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.setDefaultSource(modelData) }
                                                }
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    width: parent.width; height: 36; radius: 10
                                    color: openAudioMouse.containsMouse ? Theme.surface1 : Theme.surface
                                    border.color: Theme.surface1
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }
                                    Text { anchors.centerIn: parent; text: "Открыть аудио-попап"; color: Theme.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
                                    MouseArea { id: openAudioMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openAndClose(root.audioPopup) }
                                }
                            }
                        }
                        ColumnLayout {
                            anchors.fill: parent
                            visible: root.currentPage === "notifications"
                            spacing: 10

                            Row {
                                Layout.fillWidth: true
                                spacing: 8
                                Rectangle {
                                    width: 150; height: 36; radius: 10
                                    color: NotificationService.dnd ? Theme.red : Theme.surface
                                    border.color: (root.navZone === "content" && root.currentPage === "notifications" && root.contentFocusIndex === 0) ? Theme.accent : Theme.surface1
                                    border.width: (root.navZone === "content" && root.currentPage === "notifications" && root.contentFocusIndex === 0) ? 2 : 1
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }
                                    Text { anchors.centerIn: parent; text: NotificationService.dnd ? "󰂛 DND: вкл" : "󰂚 DND: выкл"; color: NotificationService.dnd ? Theme.bg : Theme.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
                                    MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: NotificationService.toggleDnd() }
                                }
                                Rectangle {
                                    width: 150; height: 36; radius: 10
                                    color: clearAllMouse.containsMouse ? Theme.surface1 : Theme.surface
                                    border.color: (root.navZone === "content" && root.currentPage === "notifications" && root.contentFocusIndex === 1) ? Theme.accent : Theme.surface1
                                    border.width: (root.navZone === "content" && root.currentPage === "notifications" && root.contentFocusIndex === 1) ? 2 : 1
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }
                                    Text { anchors.centerIn: parent; text: "󰆴 Очистить всё"; color: clearAllMouse.containsMouse ? Theme.red : Theme.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
                                    MouseArea { id: clearAllMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: NotificationService.dismissAll() }
                                }
                            }

                            ListView {
                                id: notifList
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                spacing: 8
                                model: NotificationService.history

                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    width: notifList.width
                                    height: nContent.implicitHeight + 20
                                    radius: 10
                                    color: Theme.surface
                                    property bool kbdFocused: root.navZone === "content" && root.currentPage === "notifications" && root.contentFocusIndex === index + 2
                                    border.color: kbdFocused ? Theme.accent : (modelData.urgency === 2 ? Theme.red : "transparent")
                                    border.width: kbdFocused ? 2 : (modelData.urgency === 2 ? 1 : 0)
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }

                                    Column {
                                        id: nContent
                                        anchors.fill: parent; anchors.margins: 10; spacing: 4
                                        Row {
                                            width: parent.width; spacing: 6
                                            Text { width: parent.width - 24; text: modelData.appName || ""; color: Theme.accent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true; elide: Text.ElideRight }
                                            Text { text: "󰅖"; color: nCloseMouse.containsMouse ? Theme.red : Theme.fgMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; MouseArea { id: nCloseMouse; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: NotificationService.dismiss(modelData.id) } }
                                        }
                                        Text { width: parent.width; visible: (modelData.summary || "") !== ""; text: modelData.summary || ""; color: Theme.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.bold: true; elide: Text.ElideRight }
                                        Text { width: parent.width; visible: (modelData.body || "") !== ""; text: modelData.body || ""; color: Theme.fgMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; wrapMode: Text.WordWrap; maximumLineCount: 4; elide: Text.ElideRight }
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: NotificationService.history.count === 0
                                    text: "Нет уведомлений"
                                    color: Theme.fgMuted
                                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13
                                }
                            }
                        }
                        Flickable {
                            id: pageBar
                            anchors.fill: parent
                            opacity: root.currentPage === "bar" ? 1 : 0
                            visible: opacity > 0
                            transform: Translate { x: root.currentPage === "bar" ? 0 : 12 }
                            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.InOutQuad } }
                            clip: true
                            contentWidth: width
                            contentHeight: barCol.implicitHeight
                            boundsBehavior: Flickable.StopAtBounds

                            Column {
                                id: barCol
                                width: parent.width
                                spacing: 14

                                Text {
                                    text: "Стиль бара"
                                    color: Theme.fg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                    font.bold: true
                                }

                                Row {
                                    width: parent.width
                                    spacing: 10

                                    Rectangle {
                                        width: (parent.width - 20) / 3
                                        height: 84
                                        radius: 12
                                        property bool kbdFocused: root.navZone === "content" && root.currentPage === "bar" && root.contentFocusIndex === 0
                                        color: BarConfig.style === "islands" ? Theme.accent : Theme.surface
                                        border.color: kbdFocused ? Theme.accent2 : (BarConfig.style === "islands" ? Theme.accent : Theme.surface1)
                                        border.width: kbdFocused ? 2 : 1
                                        Behavior on color { ColorAnimation { duration: 180 } }
                                        Behavior on border.color { ColorAnimation { duration: 180 } }

                                        Column {
                                            anchors.centerIn: parent
                                            spacing: 4
                                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰕰"; color: BarConfig.style === "islands" ? Theme.bg : Theme.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 20 }
                                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Островки"; color: BarConfig.style === "islands" ? Theme.bg : Theme.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: BarConfig.setStyle("islands")
                                        }
                                    }

                                    Rectangle {
                                        width: (parent.width - 20) / 3
                                        height: 84
                                        radius: 12
                                        property bool kbdFocused: root.navZone === "content" && root.currentPage === "bar" && root.contentFocusIndex === 1
                                        color: BarConfig.style === "monolithic" ? Theme.accent : Theme.surface
                                        border.color: kbdFocused ? Theme.accent2 : (BarConfig.style === "monolithic" ? Theme.accent : Theme.surface1)
                                        border.width: kbdFocused ? 2 : 1
                                        Behavior on color { ColorAnimation { duration: 180 } }
                                        Behavior on border.color { ColorAnimation { duration: 180 } }

                                        Column {
                                            anchors.centerIn: parent
                                            spacing: 4
                                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰘔"; color: BarConfig.style === "monolithic" ? Theme.bg : Theme.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 20 }
                                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Монолитный"; color: BarConfig.style === "monolithic" ? Theme.bg : Theme.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true }
                                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "плавающий"; color: BarConfig.style === "monolithic" ? Theme.bg : Theme.fgMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9 }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: BarConfig.setStyle("monolithic")
                                        }
                                    }

                                    Rectangle {
                                        width: (parent.width - 20) / 3
                                        height: 84
                                        radius: 12
                                        property bool kbdFocused: root.navZone === "content" && root.currentPage === "bar" && root.contentFocusIndex === 2
                                        color: BarConfig.style === "full" ? Theme.accent : Theme.surface
                                        border.color: kbdFocused ? Theme.accent2 : (BarConfig.style === "full" ? Theme.accent : Theme.surface1)
                                        border.width: kbdFocused ? 2 : 1
                                        Behavior on color { ColorAnimation { duration: 180 } }
                                        Behavior on border.color { ColorAnimation { duration: 180 } }

                                        Column {
                                            anchors.centerIn: parent
                                            spacing: 4
                                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰍹"; color: BarConfig.style === "full" ? Theme.bg : Theme.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 20 }
                                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "На всю ширину"; color: BarConfig.style === "full" ? Theme.bg : Theme.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true }
                                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "от края до края"; color: BarConfig.style === "full" ? Theme.bg : Theme.fgMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9 }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: BarConfig.setStyle("full")
                                        }
                                    }
                                }

                                Text {
                                    width: parent.width
                                    text: "Текущий режим: " + (BarConfig.style === "full" ? "монолитный на всю ширину (от края до края)" : (BarConfig.style === "monolithic" ? "монолитный (плавающий)" : "островки"))
                                    color: Theme.fgMuted
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                }

                                Rectangle { width: parent.width; height: 1; color: Theme.surface }

                                Text {
                                    text: "Пресеты"
                                    color: Theme.fg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                    font.bold: true
                                }

                                Column {
                                    width: parent.width
                                    spacing: 8

                                    Repeater {
                                        model: { var _u = BarConfig.userPresets; var _a = BarConfig.activePreset; return BarConfig.allPresets() }

                                        delegate: Rectangle {
                                            required property var modelData
                                            required property int index
                                            width: barCol.width
                                            height: 46
                                            radius: 10
                                            property bool kbdFocused: root.navZone === "content" && root.currentPage === "bar" && root.contentFocusIndex === index + 3
                                            color: BarConfig.activePreset === modelData.id ? Theme.accent : (presetMouse.containsMouse ? Theme.surface : Theme.surface1)
                                            border.color: kbdFocused ? Theme.accent2 : (BarConfig.activePreset === modelData.id ? Theme.accent : "transparent")
                                            border.width: kbdFocused ? 2 : (BarConfig.activePreset === modelData.id ? 1 : 0)
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                            Behavior on border.color { ColorAnimation { duration: 150 } }

                                            Row {
                                                anchors.fill: parent
                                                anchors.leftMargin: 12
                                                anchors.rightMargin: 12
                                                spacing: 10

                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: BarConfig.activePreset === modelData.id ? "󰄬" : (modelData.style === "islands" ? "󰕰" : (modelData.style === "full" ? "󰍹" : "󰘔"))
                                                    color: BarConfig.activePreset === modelData.id ? Theme.bg : Theme.fg
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 14
                                                }

                                                Column {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: parent.width - 40
                                                    spacing: 1

                                                    Text {
                                                        width: parent.width
                                                        text: modelData.name
                                                        color: BarConfig.activePreset === modelData.id ? Theme.bg : Theme.fg
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        font.pixelSize: 12
                                                        elide: Text.ElideRight
                                                    }

                                                    Text {
                                                        width: parent.width
                                                        text: modelData.style === "full" ? "Монолитный (на всю ширину)" : (modelData.style === "monolithic" ? "Монолитный (плавающий)" : "Островки")
                                                        color: BarConfig.activePreset === modelData.id ? Theme.bg : Theme.fgMuted
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        font.pixelSize: 10
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                id: presetMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: BarConfig.applyPreset(modelData.id)
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 44
                                    radius: 10
                                    property bool kbdFocused: root.navZone === "content" && root.currentPage === "bar" && root.contentFocusIndex === BarConfig.allPresets().length + 3
                                    color: savePresetMouse.containsMouse ? Theme.accent : Theme.surface
                                    border.color: kbdFocused ? Theme.accent : Theme.surface1
                                    border.width: kbdFocused ? 2 : 1
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 8
                                        Text { text: "󰆓"; color: savePresetMouse.containsMouse ? Theme.bg : Theme.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14 }
                                        Text { text: "Сохранить текущий как мой пресет"; color: savePresetMouse.containsMouse ? Theme.bg : Theme.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
                                    }

                                    MouseArea {
                                        id: savePresetMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: BarConfig.saveCurrentAsMyPreset()
                                    }
                                }

                                Text {
                                    width: parent.width
                                    text: "«Островки» — базовый пресет. Переключение стиля применяется сразу и сохраняется."
                                    color: Theme.fgMuted
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 10
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                        Flickable {
                            id: pageColors
                            anchors.fill: parent
                            opacity: root.currentPage === "colors" ? 1 : 0
                            visible: opacity > 0
                            transform: Translate { x: root.currentPage === "colors" ? 0 : 12 }
                            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.InOutQuad } }
                            clip: true
                            contentWidth: width
                            contentHeight: colorsCol.implicitHeight
                            boundsBehavior: Flickable.StopAtBounds

                            Column {
                                id: colorsCol
                                width: parent.width
                                spacing: 14

                                Rectangle {
                                    width: parent.width
                                    radius: 12
                                    color: Theme.surface
                                    implicitHeight: curSchemeCol.implicitHeight + 20

                                    Column {
                                        id: curSchemeCol
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 8

                                        Text {
                                            text: "Текущая схема"
                                            color: Theme.fg
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 13
                                            font.bold: true
                                        }

                                        Row {
                                            spacing: 8

                                            Repeater {
                                                model: ["bg", "surface", "surface1", "overlay", "fg", "accent", "accent2", "green", "yellow", "orange", "red", "mauve"]

                                                delegate: Rectangle {
                                                    required property var modelData
                                                    width: 22
                                                    height: 22
                                                    radius: 6
                                                    color: Theme[modelData]
                                                    border.color: Theme.overlay
                                                    border.width: 1
                                                }
                                            }
                                        }

                                        Text {
                                            width: parent.width
                                            text: "Matugen-пресеты и «Из обоев» перегенерируют ~/.config/quickshell/matugen-colors.json (подхватывается автоматически). Кастомная тема записывает палитру напрямую."
                                            color: Theme.fgMuted
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 10
                                            wrapMode: Text.WordWrap
                                        }
                                    }
                                }

                                Text { text: "Matugen (из обоев)"; color: Theme.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.bold: true }

                                GridLayout {
                                    width: parent.width
                                    columns: 2
                                    columnSpacing: 10
                                    rowSpacing: 10

                                    Repeater {
                                        model: root.colorPresetsByMode("dynamic")

                                        delegate: Rectangle {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 72
                                            radius: 12
                                            property bool kbdFocused: root.navZone === "content" && root.currentPage === "colors" && root.contentFocusIndex === 0
                                            color: root.activeColorPreset === modelData.id ? Theme.accent : (dynMouse.containsMouse ? Theme.surface : Theme.surface1)
                                            border.color: kbdFocused ? Theme.accent2 : (root.activeColorPreset === modelData.id ? Theme.accent : Theme.surface)
                                            border.width: kbdFocused ? 2 : 1
                                            Behavior on color { ColorAnimation { duration: 180 } }
                                            Behavior on border.color { ColorAnimation { duration: 180 } }

                                            Column {
                                                anchors.fill: parent
                                                anchors.margins: 10
                                                spacing: 6

                                                Row {
                                                    width: parent.width
                                                    spacing: 10

                                                    Text {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: "󰸉"
                                                        color: root.activeColorPreset === modelData.id ? Theme.bg : Theme.accent
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        font.pixelSize: 18
                                                    }

                                                    Column {
                                                        width: parent.width - 90
                                                        spacing: 2
                                                        Text {
                                                            width: parent.width
                                                            text: modelData.name
                                                            color: root.activeColorPreset === modelData.id ? Theme.bg : Theme.fg
                                                            font.family: "JetBrainsMono Nerd Font"
                                                            font.pixelSize: 12
                                                            font.bold: true
                                                            elide: Text.ElideRight
                                                        }
                                                        Text {
                                                            width: parent.width
                                                            text: "Цвета из текущих обоев (waypaper)"
                                                            color: root.activeColorPreset === modelData.id ? Theme.bg : Theme.fgMuted
                                                            font.family: "JetBrainsMono Nerd Font"
                                                            font.pixelSize: 10
                                                            elide: Text.ElideRight
                                                        }
                                                    }

                                                    Rectangle {
                                                        width: 52; height: 24; radius: 12
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        property bool kbdFocused: root.navZone === "content" && root.currentPage === "colors" && root.contentFocusIndex === 1
                                                        color: root.wallpaperColorMode === "dark" ? (root.activeColorPreset === modelData.id ? Theme.bg : Theme.surface) : Theme.yellow
                                                        border.color: kbdFocused ? Theme.accent : Theme.surface1
                                                        border.width: kbdFocused ? 2 : 1
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: root.wallpaperColorMode === "dark" ? "Dark" : "Light"
                                                            color: root.activeColorPreset === modelData.id && root.wallpaperColorMode === "dark" ? Theme.fg : (root.wallpaperColorMode === "light" ? Theme.bg : Theme.fg)
                                                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10
                                                        }
                                                        MouseArea {
                                                            anchors.fill: parent
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                root.wallpaperColorMode = (root.wallpaperColorMode === "dark" ? "light" : "dark")
                                                                root.saveColorPresets()
                                                                if (root.activeColorPreset === modelData.id) root.applyColorPreset(modelData)
                                                            }
                                                        }
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                id: dynMouse
                                                anchors.fill: parent
                                                z: -1
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.applyColorPreset(modelData)
                                            }
                                        }
                                    }
                                }

                                Row {
                                    spacing: 8
                                    Text { text: "󰖔"; color: Theme.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14 }
                                    Text { text: "Тёмные темы"; color: Theme.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.bold: true }
                                }

                                GridLayout {
                                    width: parent.width
                                    columns: 2
                                    columnSpacing: 10
                                    rowSpacing: 10

                                    Repeater {
                                        model: root.colorPresetsByMode("dark")

                                        delegate: Rectangle {
                                            required property var modelData
                                            required property int index
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 58
                                            radius: 12
                                            property bool kbdFocused: root.navZone === "content" && root.currentPage === "colors" && root.contentFocusIndex === index + 2
                                            color: root.activeColorPreset === modelData.id ? Theme.accent : (cpdMouse.containsMouse ? Theme.surface : Theme.surface1)
                                            border.color: kbdFocused ? Theme.accent2 : (root.activeColorPreset === modelData.id ? Theme.accent : Theme.surface)
                                            border.width: kbdFocused ? 2 : 1
                                            Behavior on color { ColorAnimation { duration: 180 } }
                                            Behavior on border.color { ColorAnimation { duration: 180 } }

                                            Row {
                                                anchors.fill: parent
                                                anchors.leftMargin: 12
                                                anchors.rightMargin: 12
                                                spacing: 10

                                                Row {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    spacing: 3
                                                    visible: modelData.kind === "custom"

                                                    Repeater {
                                                        model: modelData.kind === "custom" ? ["#949494", "#aba884", "#6f9eb0"] : []
                                                        delegate: Rectangle {
                                                            required property var modelData
                                                            width: 14; height: 14; radius: 4
                                                            color: modelData
                                                            border.color: Theme.overlay; border.width: 1
                                                        }
                                                    }
                                                }

                                                Rectangle {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 24
                                                    height: 24
                                                    radius: 7
                                                    visible: modelData.kind !== "custom"
                                                    color: modelData.seed
                                                    border.color: Theme.overlay
                                                    border.width: 1

                                                    Text {
                                                        anchors.centerIn: parent
                                                        visible: root.activeColorPreset === modelData.id
                                                        text: "󰄬"
                                                        color: "#ffffff"
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        font.pixelSize: 12
                                                    }
                                                }

                                                Column {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: parent.width - (modelData.kind === "custom" ? 60 : 40)
                                                    spacing: 1

                                                    Text {
                                                        width: parent.width
                                                        text: modelData.name
                                                        color: root.activeColorPreset === modelData.id ? Theme.bg : Theme.fg
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        font.pixelSize: 12
                                                        font.bold: true
                                                        elide: Text.ElideRight
                                                    }

                                                    Text {
                                                        width: parent.width
                                                        text: modelData.kind === "custom" ? "Тёмная · #949494 #aba884 #6f9eb0" : ("Тёмная · " + modelData.seed)
                                                        color: root.activeColorPreset === modelData.id ? Theme.bg : Theme.fgMuted
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        font.pixelSize: 10
                                                        elide: Text.ElideRight
                                                    }
                                                }

                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    visible: modelData.kind === "custom" && root.activeColorPreset === modelData.id
                                                    text: "󰄬"
                                                    color: Theme.bg
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 12
                                                }
                                            }

                                            MouseArea {
                                                id: cpdMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.applyColorPreset(modelData)
                                            }
                                        }
                                    }
                                }

                                Row {
                                    spacing: 8
                                    Text { text: "󰖨"; color: Theme.yellow; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14 }
                                    Text { text: "Светлые темы"; color: Theme.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.bold: true }
                                }

                                GridLayout {
                                    width: parent.width
                                    columns: 2
                                    columnSpacing: 10
                                    rowSpacing: 10

                                    Repeater {
                                        model: root.colorPresetsByMode("light")

                                        delegate: Rectangle {
                                            required property var modelData
                                            required property int index
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 58
                                            radius: 12
                                            property int kbdOffset: 2 + root.colorPresetsByMode("dark").length
                                            property bool kbdFocused: root.navZone === "content" && root.currentPage === "colors" && root.contentFocusIndex === index + kbdOffset
                                            color: root.activeColorPreset === modelData.id ? Theme.accent : (cplMouse.containsMouse ? Theme.surface : Theme.surface1)
                                            border.color: kbdFocused ? Theme.accent2 : (root.activeColorPreset === modelData.id ? Theme.accent : Theme.surface)
                                            border.width: kbdFocused ? 2 : 1
                                            Behavior on color { ColorAnimation { duration: 180 } }
                                            Behavior on border.color { ColorAnimation { duration: 180 } }

                                            Row {
                                                anchors.fill: parent
                                                anchors.leftMargin: 12
                                                anchors.rightMargin: 12
                                                spacing: 10

                                                Rectangle {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 24
                                                    height: 24
                                                    radius: 7
                                                    color: modelData.seed
                                                    border.color: Theme.overlay
                                                    border.width: 1

                                                    Text {
                                                        anchors.centerIn: parent
                                                        visible: root.activeColorPreset === modelData.id
                                                        text: "󰄬"
                                                        color: "#1e1e2e"
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        font.pixelSize: 12
                                                    }
                                                }

                                                Column {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: parent.width - 40
                                                    spacing: 1

                                                    Text {
                                                        width: parent.width
                                                        text: modelData.name
                                                        color: root.activeColorPreset === modelData.id ? Theme.bg : Theme.fg
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        font.pixelSize: 12
                                                        font.bold: true
                                                        elide: Text.ElideRight
                                                    }

                                                    Text {
                                                        width: parent.width
                                                        text: "Светлая · " + modelData.seed
                                                        color: root.activeColorPreset === modelData.id ? Theme.bg : Theme.fgMuted
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        font.pixelSize: 10
                                                        elide: Text.ElideRight
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                id: cplMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.applyColorPreset(modelData)
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    width: parent.width
                                    radius: 10
                                    color: Theme.surface
                                    implicitHeight: noteCol.implicitHeight + 16

                                    Column {
                                        id: noteCol
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 4

                                        Text {
                                            width: parent.width
                                            text: "«Из обоев» берёт путь из ~/.config/waypaper/config.ini и запускает matugen image (можно переключить dark/light). Stone Trio — кастомная палитра из #949494, #aba884, #6f9eb0 в общем списке тёмных тем."
                                            color: Theme.fgMuted
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 10
                                            wrapMode: Text.WordWrap
                                        }
                                    }
                                }
                            }
                        }
                        Flickable {
                            id: pagePower
                            anchors.fill: parent
                            opacity: root.currentPage === "power" ? 1 : 0
                            visible: opacity > 0
                            transform: Translate { x: root.currentPage === "power" ? 0 : 12 }
                            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.InOutQuad } }
                            clip: true
                            contentWidth: width
                            contentHeight: powerCol.implicitHeight
                            boundsBehavior: Flickable.StopAtBounds

                            Column {
                                id: powerCol
                                width: parent.width
                                spacing: 10

                                Repeater {
                                    model: [
                                        { icon: "󰌾", label: "Заблокировать", cmd: ["loginctl", "lock-session"], danger: false },
                                        { icon: "󰍃", label: "Выйти из сессии", cmd: ["niri", "msg", "action", "quit", "-s"], danger: false },
                                        { icon: "󰒲", label: "Сон", cmd: ["systemctl", "suspend"], danger: false },
                                        { icon: "󰜉", label: "Перезагрузка", cmd: ["systemctl", "reboot"], danger: true },
                                        { icon: "󰐥", label: "Выключение", cmd: ["systemctl", "poweroff"], danger: true }
                                    ]
                                    delegate: Rectangle {
                                        required property var modelData
                                        width: powerCol.width
                                        height: 52
                                        radius: 12
                                        color: pMouse.containsMouse ? (modelData.danger ? Theme.red : Theme.accent) : Theme.surface
                                        border.color: Theme.surface1
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        Behavior on border.color { ColorAnimation { duration: 150 } }

                                        Row {
                                            anchors.fill: parent; anchors.leftMargin: 14; spacing: 12
                                            Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.icon; color: pMouse.containsMouse ? Theme.bg : (modelData.danger ? Theme.red : Theme.fg); font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 20 }
                                            Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.label; color: pMouse.containsMouse ? Theme.bg : Theme.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14 }
                                        }
                                        MouseArea {
                                            id: pMouse
                                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: { root.visible = false; Quickshell.execDetached(modelData.cmd) }
                                        }
                                    }
                                }
                            }
                        }
                        Flickable {
                            id: pageGeneral
                            anchors.fill: parent
                            opacity: root.currentPage === "general" ? 1 : 0
                            visible: opacity > 0
                            transform: Translate { x: root.currentPage === "general" ? 0 : 12 }
                            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.InOutQuad } }
                            clip: true
                            contentWidth: width
                            contentHeight: genCol.implicitHeight
                            boundsBehavior: Flickable.StopAtBounds

                            Column {
                                id: genCol
                                width: parent.width
                                spacing: 12

                                GridLayout {
                                    width: parent.width
                                    columns: 2
                                    columnSpacing: 10
                                    rowSpacing: 10

                                    Rectangle {
                                        Layout.fillWidth: true; Layout.preferredHeight: 64; radius: 12
                                        color: (root.caffeineModule && root.caffeineModule.isInhibited) ? Theme.yellow : Theme.surface
                                        border.color: Theme.surface1
                                        Behavior on color { ColorAnimation { duration: 180 } }
                                        Behavior on border.color { ColorAnimation { duration: 150 } }
                                        Row {
                                            anchors.centerIn: parent; spacing: 10
                                            Text { text: (root.caffeineModule && root.caffeineModule.isInhibited) ? "󰅶" : "󰾪"; color: (root.caffeineModule && root.caffeineModule.isInhibited) ? Theme.bg : Theme.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 20 }
                                            Text { text: (root.caffeineModule && root.caffeineModule.isInhibited) ? "Кофеин: вкл" : "Кофеин: выкл"; color: (root.caffeineModule && root.caffeineModule.isInhibited) ? Theme.bg : Theme.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13 }
                                        }
                                        MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (root.caffeineModule) root.caffeineModule.toggle() } }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true; Layout.preferredHeight: 64; radius: 12
                                        color: layoutMouse.containsMouse ? Theme.surface1 : Theme.surface; border.color: Theme.surface1
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        Row {
                                            anchors.centerIn: parent; spacing: 10
                                            Text { text: "󰌌"; color: Theme.accent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 20 }
                                            Text { text: "Раскладка: " + (NiriService.keyboardLayoutIdx === 0 ? "EN" : "RU"); color: Theme.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13 }
                                        }
                                        MouseArea { id: layoutMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["niri", "msg", "action", "switch-layout", "next"]) }
                                    }
                                }

                                Text { text: "Модули и окна"; color: Theme.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.bold: true }

                                GridLayout {
                                    width: parent.width
                                    columns: 3
                                    columnSpacing: 10
                                    rowSpacing: 10

                                    Repeater {
                                        model: [
                                            { icon: "󰀻", label: "Приложения", action: function() { root.openAndClose(root.appLauncher) } },
                                            { icon: "󰅇", label: "Буфер", action: function() { root.openAndClose(root.clipboardMenu) } },
                                            { icon: "󰃭", label: "Календарь", action: function() { root.openAndClose(root.calendarPopup) } },
                                            { icon: "󰏘", label: "Цвета", action: function() { root.currentPage = "colors" } },
                                            { icon: "󰎆", label: "Плеер", action: function() { root.openAndClose(root.playerPopup) } },
                                            { icon: "󰐥", label: "Меню питания", action: function() { root.openAndClose(root.powerMenu) } }
                                        ]
                                        delegate: Rectangle {
                                            required property var modelData
                                            Layout.fillWidth: true; Layout.preferredHeight: 56; radius: 12
                                            color: gMouse.containsMouse ? Theme.accent : Theme.surface
                                            border.color: Theme.surface1
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                            Behavior on border.color { ColorAnimation { duration: 150 } }
                                            Column {
                                                anchors.centerIn: parent; spacing: 2
                                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.icon; color: gMouse.containsMouse ? Theme.bg : Theme.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 17 }
                                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; color: gMouse.containsMouse ? Theme.bg : Theme.fgMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10 }
                                            }
                                            MouseArea { id: gMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: modelData.action() }
                                        }
                                    }
                                }

                                Rectangle {
                                    width: parent.width; radius: 12; color: Theme.surface
                                    implicitHeight: stCol.implicitHeight + 20
                                    Column {
                                        id: stCol
                                        anchors.fill: parent; anchors.margins: 10; spacing: 6
                                        Text { text: "Статус"; color: Theme.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.bold: true }
                                        Text { width: parent.width; text: "󰖐 " + (root.weatherModule ? (root.weatherModule.weatherText + (root.weatherModule.condition ? " · " + root.weatherModule.condition : "")) : "--"); color: Theme.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; elide: Text.ElideRight }
                                        Text { width: parent.width; text: "󰖩 " + (root.netConnType === "wifi" ? root.netSsid : (root.netConnType === "ethernet" ? "Ethernet" : "Offline")) + (root.netIpAddr ? " · " + root.netIpAddr : ""); color: Theme.fgMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; elide: Text.ElideRight }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Esc — закрыть"
                        color: Theme.fgMuted
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10
                    }
                }
            }
        }
    }
}
