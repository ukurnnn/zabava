pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    visible: false
    width: 0
    height: 0

    // "islands" | "monolithic" | "full"
    property string style: "islands"
    property string activePreset: "my_islands"
    property var userPresets: ({})

    readonly property var defaultModuleOrder: ({
        left: ["workspaces", "mpris"],
        center: ["clock"],
        right: ["volume", "sysmon", "layout", "network", "tray", "power"]
    })
    property var moduleOrder: ({
        left: defaultModuleOrder.left.slice(),
        center: defaultModuleOrder.center.slice(),
        right: defaultModuleOrder.right.slice()
    })
    property var hiddenModules: ([])

    readonly property var moduleMeta: ({
        workspaces: { name: "Рабочие столы", icon: "󰍹" },
        mpris:      { name: "Медиа",         icon: "󰎆" },
        clock:      { name: "Часы/Погода",   icon: "󰥔" },
        volume:     { name: "Громкость",     icon: "󰕾" },
        sysmon:     { name: "Мониторинг",    icon: "󰍛" },
        layout:     { name: "Раскладка",     icon: "󰌌" },
        network:    { name: "Сеть",          icon: "󰖩" },
        tray:       { name: "Трей",          icon: "󰇙" },
        power:      { name: "Питание",       icon: "󰐥" }
    })

    readonly property string configPath: Quickshell.env("HOME") + "/.config/quickshell/bar-config.json"

    readonly property var builtinPresets: ({
        my_islands: { name: "Островки", style: "islands" },
        monolithic: { name: "Монолитный", style: "monolithic" },
        full: { name: "Монолитный (на всю ширину)", style: "full" }
    })

    function allPresets() {
        var list = []
        var bkeys = Object.keys(builtinPresets)
        for (var i = 0; i < bkeys.length; i++) {
            var id = bkeys[i]
            list.push({ id: id, name: builtinPresets[id].name, style: builtinPresets[id].style, builtin: true })
        }
        var up = userPresets || {}
        var ukeys = Object.keys(up)
        for (var j = 0; j < ukeys.length; j++) {
            var uid = ukeys[j]
            list.push({ id: uid, name: up[uid].name || uid, style: up[uid].style || "islands", builtin: false })
        }
        return list
    }

    function cloneOrder(ord) {
        ord = ord || {}
        return {
            left: (ord.left || defaultModuleOrder.left).slice(),
            center: (ord.center || defaultModuleOrder.center).slice(),
            right: (ord.right || defaultModuleOrder.right).slice()
        }
    }

    function ensureModuleOrder() {
        var o = root.moduleOrder || {}
        var changed = false
        var sections = ["left", "center", "right"]
        for (var s = 0; s < sections.length; s++) {
            var sec = sections[s]
            if (!o[sec]) { o[sec] = defaultModuleOrder[sec].slice(); changed = true }
        }
        if (changed) root.moduleOrder = cloneOrder(o)
        return root.moduleOrder
    }

    function isModuleHidden(id) {
        var h = root.hiddenModules || []
        for (var i = 0; i < h.length; i++) if (h[i] === id) return true
        return false
    }

    function visibleOrder(section) {
        ensureModuleOrder()
        var list = (root.moduleOrder[section] || [])
        var out = []
        for (var i = 0; i < list.length; i++) {
            if (!isModuleHidden(list[i])) out.push(list[i])
        }
        return out
    }

    function setModuleHidden(id, hidden) {
        var h = (root.hiddenModules || []).slice()
        var idx = h.indexOf(id)
        if (hidden && idx === -1) h.push(id)
        else if (!hidden && idx !== -1) h.splice(idx, 1)
        root.hiddenModules = h
        save()
    }

    function moveModule(id, direction) {
        ensureModuleOrder()
        var sections = ["left", "center", "right"]
        var sec = "", idx = -1
        for (var s = 0; s < sections.length; s++) {
            var list = root.moduleOrder[sections[s]] || []
            for (var i = 0; i < list.length; i++) {
                if (list[i] === id) { sec = sections[s]; idx = i; break }
            }
            if (sec !== "") break
        }
        if (sec === "" || idx < 0) return
        var arr = (root.moduleOrder[sec] || []).slice()
        var ni = idx + direction
        if (ni < 0 || ni >= arr.length) return
        var tmp = arr[idx]; arr[idx] = arr[ni]; arr[ni] = tmp
        var o = cloneOrder(root.moduleOrder)
        o[sec] = arr
        root.moduleOrder = o
        save()
    }

    function moveModuleToSection(id, targetSection) {
        ensureModuleOrder()
        var sections = ["left", "center", "right"]
        var src = ""
        for (var s = 0; s < sections.length; s++) {
            var list = root.moduleOrder[sections[s]] || []
            for (var i = 0; i < list.length; i++) {
                if (list[i] === id) { src = sections[s]; break }
            }
            if (src !== "") break
        }
        if (src === "" || src === targetSection) return
        var o = cloneOrder(root.moduleOrder)
        var from = o[src]; var idx = from.indexOf(id)
        if (idx === -1) return
        from.splice(idx, 1)
        o[targetSection].push(id)
        root.moduleOrder = o
        save()
    }

    function resetModuleLayout() {
        root.moduleOrder = cloneOrder(defaultModuleOrder)
        root.hiddenModules = []
        save()
    }

    function applyPreset(id) {
        var p = builtinPresets[id] || (userPresets ? userPresets[id] : null)
        if (!p) return
        root.style = p.style || "islands"
        if (p.moduleOrder) root.moduleOrder = cloneOrder(p.moduleOrder)
        if (p.hiddenModules) root.hiddenModules = p.hiddenModules.slice()
        root.activePreset = id
        save()
    }

    function setStyle(s) {
        root.style = s
        if (s === "islands") root.activePreset = "my_islands"
        else if (s === "monolithic") root.activePreset = "monolithic"
        else if (s === "full") root.activePreset = "full"
        else root.activePreset = ""
        save()
    }

    function saveCurrentAsMyPreset() {
        var up = Object.assign({}, userPresets || {})
        up["my_saved"] = {
            name: "Сохранённый пресет",
            style: root.style,
            moduleOrder: cloneOrder(root.moduleOrder),
            hiddenModules: (root.hiddenModules || []).slice()
        }
        root.userPresets = up
        root.activePreset = "my_saved"
        save()
    }

    FileView {
        id: cfgFile
        path: root.configPath
        preload: true
        watchChanges: true
        printErrors: false

        onLoaded: {
            var txt = cfgFile.text().trim()
            if (txt === "") return
            try {
                var obj = JSON.parse(txt)
                if (obj && obj.style) root.style = obj.style
                if (obj && obj.activePreset) root.activePreset = obj.activePreset
                if (obj && obj.userPresets) root.userPresets = obj.userPresets
                if (obj && obj.moduleOrder) root.moduleOrder = root.cloneOrder(obj.moduleOrder)
                if (obj && obj.hiddenModules) root.hiddenModules = obj.hiddenModules
            } catch (e) {
            }
        }

        onFileChanged: cfgFile.reload()
    }

    Process {
        id: saveProc
        command: ["bash", "-c", "true"]
        running: false
    }

    function save() {
        try {
            var obj = {
                style: root.style,
                activePreset: root.activePreset,
                userPresets: root.userPresets || {},
                moduleOrder: root.cloneOrder(root.moduleOrder),
                hiddenModules: (root.hiddenModules || []).slice()
            }
            var json = JSON.stringify(obj).replace(/'/g, "'\\''")
            saveProc.command = ["bash", "-lc", "mkdir -p \"$HOME/.config/quickshell\" && printf '%s' '" + json + "' > " + configPath]
            saveProc.running = true
        } catch (e) {
        }
    }
}
