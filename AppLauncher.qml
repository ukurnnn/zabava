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
    property var filteredApps: []
    property string searchText: ""
    property int maxSearchResults: 10

    // usageTimestamps: { appId: [unix_ts, unix_ts, ...] }
    property var usageTimestamps: ({})

    readonly property string usageFile: Quickshell.env("HOME") + "/.config/quickshell/usage.json"

    property var blacklist: [
        "avahi", "bssh", "bvnc", "qv4l2", "qvidcap",
        "kdeconnect", "xterm", "uxterm", "htop"
    ]

    Component.onCompleted: {
        loadUsage()
    }

    Timer {
        interval: 500
        running: true
        repeat: false
        onTriggered: {
            if (allApps.length === 0) loadApps()
        }
    }

    Process {
        id: usageReadProc
        command: ["cat", launcher.usageFile]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    launcher.usageTimestamps = JSON.parse(this.text)
                } catch (e) {
                    launcher.usageTimestamps = ({})
                }
                launcher.loadApps()
            }
        }
    }

    function loadUsage() {
        usageReadProc.running = true
    }

    function saveUsage() {
        usageWriteProc.command = ["bash", "-c",
            "echo '" + JSON.stringify(usageTimestamps) + "' > " + usageFile]
        usageWriteProc.running = true
    }

    Process {
        id: usageWriteProc
        command: ["bash", "-c", "echo"]
        running: false
    }

    // Считаем frecency-score для приложения (только запуски через этот лаунчер)
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
        function toggle(): void {
            launcher.visible = !launcher.visible
        }
    }

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
                if (id.indexOf(blacklist[j]) !== -1 || name.indexOf(blacklist[j]) !== -1) {
                    hidden = true
                    break
                }
            }
            if (hidden) continue

            apps.push(entry)
        }

        // Топ: сначала чаще запускаемые через лаунчер, затем по алфавиту
        apps.sort(function(a, b) {
            var scoreA = launcher.frecencyScore(a.id)
            var scoreB = launcher.frecencyScore(b.id)
            if (scoreB !== scoreA) return scoreB - scoreA
            return launcher.norm(a.name).localeCompare(launcher.norm(b.name))
        })

        allApps = apps
        filteredApps = apps
    }

    function norm(s) {
        return (s === undefined || s === null ? "" : ("" + s)).toLowerCase().trim()
    }

    // ===================== ВЕСА РАНЖИРОВАНИЯ =====================
    // name == query ................................. 1000
    // name начинается с query ....................... 800
    // слово в name начинается с query ............... 600
    //   (разделители: пробел, дефис, подчёркивание, точка)
    // query — подстрока в середине name ............. 300
    // genericName содержит query .................... 150  (только если name не дал очков)
    // слово в keywords начинается с query ........... 100  (только если name не дал очков)
    // fuzzy-фолбэк (последний): общий непрерывный блок
    //   запроса и name длиной >= 80% от запроса .... 50 * ratio
    //   (включается только если пункты выше не дали ни одного результата,
    //    и только при длине запроса >= 3; по умолчанию выключен)
    // бонус за короткое name ........................ +max(0, 30 - name.length)
    // бонус за частоту запусков (история) ........... +0..50
    // comment / Exec / имя бинарника ................ не используются
    // ==============================================================
    function score(entry, query, allowFuzzy) {
        var q = norm(query)
        if (q === "") return 0

        var name = norm(entry.name)
        var s = 0

        // --- главное поле: name ---
        if (name === q) {
            s = 1000
        } else if (name.indexOf(q) === 0) {
            s = 800
        } else {
            var words = name.split(/[ \-_.]+/)
            for (var i = 0; i < words.length; i++) {
                if (words[i] !== "" && words[i].indexOf(q) === 0) {
                    s = 600
                    break
                }
            }
            if (s === 0 && name.indexOf(q) !== -1) s = 300
        }

        // --- дополнительные поля, только если name не дал очков ---
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
                    if (kwWords[w] !== "" && kwWords[w].indexOf(q) === 0) {
                        s = 100
                        break outer
                    }
                }
            }
        }

        // --- последний фолбэк: нечёткий поиск (только если обычных совпадений нет) ---
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
            if (bestBlock >= minBlock) {
                var ratio = bestBlock / q.length
                s = Math.round(50 * ratio)
            }
        }

        if (s === 0) return 0

        // --- бонусы ---
        s += Math.max(0, 30 - name.length)
        s += Math.min(50, Math.round(launcher.frecencyScore(entry.id) / 4))

        return s
    }

    function filterApps(query) {
        var q = norm(query)

        if (q === "") {
            var base = allApps.slice()
            base.sort(function(a, b) {
                var scoreA = launcher.frecencyScore(a.id)
                var scoreB = launcher.frecencyScore(b.id)
                if (scoreB !== scoreA) return scoreB - scoreA
                return launcher.norm(a.name).localeCompare(launcher.norm(b.name))
            })
            filteredApps = base
            resultsList.currentIndex = 0
            return
        }

        var scored = []
        for (var i = 0; i < allApps.length; i++) {
            var s = score(allApps[i], q, false)
            if (s > 0) scored.push({ app: allApps[i], score: s })
        }

        // нечёткий поиск — только если обычные правила не дали ничего
        if (scored.length === 0) {
            for (var f = 0; f < allApps.length; f++) {
                var fs = score(allApps[f], q, true)
                if (fs > 0) scored.push({ app: allApps[f], score: fs })
            }
        }

        scored.sort(function(a, b) {
            if (b.score !== a.score) return b.score - a.score
            var la = norm(a.app.name).length
            var lb = norm(b.app.name).length
            if (la !== lb) return la - lb
            return norm(a.app.name).localeCompare(norm(b.app.name))
        })

        var out = []
        for (var j = 0; j < scored.length && j < launcher.maxSearchResults; j++)
            out.push(scored[j].app)

        filteredApps = out
        resultsList.currentIndex = 0
    }

    function launchApp(app) {
        var id = app.id || ""
        var now = Math.floor(Date.now() / 1000)
        var cutoff = now - 90 * 86400

        var newTimestamps = Object.assign({}, usageTimestamps)
        var stamps = (newTimestamps[id] || []).slice()

        // Убираем записи старше 90 дней, чтобы файл не рос бесконечно
        stamps = stamps.filter(function(ts) { return ts >= cutoff })

        // Добавляем текущий запуск
        stamps.push(now)
        newTimestamps[id] = stamps

        usageTimestamps = newTimestamps
        saveUsage()

        app.execute()
        launcher.visible = false
    }

    MouseArea {
        anchors.fill: parent
        onClicked: launcher.visible = false
    }

    Item {
        id: launcherBox
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom

        width: 500
        height: launcher.visible ? 400 : 0

        anchors.bottomMargin: launcher.visible ? 12 : -height - 20

        clip: true

        Behavior on height {
            NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
        }

        Behavior on anchors.bottomMargin {
            NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
        }

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: Theme.bg
            border.color: Theme.surface
            border.width: 1

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
                        placeholderText: "Search applications..."
                        placeholderTextColor: Theme.fgMuted
                        color: Theme.fg
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 15
                        background: null
                        focus: true
                        selectByMouse: true

                        onTextChanged: {
                            launcher.searchText = text
                            launcher.filterApps(text)
                        }

                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Down) {
                                resultsList.incrementCurrentIndex()
                                event.accepted = true
                            } else if (event.key === Qt.Key_Up) {
                                resultsList.decrementCurrentIndex()
                                event.accepted = true
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (resultsList.currentIndex >= 0 && resultsList.currentIndex < launcher.filteredApps.length) {
                                    launcher.launchApp(launcher.filteredApps[resultsList.currentIndex])
                                }
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
                    model: launcher.filteredApps
                    currentIndex: 0

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        width: resultsList.width
                        height: 42
                        radius: 8
                        color: index === resultsList.currentIndex ? Theme.accent : (hoverItem.containsMouse ? Theme.surface : "transparent")
                        Behavior on color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 10

                            IconImage {
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                Layout.alignment: Qt.AlignVCenter
                                source: modelData.icon ? Quickshell.iconPath(modelData.icon) : ""
                                visible: modelData.icon !== ""
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 0

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    color: index === resultsList.currentIndex ? Theme.bg : Theme.fg
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    visible: modelData.genericName && modelData.genericName !== ""
                                    text: modelData.genericName || ""
                                    color: index === resultsList.currentIndex ? Theme.bg : Theme.fgMuted
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        MouseArea {
                            id: hoverItem
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: launcher.launchApp(modelData)
                        }
                    }
                }
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            searchField.text = ""
            launcher.filterApps("")
            resultsList.currentIndex = 0
            searchField.forceActiveFocus()
            loadUsage()
        }
    }
}
