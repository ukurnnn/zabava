pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    visible: false
    width: 0
    height: 0

    // "islands" | "monolithic"
    property string style: "islands"
    property string activePreset: "my_islands"
    property var userPresets: ({})

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

    function applyPreset(id) {
        var p = builtinPresets[id] || (userPresets ? userPresets[id] : null)
        if (!p) return
        root.style = p.style || "islands"
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
        up["my_saved"] = { name: "Сохранённый пресет", style: root.style }
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
            var obj = { style: root.style, activePreset: root.activePreset, userPresets: root.userPresets || {} }
            var json = JSON.stringify(obj).replace(/'/g, "'\\''")
            saveProc.command = ["bash", "-lc", "mkdir -p \"$HOME/.config/quickshell\" && printf '%s' '" + json + "' > " + configPath]
            saveProc.running = true
        } catch (e) {
        }
    }
}
