import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: launcher

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    visible: false
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-launcher"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property var allApps: []
    property var displayItems: []
    property string searchText: ""
    property int maxSearchResults: 8
    property string mode: "apps"
    property string modeHint: ""
    property var usageTimestamps: ({})

    readonly property string usageFile: Quickshell.env("HOME") + "/.config/quickshell/usage.json"

    property var blacklist: [
        "avahi", "bssh", "bvnc", "qv4l2", "qvidcap",
        "kdeconnect", "xterm", "uxterm", "htop"
    ]

    Component.onCompleted: { loadUsage() }

    Timer {
        interval: 500
        running: true
        repeat: false
        onTriggered: { if (allApps.length === 0) loadApps() }
    }

    Process {
        id: usageReadProc
        command: ["cat", launcher.usageFile]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(this.text)
                    launcher.usageTimestamps = (parsed && typeof parsed === "object") ? parsed : ({})
                } catch (e) {
                    launcher.usageTimestamps = ({})
                }
                launcher.loadApps()
            }
        }
    }

    function loadUsage() { usageReadProc.running = true }

    function saveUsage() {
        try {
            var json = JSON.stringify(usageTimestamps).replace(/'/g, "'\\''")
            usageWriteProc.command = ["bash", "-lc", "mkdir -p \"$HOME/.config/quickshell\" && printf '%s' '" + json + "' > " + usageFile]
            usageWriteProc.running = true
        } catch (e) {}
    }

    Process { id: usageWriteProc; command: ["bash", "-c", "true"]; running: false }

    function frecencyScore(appId) {
        var stamps = usageTimestamps[appId]
        if (!stamps || stamps.length === 0) return 0
        var now = Math.floor(Date.now() / 1000)
        var score = 0
        for (var i = 0; i < stamps.length; i++) {
            var ageDays = (now - stamps[i]) / 86400
            if (ageDays < 0 || ageDays > 90) continue
            if (ageDays <= 4)       score += 100
            else if (ageDays <= 14) score += 70
            else if (ageDays <= 31) score += 50
            else                    score += 30
        }
        return score
    }

    function recordLaunch(appId) {
        var id = appId || ""
        if (id === "") return
        var now = Math.floor(Date.now() / 1000)
        var cutoff = now - 90 * 86400
        var newTimestamps = Object.assign({}, usageTimestamps)
        var stamps = (newTimestamps[id] || []).slice()
        stamps = stamps.filter(function(ts) { return ts >= cutoff })
        stamps.push(now)
        newTimestamps[id] = stamps
        usageTimestamps = newTimestamps
        saveUsage()
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { launcher.visible = !launcher.visible }
    }

    function norm(s) { return (s === undefined || s === null ? "" : ("" + s)).toLowerCase().trim() }

    function loadApps() {
        var entries = DesktopEntries.applications.values
        var apps = []
        for (var i = 0; i < entries.length; i++) {
            var entry = entries[i]
            if (entry.noDisplay) continue
            var id = (entry.id || "").toLowerCase()
            var name = (entry.name || "").toLowerCase()
            var hidden = false
            for (var j = 0; j < blacklist.length; j++) {
                if (id.indexOf(blacklist[j]) !== -1 || name.indexOf(blacklist[j]) !== -1) { hidden = true; break }
            }
            if (hidden) continue
            apps.push(entry)
        }

        apps.sort(function(a, b) {
            var scoreA = launcher.frecencyScore(a.id)
            var scoreB = launcher.frecencyScore(b.id)
            if (scoreB !== scoreA) return scoreB - scoreA
            return launcher.norm(a.name).localeCompare(launcher.norm(b.name))
        })

        allApps = apps
        if (launcher.visible || launcher.mode === "apps")
            launcher.filterApps(launcher.searchText || "")
    }

    function scoreApp(entry, query, allowFuzzy) {
        var q = norm(query)
        if (q === "") return 0
        var name = norm(entry.name)
        var s = 0

        if (name === q) s = 1000
        else if (name.indexOf(q) === 0) s = 800
        else {
            var words = name.split(/[ \-_.]+/)
            for (var i = 0; i < words.length; i++) {
                if (words[i] !== "" && words[i].indexOf(q) === 0) { s = 600; break }
            }
            if (s === 0 && name.indexOf(q) !== -1) s = 300
        }

        if (s === 0) {
            var generic = norm(entry.genericName)
            if (generic !== "" && generic.indexOf(q) !== -1) s = 150
        }
        if (s === 0) {
            var kws = entry.keywords || []
            if (typeof kws === "string") kws = [kws]
            outer:
            for (var k = 0; k < kws.length; k++) {
                var kwWords = norm(kws[k]).split(/[ \-_.]+/)
                for (var w = 0; w < kwWords.length; w++) {
                    if (kwWords[w] !== "" && kwWords[w].indexOf(q) === 0) { s = 100; break outer }
                }
            }
        }

        if (s === 0 && allowFuzzy === true && q.length >= 3) {
            var minBlock = Math.ceil(q.length * 0.8)
            var bestBlock = 0
            for (var start = 0; start <= q.length - minBlock; start++) {
                for (var end = q.length; end >= start + minBlock; end--) {
                    var sub = q.substring(start, end)
                    if (name.indexOf(sub) !== -1) {
                        var len = end - start
                        if (len > bestBlock) bestBlock = len
                        break
                    }
                }
            }
            if (bestBlock >= minBlock) s = Math.round(50 * (bestBlock / q.length))
        }

        if (s === 0) return 0
        s += Math.max(0, 30 - name.length)
        s += Math.min(50, Math.round(launcher.frecencyScore(entry.id) / 4))
        return s
    }

    function appResults(query) {
        var q = norm(query)
        if (q === "") {
            var base = allApps.slice()
            base.sort(function(a, b) {
                var sa = launcher.frecencyScore(a.id), sb = launcher.frecencyScore(b.id)
                if (sb !== sa) return sb - sa
                return launcher.norm(a.name).localeCompare(launcher.norm(b.name))
            })
            var out0 = []
            for (var i = 0; i < base.length; i++) out0.push({ type: "app", app: base[i] })
            return out0
        }
        var scored = []
        for (var i = 0; i < allApps.length; i++) {
            var s = scoreApp(allApps[i], q, false)
            if (s > 0) scored.push({ app: allApps[i], score: s })
        }
        if (scored.length === 0) {
            for (var f = 0; f < allApps.length; f++) {
                var fs = scoreApp(allApps[f], q, true)
                if (fs > 0) scored.push({ app: allApps[f], score: fs })
            }
        }
        scored.sort(function(a, b) {
            if (b.score !== a.score) return b.score - a.score
            var la = norm(a.app.name).length, lb = norm(b.app.name).length
            if (la !== lb) return la - lb
            return norm(a.app.name).localeCompare(norm(b.app.name))
        })
        var out = []
        for (var j = 0; j < scored.length && j < launcher.maxSearchResults; j++) out.push({ type: "app", app: scored[j].app })
        return out
    }

    function shellQuote(s) { s = String(s === undefined || s === null ? "" : s); return "'" + s.replace(/'/g, "'\\''") + "'" }

    function filterApps(raw) {
        var query = raw || ""
        searchText = query
        var t = query

        if (t.startsWith(">")) {
            mode = "command"; modeHint = "Команда"
            var cmd = t.substring(1).trim()
            displayItems = cmd.length === 0
                ? [{ type: "info", icon: "󰆍", title: "Команда", subtitle: "> команда" }]
                : [{ type: "command", icon: "󰆍", title: cmd, subtitle: "Запустить", cmd: cmd }]
            resultsList.currentIndex = 0
            return
        }

        if (t.startsWith("=")) {
            mode = "calc"; modeHint = "Калькулятор"
            var expr = t.substring(1).trim()
            if (expr.length === 0) {
                displayItems = [{ type: "info", icon: "󰃬", title: "Калькулятор", subtitle: "= выражение" }]
            } else {
                displayItems = [{ type: "info", icon: "󰃬", title: "Вычисление...", subtitle: expr }]
                calcProc.expr = expr
                calcProc.command = ["python3", "-c",
                    "import math, re\n" +
                    "expr = " + JSON.stringify(expr) + "\n" +
                    "expr = expr.replace('×', '*').replace('·', '*').replace('÷', '/').replace('−', '-').replace(',', '.')\n" +
                    "expr = re.sub(r'(?<=\\d)\\s*[xX]\\s*(?=\\d|[\\(\\.])', '*', expr)\n" +
                    "allowed = {k:getattr(math,k) for k in dir(math) if not k.startswith('_')}\n" +
                    "allowed.update({'abs':abs,'round':round,'min':min,'max':max,'pow':pow,'sum':sum,'int':int,'float':float})\n" +
                    "try:\n" +
                    "    print(eval(expr, {'__builtins__':{}}, allowed))\n" +
                    "except Exception:\n" +
                    "    print('__ERR__')\n"]
                calcProc.running = true
            }
            resultsList.currentIndex = 0
            return
        }

        mode = "apps"; modeHint = ""
        displayItems = appResults(query)
        resultsList.currentIndex = 0
    }

    function launchItem(item) {
        if (!item) return
        if (item.type === "app") {
            recordLaunch(item.app.id || "")
            try { item.app.execute() } catch (e) {}
            launcher.visible = false
            return
        }
        if (item.type === "command") {
            Quickshell.execDetached(["bash", "-lc", item.cmd])
            launcher.visible = false
            return
        }
        if (item.type === "calc") {
            if (item.value && item.value !== "" && item.value !== "__ERR__") {
                copyProc.command = ["bash", "-lc", "printf '%s' " + shellQuote(item.value) + " | wl-copy 2>/dev/null || true"]
                copyProc.running = true
            }
            launcher.visible = false
            return
        }
    }

    Process {
        id: calcProc
        property string expr: ""
        command: ["bash", "-c", "true"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (launcher.mode !== "calc") return
                var val = ((this.text || "").trim().split("\n")[0] || "")
                if (val === "__ERR__" || val === "") {
                    launcher.displayItems = [{ type: "info", icon: "󰃬", title: "Ошибка", subtitle: calcProc.expr }]
                } else {
                    launcher.displayItems = [{ type: "calc", icon: "󰃬", title: val, subtitle: calcProc.expr, expr: calcProc.expr, value: val }]
                }
                resultsList.currentIndex = 0
            }
        }
    }

    Process { id: copyProc; command: ["bash", "-c", "true"]; running: false }

    MouseArea { anchors.fill: parent; onClicked: launcher.visible = false }

    Item {
        id: launcherBox
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: 420
        height: launcher.visible ? 320 : 0
        anchors.bottomMargin: launcher.visible ? 10 : -height - 20
        clip: true

        Behavior on height { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        Behavior on anchors.bottomMargin { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            radius: 14
            color: Theme.glassPanel
            border.color: Theme.glassBorderStrong
            border.width: 1
            opacity: launcher.visible ? 1 : 0
            scale: launcher.visible ? 1 : 0.985
            transformOrigin: Item.Bottom

            Behavior on opacity { NumberAnimation { duration: 160 } }
            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 180 } }
            Behavior on border.color { ColorAnimation { duration: 180 } }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 1
                height: Math.max(0, parent.height * 0.5)
                radius: Math.max(0, parent.radius - 1)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.glassHighlight }
                    GradientStop { position: 0.45; color: Theme.glassHighlightSoft }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 1
                width: Math.max(0, parent.width * 0.45)
                height: Math.max(0, parent.height * 0.6)
                radius: Math.max(0, parent.radius - 1)
                opacity: Theme.glassEnabled ? 1 : 0
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Theme.glassHighlightSoft }
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 1
                height: Math.max(0, parent.height * 0.3)
                radius: Math.max(0, parent.radius - 1)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Theme.glassHighlightSoft }
                }
            }

            MouseArea { anchors.fill: parent; onClicked: {} }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 5
                z: 1

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    radius: 9
                    color: Theme.glassCard
                    border.color: Theme.glassBorder
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }

                    TextField {
                        id: searchField
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        placeholderText: "Поиск  ·  >  ·  ="
                        placeholderTextColor: Theme.fgMuted
                        color: Theme.fg
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        background: null
                        focus: true
                        selectByMouse: true

                        onTextChanged: {
                            launcher.searchText = text
                            launcher.filterApps(text)
                        }

                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Down) {
                                resultsList.incrementCurrentIndex(); event.accepted = true
                            } else if (event.key === Qt.Key_Up) {
                                resultsList.decrementCurrentIndex(); event.accepted = true
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (resultsList.currentIndex >= 0 && resultsList.currentIndex < launcher.displayItems.length)
                                    launcher.launchItem(launcher.displayItems[resultsList.currentIndex])
                                event.accepted = true
                            } else if (event.key === Qt.Key_Escape) {
                                launcher.visible = false
                                event.accepted = true
                            }
                        }
                    }
                }

                ListView {
                    id: resultsList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 2
                    model: launcher.displayItems
                    currentIndex: 0

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        width: resultsList.width
                        height: 34
                        radius: 8
                        color: index === resultsList.currentIndex ? Theme.accent : (hoverItem.containsMouse ? Theme.glassCardHover : "transparent")
                        border.color: index === resultsList.currentIndex ? Theme.accent : "transparent"
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        property bool isApp: modelData.type === "app" && modelData.app
                        property string iconSource: (isApp && modelData.app.icon) ? Quickshell.iconPath(modelData.app.icon) : ""
                        property string glyph: {
                            if (!isApp && modelData.icon) return modelData.icon
                            if (isApp) return "󰣆"
                            return "󰘔"
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8

                            Item {
                                Layout.preferredWidth: 22
                                Layout.preferredHeight: 22
                                Layout.alignment: Qt.AlignVCenter
                                IconImage { anchors.fill: parent; source: iconSource; visible: iconSource !== "" }
                                Text {
                                    anchors.centerIn: parent
                                    visible: iconSource === ""
                                    text: glyph
                                    color: index === resultsList.currentIndex ? Theme.bg : Theme.fg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 0

                                Text {
                                    Layout.fillWidth: true
                                    text: isApp ? (modelData.app.name || "") : (modelData.title || "")
                                    color: index === resultsList.currentIndex ? Theme.bg : Theme.fg
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    visible: text !== ""
                                    text: isApp ? (modelData.app.genericName || "") : (modelData.subtitle || "")
                                    color: index === resultsList.currentIndex ? Theme.bg : Theme.fgMuted
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 9
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        MouseArea {
                            id: hoverItem
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: launcher.launchItem(modelData)
                        }
                    }
                }
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            mode = "apps"
            modeHint = ""
            searchField.text = ""
            launcher.filterApps("")
            resultsList.currentIndex = 0
            searchField.forceActiveFocus()
            loadUsage()
        } else {
            mode = "apps"
            modeHint = ""
        }
    }
}
