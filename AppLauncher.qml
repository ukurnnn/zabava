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
    property int maxSearchResults: 12
    property string mode: "apps" // apps, command, calc, web, clipboard, windows, emoji, stats, actions
    property string modeHint: ""
    property var pendingAppForActions: null

    // usageTimestamps: { appId: [unix_ts, unix_ts, ...] }
    property var usageTimestamps: ({})

    readonly property string usageFile: Quickshell.env("HOME") + "/.config/quickshell/usage.json"

    property var blacklist: [
        "avahi", "bssh", "bvnc", "qv4l2", "qvidcap",
        "kdeconnect", "xterm", "uxterm", "htop"
    ]

    property var emojiList: [
        { ch: "😀", name: "grinning smile happy" }, { ch: "😁", name: "beaming smile" }, { ch: "😂", name: "joy tears laugh" },
        { ch: "🤣", name: "rofl laugh" }, { ch: "😊", name: "blush smile" }, { ch: "😍", name: "heart eyes love" },
        { ch: "😎", name: "sunglasses cool" }, { ch: "🤔", name: "thinking hmm" }, { ch: "😴", name: "sleep tired" },
        { ch: "😭", name: "cry sad" }, { ch: "😡", name: "angry" }, { ch: "👍", name: "thumbs up yes ok" },
        { ch: "👎", name: "thumbs down no" }, { ch: "👏", name: "clap" }, { ch: "🙏", name: "pray thanks" },
        { ch: "🔥", name: "fire hot" }, { ch: "⭐", name: "star" }, { ch: "✨", name: "sparkles" },
        { ch: "❤️", name: "heart red love" }, { ch: "💔", name: "broken heart" }, { ch: "✅", name: "check ok done" },
        { ch: "❌", name: "cross no" }, { ch: "⚠️", name: "warning" }, { ch: "🎉", name: "party tada" },
        { ch: "🚀", name: "rocket launch" }, { ch: "💡", name: "idea bulb" }, { ch: "📌", name: "pin" },
        { ch: "📎", name: "paperclip" }, { ch: "📝", name: "note memo" }, { ch: "📁", name: "folder" },
        { ch: "📷", name: "camera photo" }, { ch: "🎵", name: "music note" }, { ch: "🎮", name: "game controller" },
        { ch: "🐧", name: "linux tux penguin" }, { ch: "☕", name: "coffee" }, { ch: "🍕", name: "pizza" },
        { ch: "🙂", name: "slight smile" }, { ch: "😉", name: "wink" }, { ch: "😅", name: "sweat smile" },
        { ch: "🥳", name: "party face" }, { ch: "🤖", name: "robot" }, { ch: "👀", name: "eyes look" },
        { ch: "💻", name: "laptop computer" }, { ch: "🖥️", name: "desktop computer" }, { ch: "⌨️", name: "keyboard" },
        { ch: "🖱️", name: "mouse" }, { ch: "🔒", name: "lock" }, { ch: "🔓", name: "unlock" },
        { ch: "⚙️", name: "gear settings" }, { ch: "🧪", name: "test lab" }, { ch: "🐛", name: "bug debug" }
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

    // Frecency-score (launcher-only history)
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

        // Empty-state sort: frecency, then alphabetical
        apps.sort(function(a, b) {
            var scoreA = launcher.frecencyScore(a.id)
            var scoreB = launcher.frecencyScore(b.id)
            if (scoreB !== scoreA) return scoreB - scoreA
            return launcher.norm(a.name).localeCompare(launcher.norm(b.name))
        })

        allApps = apps
        if (launcher.visible || launcher.mode === "apps" || launcher.mode === "actions")
            launcher.filterApps(launcher.searchText || "")
    }

    // Preserved ranking rules
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

    function usageStats() {
        var ids = Object.keys(usageTimestamps || {})
        var now = Math.floor(Date.now() / 1000)
        var cutoff = now - 90 * 86400
        var rows = []
        for (var i = 0; i < ids.length; i++) {
            var id = ids[i]
            var stamps = (usageTimestamps[id] || []).filter(function(ts) { return ts >= cutoff })
            if (stamps.length === 0) continue
            var name = id
            for (var a = 0; a < allApps.length; a++) {
                if (allApps[a].id === id) { name = allApps[a].name || id; break }
            }
            rows.push({ id: id, name: name, count: stamps.length, score: frecencyScore(id) })
        }
        rows.sort(function(a, b) { if (b.score !== a.score) return b.score - a.score; return b.count - a.count })
        return rows
    }

    function resetUsageStats() {
        usageTimestamps = ({})
        saveUsage()
        filterApps(searchField.text)
    }

    function shellQuote(s) { s = String(s === undefined || s === null ? "" : s); return "'" + s.replace(/'/g, "'\\''") + "'" }

    function filterApps(raw) {
        var query = raw || ""
        searchText = query
        var t = query
        var tl = t.trim()

        // Stats/frecency view
        if (tl === ":stats" || tl === "stats:" || tl === ":usage") {
            mode = "stats"; modeHint = "Статистика запусков"
            var rows = usageStats()
            var items = [{ type: "action", icon: "󰑓", title: "Сбросить статистику запусков", subtitle: "Очистить usage.json (только лаунчер)", action: "reset-usage" }]
            for (var i = 0; i < rows.length && items.length < maxSearchResults; i++) {
                var r = rows[i]
                items.push({ type: "info", icon: "󰄬", title: r.name, subtitle: "Запусков: " + r.count + " · frecency: " + r.score })
            }
            if (rows.length === 0) items.push({ type: "info", icon: "󰋼", title: "Пока нет статистики", subtitle: "Запускайте приложения через лаунчер" })
            displayItems = items; resultsList.currentIndex = 0; return
        }

        // Command execution
        if (t.startsWith(">")) {
            mode = "command"; modeHint = "Команда"
            var cmd = t.substring(1).trim()
            displayItems = cmd.length === 0
                ? [{ type: "info", icon: "󰆍", title: "Введите команду после >", subtitle: "Enter — выполнить (bash -lc)" }]
                : [{ type: "command", icon: "󰆍", title: "Выполнить: " + cmd, subtitle: "bash -lc · Enter для запуска", cmd: cmd }]
            resultsList.currentIndex = 0; return
        }

        // Calculator
        if (t.startsWith("=")) {
            mode = "calc"; modeHint = "Калькулятор"
            var expr = t.substring(1).trim()
            if (expr.length === 0) {
                displayItems = [{ type: "info", icon: "󰃬", title: "Введите выражение после =", subtitle: "Например: =2+2*10, =sqrt(144)" }]
            } else {
                displayItems = [{ type: "info", icon: "󰃬", title: "Вычисление...", subtitle: expr }]
                calcProc.expr = expr
                calcProc.command = ["python3", "-c",
                    "import math\n" +
                    "expr = " + JSON.stringify(expr) + "\n" +
                    "allowed = {k:getattr(math,k) for k in dir(math) if not k.startswith('_')}\n" +
                    "allowed.update({'abs':abs,'round':round,'min':min,'max':max,'pow':pow,'sum':sum,'int':int,'float':float})\n" +
                    "try:\n" +
                    "    print(eval(expr, {'__builtins__':{}}, allowed))\n" +
                    "except Exception:\n" +
                    "    print('__ERR__')\n"]
                calcProc.running = true
            }
            resultsList.currentIndex = 0; return
        }

        // Web search
        if (t.startsWith("?")) {
            mode = "web"; modeHint = "Веб-поиск"
            var qweb = t.substring(1).trim()
            displayItems = qweb.length === 0
                ? [{ type: "info", icon: "󰖟", title: "Введите запрос после ?", subtitle: "Enter — открыть в браузере (DuckDuckGo)" }]
                : [{ type: "web", icon: "󰖟", title: "Искать: " + qweb, subtitle: "DuckDuckGo · Enter открыть", query: qweb }]
            resultsList.currentIndex = 0; return
        }

        // Windows (Niri)
        if (t.startsWith(":w") || t.startsWith("win:")) {
            mode = "windows"; modeHint = "Окна (Niri)"
            var wq = t.replace(/^(:w(?:in(?:dows?)?)?|win:)\s*/i, "")
            displayItems = [{ type: "info", icon: "󱂬", title: "Загрузка окон...", subtitle: "" }]
            windowsProc.query = norm(wq)
            windowsProc.command = ["bash", "-lc", "niri msg -j windows 2>/dev/null || echo '[]'"]
            windowsProc.running = true
            resultsList.currentIndex = 0; return
        }

        // Clipboard (cliphist)
        if (t.startsWith(":c") || t.startsWith(":clip") || t.startsWith("clip:") || t.startsWith(":b")) {
            mode = "clipboard"; modeHint = "Буфер обмена"
            var cq = t.replace(/^(:c(?:lip(?:board)?)?|clip:|:b)\s*/i, "")
            displayItems = [{ type: "info", icon: "󰅇", title: "Загрузка буфера...", subtitle: "" }]
            clipProc.query = norm(cq)
            clipProc.command = ["bash", "-lc", "command -v cliphist >/dev/null 2>&1 && cliphist list | head -60 || true"]
            clipProc.running = true
            resultsList.currentIndex = 0; return
        }

        // Emoji
        if (t.startsWith(":e") || t.startsWith(":emoji") || t.startsWith("emoji:")) {
            mode = "emoji"; modeHint = "Эмодзи"
            var eq = norm(t.replace(/^(:e(?:moji)?|emoji:)\s*/i, ""))
            var eitems = []
            for (var ei = 0; ei < emojiList.length; ei++) {
                var em = emojiList[ei]
                if (eq === "" || norm(em.name).indexOf(eq) !== -1 || em.ch.indexOf(eq) !== -1) {
                    eitems.push({ type: "emoji", icon: em.ch, title: em.ch + "  " + em.name.split(" ").slice(0,3).join(" "), subtitle: "Enter — скопировать", ch: em.ch })
                }
                if (eitems.length >= maxSearchResults) break
            }
            if (eitems.length === 0) eitems.push({ type: "info", icon: "󰞅", title: "Ничего не найдено", subtitle: "" })
            displayItems = eitems; resultsList.currentIndex = 0; return
        }

        // App actions mode
        if (pendingAppForActions) {
            mode = "actions"; modeHint = "Действия: " + (pendingAppForActions.name || "")
            var acts = getAppActions(pendingAppForActions)
            var aq = norm(t)
            var aitems = [
                { type: "action", icon: "󰁍", title: "Назад к приложениям", subtitle: "Esc или Enter", action: "back-apps" },
                { type: "app", icon: pendingAppForActions.icon || "", title: "Запустить: " + (pendingAppForActions.name || ""), subtitle: pendingAppForActions.genericName || "", app: pendingAppForActions }
            ]
            for (var ai = 0; ai < acts.length; ai++) {
                var act = acts[ai]
                if (aq !== "" && norm(act.name).indexOf(aq) === -1) continue
                aitems.push({ type: "app-action", icon: pendingAppForActions.icon || "", title: act.name || "Action", subtitle: pendingAppForActions.name || "", app: pendingAppForActions, appAction: act })
            }
            if (aitems.length === 2 && acts.length === 0)
                aitems.push({ type: "info", icon: "󰋼", title: "Нет дополнительных действий", subtitle: ".desktop actions не найдены для этого приложения" })
            displayItems = aitems; resultsList.currentIndex = 0; return
        }

        // Default: apps (preserve existing behavior)
        mode = "apps"; modeHint = ""
        displayItems = appResults(query)
        resultsList.currentIndex = 0
    }

    function getAppActions(app) {
        var out = []
        if (!app) return out
        try {
            var acts = app.actions
            if (!acts) return out
            if (acts.length !== undefined) {
                for (var i = 0; i < acts.length; i++) {
                    var a = acts[i]
                    if (!a) continue
                    out.push({ name: a.name || a.text || a.id || ("Action " + (i + 1)), ref: a, index: i })
                }
            } else if (acts.values !== undefined) {
                var v = acts.values
                for (var j = 0; j < v.length; j++) {
                    var av = v[j]
                    if (!av) continue
                    out.push({ name: av.name || av.text || av.id || ("Action " + (j + 1)), ref: av, index: j })
                }
            }
        } catch (e) {}
        return out
    }

    function executeAppAction(app, act) {
        try {
            if (act && act.ref) {
                if (typeof act.ref.execute === "function") { act.ref.execute(); launcher.visible = false; return }
                if (typeof act.ref.trigger === "function") { act.ref.trigger(); launcher.visible = false; return }
                if (typeof act.ref.activate === "function") { act.ref.activate(); launcher.visible = false; return }
            }
            if (app && typeof app.executeAction === "function") {
                app.executeAction(act.index !== undefined ? act.index : (act.ref || act))
                launcher.visible = false
                return
            }
            if (app && typeof app.execute === "function" && act && act.ref && act.ref.id) {
                try { app.execute(act.ref.id); launcher.visible = false; return } catch (e2) {}
            }
        } catch (e) {}
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

    function launchItem(item) {
        if (!item) return
        if (item.type === "app") {
            recordLaunch(item.app.id || "")
            try { item.app.execute() } catch (e) {}
            launcher.visible = false
            pendingAppForActions = null
            return
        }
        if (item.type === "app-action") {
            recordLaunch(item.app ? (item.app.id || "") : "")
            executeAppAction(item.app, item.appAction)
            pendingAppForActions = null
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
        if (item.type === "web") {
            var url = "https://duckduckgo.com/?q=" + encodeURIComponent(item.query || "")
            Quickshell.execDetached(["xdg-open", url])
            launcher.visible = false
            return
        }
        if (item.type === "clipboard") {
            copyProc.command = ["bash", "-lc", "cliphist decode " + shellQuote(item.id) + " | wl-copy 2>/dev/null || true"]
            copyProc.running = true
            launcher.visible = false
            return
        }
        if (item.type === "window") {
            if (item.winId !== undefined && item.winId !== null)
                Quickshell.execDetached(["niri", "msg", "action", "focus-window", "--id", String(item.winId)])
            launcher.visible = false
            return
        }
        if (item.type === "emoji") {
            copyProc.command = ["bash", "-lc", "printf '%s' " + shellQuote(item.ch) + " | wl-copy 2>/dev/null || true"]
            copyProc.running = true
            launcher.visible = false
            return
        }
        if (item.type === "action") {
            if (item.action === "reset-usage") { resetUsageStats(); return }
            if (item.action === "back-apps") { pendingAppForActions = null; searchField.text = ""; filterApps(""); return }
        }
    }

    function openActionsForSelected() {
        var idx = resultsList.currentIndex
        if (idx < 0 || idx >= displayItems.length) return
        var item = displayItems[idx]
        if (item && item.type === "app" && item.app) {
            pendingAppForActions = item.app
            searchField.text = ""
            filterApps("")
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
                    launcher.displayItems = [{ type: "info", icon: "󰃬", title: "Ошибка вычисления", subtitle: calcProc.expr }]
                } else {
                    launcher.displayItems = [{ type: "calc", icon: "󰃬", title: "= " + val, subtitle: calcProc.expr + "  (Enter — скопировать)", expr: calcProc.expr, value: val }]
                }
                resultsList.currentIndex = 0
            }
        }
    }

    Process {
        id: clipProc
        property string query: ""
        command: ["bash", "-c", "true"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (launcher.mode !== "clipboard") return
                var lines = (this.text || "").split("\n")
                var items = []
                var q = clipProc.query || ""
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i]
                    if (!line || line.trim() === "") continue
                    var tabIdx = line.indexOf("\t")
                    if (tabIdx === -1) continue
                    var id = line.substring(0, tabIdx)
                    var preview = line.substring(tabIdx + 1).replace(/\s+/g, " ").trim()
                    if (q !== "" && launcher.norm(preview).indexOf(q) === -1) continue
                    items.push({ type: "clipboard", icon: "󰅇", title: preview.substring(0, 120), subtitle: "cliphist #" + id, id: id })
                    if (items.length >= launcher.maxSearchResults) break
                }
                if (items.length === 0) items.push({ type: "info", icon: "󰅇", title: q !== "" ? "Ничего не найдено" : "Буфер пуст или cliphist недоступен", subtitle: "Нужны cliphist и wl-clipboard" })
                launcher.displayItems = items
                resultsList.currentIndex = 0
            }
        }
    }

    Process {
        id: windowsProc
        property string query: ""
        command: ["bash", "-c", "true"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (launcher.mode !== "windows") return
                var items = []
                try {
                    var arr = JSON.parse(this.text || "[]")
                    var q = windowsProc.query || ""
                    for (var i = 0; i < arr.length; i++) {
                        var w = arr[i] || {}
                        var title = w.title || "(без названия)"
                        var appId = w.app_id || w.appId || ""
                        var label = (appId ? appId + " — " : "") + title
                        if (q !== "" && launcher.norm(label).indexOf(q) === -1) continue
                        var ws = (w.workspace_id !== undefined) ? ("ws " + w.workspace_id) : ""
                        items.push({ type: "window", icon: "󱂬", title: label.substring(0, 120), subtitle: (w.is_focused ? "focused" : "") + (ws ? ((w.is_focused ? " · " : "") + ws) : ""), winId: w.id })
                        if (items.length >= launcher.maxSearchResults) break
                    }
                } catch (e) {
                    items = [{ type: "info", icon: "󱂬", title: "Не удалось получить окна", subtitle: "niri msg -j windows недоступен" }]
                }
                if (items.length === 0) items.push({ type: "info", icon: "󱂬", title: "Окна не найдены", subtitle: "" })
                launcher.displayItems = items
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
        width: 560
        height: launcher.visible ? 440 : 0
        anchors.bottomMargin: launcher.visible ? 12 : -height - 20
        clip: true

        Behavior on height { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
        Behavior on anchors.bottomMargin { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: Theme.bg
            border.color: Theme.surface1
            border.width: 1
            opacity: launcher.visible ? 1 : 0
            scale: launcher.visible ? 1 : 0.985
            transformOrigin: Item.Bottom

            Behavior on opacity { NumberAnimation { duration: 160 } }
            Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            Behavior on border.color { ColorAnimation { duration: 180 } }

            MouseArea { anchors.fill: parent; onClicked: {} }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    radius: 8
                    color: Theme.surface

                    TextField {
                        id: searchField
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        placeholderText: "Поиск…  (> команда, = кальк, ? web, :w окна, :c буфер, :e emoji, :stats)"
                        placeholderTextColor: Theme.fgMuted
                        color: Theme.fg
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
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
                                if (launcher.pendingAppForActions) {
                                    launcher.pendingAppForActions = null
                                    launcher.filterApps(searchField.text)
                                } else {
                                    launcher.visible = false
                                }
                                event.accepted = true
                            } else if (event.key === Qt.Key_Tab) {
                                launcher.openActionsForSelected(); event.accepted = true
                            }
                        }
                    }
                }

                Text {
                    visible: launcher.mode !== "apps" || launcher.modeHint !== ""
                    text: {
                        if (launcher.mode === "actions") return "Действия: " + (launcher.pendingAppForActions ? launcher.pendingAppForActions.name : "") + "  ·  Esc — назад"
                        if (launcher.mode === "apps") return "Tab/ПКМ — действия приложения  ·  :stats — статистика"
                        return "Режим: " + launcher.modeHint
                    }
                    color: Theme.fgMuted
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
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
                        height: 44
                        radius: 8
                        color: index === resultsList.currentIndex ? Theme.accent : (hoverItem.containsMouse ? Theme.surface : "transparent")
                        Behavior on color { ColorAnimation { duration: 120 } }

                        property bool isApp: modelData.type === "app" && modelData.app
                        property string iconSource: (isApp && modelData.app.icon) ? Quickshell.iconPath(modelData.app.icon) : ""
                        property bool hasActions: isApp && launcher.getAppActions(modelData.app).length > 0
                        property string glyph: {
                            if (modelData.type === "emoji") return modelData.ch || ""
                            if (!isApp && modelData.icon) return modelData.icon
                            if (isApp) return "󰣆"
                            return "󰘔"
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 10

                            Item {
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                Layout.alignment: Qt.AlignVCenter
                                IconImage { anchors.fill: parent; source: iconSource; visible: iconSource !== "" }
                                Text {
                                    anchors.centerIn: parent
                                    visible: iconSource === ""
                                    text: glyph
                                    color: index === resultsList.currentIndex ? Theme.bg : Theme.fg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: modelData.type === "emoji" ? 18 : 15
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
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    visible: text !== ""
                                    text: isApp ? (modelData.app.genericName || "") : (modelData.subtitle || "")
                                    color: index === resultsList.currentIndex ? Theme.bg : Theme.fgMuted
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                }
                            }

                            Text {
                                visible: hasActions && launcher.mode === "apps"
                                text: "󰅂"
                                color: index === resultsList.currentIndex ? Theme.bg : Theme.fgMuted
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                            }
                        }

                        MouseArea {
                            id: hoverItem
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton && isApp) {
                                    launcher.pendingAppForActions = modelData.app
                                    searchField.text = ""
                                    launcher.filterApps("")
                                } else {
                                    launcher.launchItem(modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            pendingAppForActions = null
            mode = "apps"
            modeHint = ""
            searchField.text = ""
            launcher.filterApps("")
            resultsList.currentIndex = 0
            searchField.forceActiveFocus()
            loadUsage()
        } else {
            pendingAppForActions = null
            mode = "apps"
            modeHint = ""
        }
    }
}
