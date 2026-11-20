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

    // FileView: читает один раз и следит за изменением файла (matugen перезаписывает json).
    // Никаких опросов и спавна процессов.
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
                console.log("Matugen parse error:", e)
            }
        }

        // matugen обновил палитру (смена обоев) — перечитываем мгновенно
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

    property string current: "matugen"
    readonly property var themeNames: ["matugen"]
    readonly property var themeLabels: ({ matugen: "Matugen" })
    readonly property var allThemes: ({})
    readonly property bool isDark: true

    function setTheme(name) {}
    function cycle(step) {}
    function label(name) { return "Matugen" }
}
