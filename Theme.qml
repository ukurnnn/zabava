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

    readonly property color bg:        color("bg")
    readonly property color surface:   color("surface")
    readonly property color surface1:  color("surface1")
    readonly property color overlay:   color("overlay")
    readonly property color fg:        color("fg")
    readonly property color fgMuted:   color("fgMuted")
    readonly property color accent:    color("accent")
    readonly property color accent2:   color("accent2")
    readonly property color green:     color("green")
    readonly property color yellow:    color("yellow")
    readonly property color orange:    color("orange")
    readonly property color red:       color("red")
    readonly property color mauve:     color("mauve")
    readonly property color pink:      color("pink")
    readonly property color teal:      color("teal")
    readonly property color sky:       color("sky")

    property string current: "matugen"
    readonly property var themeNames: ["matugen"]
    readonly property var themeLabels: ({ matugen: "Matugen" })
    readonly property var allThemes: ({})
    readonly property bool isDark: true

    function setTheme(name) {}
    function cycle(step) {}
    function label(name) { return "Matugen" }
}
