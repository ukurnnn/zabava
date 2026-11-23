pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    visible: false
    width: 0
    height: 0

    property var matugenColors: ({})

    readonly property string repoDir: String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "")
    readonly property string configHome: {
        var xdg = Quickshell.env("XDG_CONFIG_HOME")
        return (xdg && xdg !== "") ? xdg : (Quickshell.env("HOME") + "/.config")
    }
    readonly property string cacheHome: {
        var xdg = Quickshell.env("XDG_CACHE_HOME")
        return (xdg && xdg !== "") ? xdg : (Quickshell.env("HOME") + "/.cache")
    }
    readonly property string configDir: configHome + "/quickshell"
    readonly property string cacheDir: cacheHome + "/quickshell"
    readonly property string matugenColorsPath: cacheDir + "/matugen-colors.json"
    readonly property string defaultMatugenColorsPath: repoDir + "/matugen-colors.default.json"

    function loadMatugenText(txt, fromDefault) {
        var text = (txt || "").trim()
        if (text === "") return false
        try {
            var obj = JSON.parse(text)
            if (!obj || typeof obj !== "object") return false
            root.matugenColors = obj
            if (fromDefault) {
                // Seed cache from default; best-effort write.
                matugenSeedProc.command = ["bash", "-lc", "mkdir -p '" + root.cacheDir.replace(/'/g, "'\\''") + "' && [ -f '" + root.matugenColorsPath.replace(/'/g, "'\\''") + "' ] || cp '" + root.defaultMatugenColorsPath.replace(/'/g, "'\\''") + "' '" + root.matugenColorsPath.replace(/'/g, "'\\''") + "'"]
                matugenSeedProc.running = true
            }
            return true
        } catch (e) {
            return false
        }
    }

    FileView {
        id: colorsFile
        path: root.matugenColorsPath
        preload: true
        watchChanges: true
        printErrors: false

        onLoaded: {
            if (!root.loadMatugenText(colorsFile.text(), false))
                defaultColorsFile.reload()
        }
        onLoadFailed: function(error) { defaultColorsFile.reload() }
        onFileChanged: colorsFile.reload()
    }

    FileView {
        id: defaultColorsFile
        path: root.defaultMatugenColorsPath
        preload: false
        printErrors: false
        onLoaded: { root.loadMatugenText(defaultColorsFile.text(), true) }
    }

    Process { id: matugenSeedProc; command: ["bash", "-c", "true"]; running: false }

    function color(name) {
        return matugenColors[name] || fallbackColors[name] || "#cdd6f4"
    }

    readonly property var fallbackColors: ({
        bg: "#1e1e2e", surface: "#313244", surface1: "#45475a",
        overlay: "#6c7086", fg: "#cdd6f4", fgMuted: "#a6adc8",
        accent: "#89b4fa", accent2: "#b4befe", green: "#a6e3a1",
        yellow: "#f9e2af", orange: "#fab387", red: "#f38ba8",
        mauve: "#cba6f7", pink: "#f5c2e7", teal: "#94e2d5", sky: "#89dceb"
    })

    property color bg:        color("bg")
    property color surface:   color("surface")
    property color surface1:  color("surface1")
    property color overlay:   color("overlay")
    property color fg:        color("fg")
    property color fgMuted:   color("fgMuted")
    property color accent:    color("accent")
    property color accent2:   color("accent2")
    property color green:     color("green")
    property color yellow:    color("yellow")
    property color orange:    color("orange")
    property color red:       color("red")
    property color mauve:     color("mauve")
    property color pink:      color("pink")
    property color teal:      color("teal")
    property color sky:       color("sky")

    property bool glassEnabled: true
    property real glassOpacity: 1.0
    property real glassTint: 1.2
    property real glassHighlightStrength: 1.3
    property real glassBorderStrength: 1.1
    property bool glassBlur: false
    property bool sheenEnabled: true
    property int uiRevision: 0
    property string glassPreset: "balanced"

    property color mediaAccent: accent
    property bool mediaAccentActive: false

    readonly property string uiStylePath: configDir + "/ui-style.json"
    readonly property string defaultUiStylePath: repoDir + "/ui-style.default.json"
    readonly property int uiStyleVersion: 2

    function clampValue(v, lo, hi) {
        return Math.max(lo, Math.min(hi, Number(v)))
    }

    function applyUiStyleText(txt, fromDefault) {
        var text = (txt || "").trim()
        if (text === "") return false
        try {
            var obj = JSON.parse(text)
            if (!obj || typeof obj !== "object") return false
            var v = obj.uiStyleVersion !== undefined ? parseInt(obj.uiStyleVersion) : 1
            if (isNaN(v) || v < 1) v = 1

            if (obj.glassEnabled !== undefined) root.glassEnabled = obj.glassEnabled === true
            if (obj.glassOpacity !== undefined) root.glassOpacity = clampValue(obj.glassOpacity, 0.5, 1.6)
            if (obj.glassTint !== undefined) root.glassTint = clampValue(obj.glassTint, 0.4, 1.8)
            if (obj.glassHighlightStrength !== undefined) root.glassHighlightStrength = clampValue(obj.glassHighlightStrength, 0.0, 2.0)
            if (obj.glassBorderStrength !== undefined) root.glassBorderStrength = clampValue(obj.glassBorderStrength, 0.0, 2.0)
            if (obj.glassBlur !== undefined) root.glassBlur = obj.glassBlur === true
            if (obj.sheenEnabled !== undefined) root.sheenEnabled = obj.sheenEnabled === true
            if (obj.glassPreset !== undefined) root.glassPreset = String(obj.glassPreset)

            if (fromDefault || v < 2) root.saveUiStyle()
            return true
        } catch (e) {
            return false
        }
    }

    FileView {
        id: uiStyleFile
        path: root.uiStylePath
        preload: true
        watchChanges: true
        printErrors: false

        onLoaded: {
            if (!root.applyUiStyleText(uiStyleFile.text(), false))
                defaultUiStyleFile.reload()
        }
        onLoadFailed: function(error) { defaultUiStyleFile.reload() }
        onFileChanged: uiStyleFile.reload()
    }

    FileView {
        id: defaultUiStyleFile
        path: root.defaultUiStylePath
        preload: false
        printErrors: false
        onLoaded: { root.applyUiStyleText(defaultUiStyleFile.text(), true) }
    }

    Process {
        id: uiStyleSaveProc
        command: ["bash", "-c", "true"]
        running: false
    }

    function uiStyleObject() {
        return {
            uiStyleVersion: root.uiStyleVersion,
            glassEnabled: root.glassEnabled,
            glassOpacity: root.glassOpacity,
            glassTint: root.glassTint,
            glassHighlightStrength: root.glassHighlightStrength,
            glassBorderStrength: root.glassBorderStrength,
            glassBlur: root.glassBlur,
            sheenEnabled: root.sheenEnabled,
            glassPreset: root.glassPreset
        }
    }

    function saveUiStyle() {
        try {
            var json = JSON.stringify(uiStyleObject()).replace(/'/g, "'\\''")
            var dir = root.configDir.replace(/'/g, "'\\''")
            var path = root.uiStylePath.replace(/'/g, "'\\''")
            uiStyleSaveProc.command = ["bash", "-lc", "mkdir -p '" + dir + "' && printf '%s' '" + json + "' > '" + path + "'"]
            uiStyleSaveProc.running = true
        } catch (e) {
        }
    }

    function setGlassEnabled(v) {
        root.glassEnabled = v === true
        saveUiStyle()
    }

    function setGlassOpacity(v) { root.glassOpacity = clampValue(v, 0.5, 1.6); root.glassPreset = ""; saveUiStyle() }
    function setGlassTint(v) { root.glassTint = clampValue(v, 0.4, 1.8); root.glassPreset = ""; saveUiStyle() }
    function setGlassHighlightStrength(v) { root.glassHighlightStrength = clampValue(v, 0.0, 2.0); root.glassPreset = ""; saveUiStyle() }
    function setGlassBorderStrength(v) { root.glassBorderStrength = clampValue(v, 0.0, 2.0); root.glassPreset = ""; saveUiStyle() }
    function setGlassBlur(v) { root.glassBlur = v === true; saveUiStyle() }
    function setSheenEnabled(v) { root.sheenEnabled = v === true; saveUiStyle() }

    function applyGlassPreset(id) {
        var p = { opacity: 1.0, tint: 1.2, highlight: 1.3, border: 1.1 }
        if (id === "light") p = { opacity: 0.75, tint: 0.7, highlight: 0.55, border: 0.6 }
        else if (id === "strong") p = { opacity: 1.3, tint: 1.55, highlight: 1.8, border: 1.4 }
        else id = "balanced"
        root.glassOpacity = clampValue(p.opacity, 0.5, 1.6)
        root.glassTint = clampValue(p.tint, 0.4, 1.8)
        root.glassHighlightStrength = clampValue(p.highlight, 0.0, 2.0)
        root.glassBorderStrength = clampValue(p.border, 0.0, 2.0)
        root.glassPreset = id
        saveUiStyle()
    }

    function mix(a, b, t) {
        t = Math.max(0, Math.min(1, t))
        return Qt.rgba(a.r * (1 - t) + b.r * t, a.g * (1 - t) + b.g * t, a.b * (1 - t) + b.b * t, 1)
    }

    function glassAlpha(base, extra) {
        var blurBoost = root.glassBlur ? 0.07 : 0
        return Math.max(0.04, Math.min(0.92, base * root.glassOpacity + (extra || 0) + blurBoost))
    }

    readonly property real _tint: Math.max(0.15, Math.min(1.0, root.glassTint))

    property color glassPanel: root.glassEnabled ? Qt.rgba(mix(surface, accent, 0.45 * root._tint).r, mix(surface, accent, 0.45 * root._tint).g, mix(surface, accent, 0.45 * root._tint).b, glassAlpha(0.32)) : bg
    property color glassPanelStrong: root.glassEnabled ? Qt.rgba(mix(surface, accent2, 0.55 * root._tint).r, mix(surface, accent2, 0.55 * root._tint).g, mix(surface, accent2, 0.55 * root._tint).b, glassAlpha(0.44)) : bg
    property color glassCard: root.glassEnabled ? Qt.rgba(mix(surface1, accent, 0.42 * root._tint).r, mix(surface1, accent, 0.42 * root._tint).g, mix(surface1, accent, 0.42 * root._tint).b, glassAlpha(0.22)) : surface
    property color glassCardHover: root.glassEnabled ? Qt.rgba(mix(surface1, accent2, 0.56 * root._tint).r, mix(surface1, accent2, 0.56 * root._tint).g, mix(surface1, accent2, 0.56 * root._tint).b, glassAlpha(0.34)) : surface1
    property color glassIsland: root.glassEnabled ? Qt.rgba(mix(bg, accent, 0.42 * root._tint).r, mix(bg, accent, 0.42 * root._tint).g, mix(bg, accent, 0.42 * root._tint).b, glassAlpha(0.30)) : bg
    property color glassBorder: root.glassEnabled ? Qt.rgba(mix(fg, accent2, 0.72).r, mix(fg, accent2, 0.72).g, mix(fg, accent2, 0.72).b, Math.max(0.0, Math.min(0.9, 0.30 * root.glassBorderStrength * root.glassOpacity))) : "transparent"
    property color glassBorderStrong: root.glassEnabled ? Qt.rgba(mix(accent, accent2, 0.55).r, mix(accent, accent2, 0.55).g, mix(accent, accent2, 0.55).b, Math.max(0.0, Math.min(0.95, 0.48 * root.glassBorderStrength * root.glassOpacity))) : surface1
    property color glassHighlight: root.glassEnabled ? Qt.rgba(mix(Qt.rgba(1,1,1,1), accent2, 0.68).r, mix(Qt.rgba(1,1,1,1), accent2, 0.68).g, mix(Qt.rgba(1,1,1,1), accent2, 0.68).b, Math.max(0.0, Math.min(0.8, 0.38 * root.glassHighlightStrength))) : "transparent"
    property color glassHighlightSoft: root.glassEnabled ? Qt.rgba(mix(Qt.rgba(1,1,1,1), accent, 0.60).r, mix(Qt.rgba(1,1,1,1), accent, 0.60).g, mix(Qt.rgba(1,1,1,1), accent, 0.60).b, Math.max(0.0, Math.min(0.7, 0.22 * root.glassHighlightStrength))) : "transparent"
    property color glassShadow: root.glassEnabled ? Qt.rgba(0, 0, 0, Math.max(0.0, Math.min(0.6, 0.28 * root.glassOpacity))) : "transparent"

    Behavior on bg       { ColorAnimation { duration: 250; easing.type: Easing.InOutQuad } }
    Behavior on surface  { ColorAnimation { duration: 250; easing.type: Easing.InOutQuad } }
    Behavior on surface1 { ColorAnimation { duration: 250; easing.type: Easing.InOutQuad } }
    Behavior on overlay  { ColorAnimation { duration: 250; easing.type: Easing.InOutQuad } }
    Behavior on fg       { ColorAnimation { duration: 250; easing.type: Easing.InOutQuad } }
    Behavior on fgMuted  { ColorAnimation { duration: 250; easing.type: Easing.InOutQuad } }
    Behavior on accent   { ColorAnimation { duration: 250; easing.type: Easing.InOutQuad } }
    Behavior on accent2  { ColorAnimation { duration: 250; easing.type: Easing.InOutQuad } }
    Behavior on green    { ColorAnimation { duration: 250; easing.type: Easing.InOutQuad } }
    Behavior on yellow   { ColorAnimation { duration: 250; easing.type: Easing.InOutQuad } }
    Behavior on orange   { ColorAnimation { duration: 250; easing.type: Easing.InOutQuad } }
    Behavior on red      { ColorAnimation { duration: 250; easing.type: Easing.InOutQuad } }
    Behavior on mauve    { ColorAnimation { duration: 250; easing.type: Easing.InOutQuad } }
    Behavior on pink     { ColorAnimation { duration: 250; easing.type: Easing.InOutQuad } }
    Behavior on teal     { ColorAnimation { duration: 250; easing.type: Easing.InOutQuad } }
    Behavior on sky      { ColorAnimation { duration: 250; easing.type: Easing.InOutQuad } }
    // Glass/media color behaviors disabled: they caused visible flicker in bar islands.

    property string current: "matugen"
    readonly property var themeNames: ["matugen"]
    readonly property var themeLabels: ({ matugen: "Matugen" })
    readonly property var allThemes: ({})
    readonly property bool isDark: true

    function setTheme(name) {}
    function cycle(step) {}
    function setMediaAccent(c, active) {
        root.mediaAccent = c
        root.mediaAccentActive = active === true
        root.uiRevision = (root.uiRevision + 1) % 1000000
    }
    function label(name) { return "Matugen" }
}
