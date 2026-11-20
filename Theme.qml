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

    FileView {
        id: colorsFile
        path: Quickshell.env("HOME") + "/.config/quickshell/matugen-colors.json"
        preload: true
        watchChanges: true
        printErrors: false

        onLoaded: {
            var txt = colorsFile.text().trim()
            if (txt === "") return
            try {
                root.matugenColors = JSON.parse(txt)
            } catch (e) {
            }
        }

        onFileChanged: colorsFile.reload()
    }

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
    readonly property string uiStylePath: Quickshell.env("HOME") + "/.config/quickshell/ui-style.json"

    FileView {
        id: uiStyleFile
        path: root.uiStylePath
        preload: true
        watchChanges: true
        printErrors: false

        onLoaded: {
            var txt = uiStyleFile.text().trim()
            if (txt === "") return
            try {
                var obj = JSON.parse(txt)
                if (obj && obj.glassEnabled !== undefined) root.glassEnabled = obj.glassEnabled === true
            } catch (e) {
            }
        }
        onFileChanged: uiStyleFile.reload()
    }

    Process {
        id: uiStyleSaveProc
        command: ["bash", "-c", "true"]
        running: false
    }

    function saveUiStyle() {
        try {
            var json = JSON.stringify({ glassEnabled: root.glassEnabled }).replace(/'/g, "'\\''")
            uiStyleSaveProc.command = ["bash", "-lc", "mkdir -p \"$HOME/.config/quickshell\" && printf '%s' '" + json + "' > " + uiStylePath]
            uiStyleSaveProc.running = true
        } catch (e) {
        }
    }

    function setGlassEnabled(v) {
        root.glassEnabled = v === true
        saveUiStyle()
    }

    property color glassPanel: root.glassEnabled ? Qt.rgba((surface.r * 0.55 + accent.r * 0.45), (surface.g * 0.55 + accent.g * 0.45), (surface.b * 0.55 + accent.b * 0.45), 0.32) : bg
    property color glassPanelStrong: root.glassEnabled ? Qt.rgba((surface.r * 0.45 + accent2.r * 0.55), (surface.g * 0.45 + accent2.g * 0.55), (surface.b * 0.45 + accent2.b * 0.55), 0.44) : bg
    property color glassCard: root.glassEnabled ? Qt.rgba((surface1.r * 0.58 + accent.r * 0.42), (surface1.g * 0.58 + accent.g * 0.42), (surface1.b * 0.58 + accent.b * 0.42), 0.22) : surface
    property color glassCardHover: root.glassEnabled ? Qt.rgba((surface1.r * 0.44 + accent2.r * 0.56), (surface1.g * 0.44 + accent2.g * 0.56), (surface1.b * 0.44 + accent2.b * 0.56), 0.34) : surface1
    property color glassIsland: root.glassEnabled ? Qt.rgba((bg.r * 0.58 + accent.r * 0.42), (bg.g * 0.58 + accent.g * 0.42), (bg.b * 0.58 + accent.b * 0.42), 0.30) : bg
    property color glassBorder: root.glassEnabled ? Qt.rgba((accent2.r * 0.72 + fg.r * 0.28), (accent2.g * 0.72 + fg.g * 0.28), (accent2.b * 0.72 + fg.b * 0.28), 0.30) : "transparent"
    property color glassBorderStrong: root.glassEnabled ? Qt.rgba((accent.r * 0.45 + accent2.r * 0.55), (accent.g * 0.45 + accent2.g * 0.55), (accent.b * 0.45 + accent2.b * 0.55), 0.48) : surface1
    property color glassHighlight: root.glassEnabled ? Qt.rgba((1 * 0.32 + accent2.r * 0.68), (1 * 0.32 + accent2.g * 0.68), (1 * 0.32 + accent2.b * 0.68), 0.38) : "transparent"
    property color glassHighlightSoft: root.glassEnabled ? Qt.rgba((1 * 0.40 + accent.r * 0.60), (1 * 0.40 + accent.g * 0.60), (1 * 0.40 + accent.b * 0.60), 0.22) : "transparent"
    property color glassShadow: root.glassEnabled ? Qt.rgba(0, 0, 0, 0.28) : "transparent"

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
    Behavior on glassPanel { ColorAnimation { duration: 250; easing.type: Easing.InOutQuad } }
    Behavior on glassPanelStrong { ColorAnimation { duration: 250; easing.type: Easing.InOutQuad } }
    Behavior on glassCard { ColorAnimation { duration: 250; easing.type: Easing.InOutQuad } }
    Behavior on glassCardHover { ColorAnimation { duration: 250; easing.type: Easing.InOutQuad } }
    Behavior on glassIsland { ColorAnimation { duration: 250; easing.type: Easing.InOutQuad } }
    Behavior on glassBorder { ColorAnimation { duration: 250; easing.type: Easing.InOutQuad } }
    Behavior on glassBorderStrong { ColorAnimation { duration: 250; easing.type: Easing.InOutQuad } }
    Behavior on glassHighlight { ColorAnimation { duration: 250; easing.type: Easing.InOutQuad } }
    Behavior on glassHighlightSoft { ColorAnimation { duration: 250; easing.type: Easing.InOutQuad } }
    Behavior on glassShadow { ColorAnimation { duration: 250; easing.type: Easing.InOutQuad } }

    property string current: "matugen"
    readonly property var themeNames: ["matugen"]
    readonly property var themeLabels: ({ matugen: "Matugen" })
    readonly property var allThemes: ({})
    readonly property bool isDark: true

    function setTheme(name) {}
    function cycle(step) {}
    function label(name) { return "Matugen" }
}
