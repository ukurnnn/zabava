import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    implicitWidth: weatherRow.implicitWidth
    implicitHeight: 24

    property string weatherText: "--"
    property string condition: ""
    property string city: ""
    property bool loading: false
    property double lastUpdated: 0

    function refresh() {
        if (!weatherProc.running) weatherProc.running = true
    }

    Process {
        id: weatherProc
        command: ["bash", "-c",
            "curl -s --max-time 10 'https://wttr.in/" +
            (root.city !== "" ? root.city : "") + "?format=%C+%t' 2>/dev/null"
        ]
        running: true

        onStarted: root.loading = true

        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false
                var txt = (this.text || "").replace(/\n/g, " ").trim()
                if (txt === "" || txt.charAt(0) === "<" || txt.indexOf("Unknown location") === 0 || txt.indexOf("Sorry") === 0) {
                    if (root.lastUpdated === 0) root.weatherText = "N/A"
                    return
                }

                var parts = txt.split(/\s+/).filter(function(p) { return p !== "" })
                if (parts.length >= 2) {
                    root.weatherText = parts[parts.length - 1]
                    root.condition = parts.slice(0, parts.length - 1).join(" ")
                } else if (parts.length === 1) {
                    root.weatherText = parts[0]
                }
                root.lastUpdated = Date.now()
            }
        }

        onExited: (code, status) => {
            root.loading = false
            if (code !== 0 && root.lastUpdated === 0) root.weatherText = "N/A"
        }
    }

    Timer {
        interval: 15 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    function weatherIcon() {
        var c = (root.condition || "").toLowerCase()
        if (c.indexOf("thunder") !== -1 || c.indexOf("storm") !== -1) return "󰙾"
        if (c.indexOf("snow") !== -1 || c.indexOf("sleet") !== -1 || c.indexOf("blizzard") !== -1 || c.indexOf("ice") !== -1) return "󰖘"
        if (c.indexOf("rain") !== -1 || c.indexOf("drizzle") !== -1 || c.indexOf("shower") !== -1) return "󰖗"
        if (c.indexOf("fog") !== -1 || c.indexOf("mist") !== -1 || c.indexOf("haze") !== -1) return "󰖑"
        if (c.indexOf("partly") !== -1) return "󰖕"
        if (c.indexOf("cloud") !== -1 || c.indexOf("overcast") !== -1) return "󰖐"
        if (c.indexOf("sun") !== -1 || c.indexOf("clear") !== -1) return "󰖙"
        return "󰖐"
    }

    Row {
        id: weatherRow
        anchors.centerIn: parent
        spacing: 6

        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 2
            text: root.weatherIcon()
            color: root.loading && root.lastUpdated === 0 ? Theme.fgMuted : Theme.accent
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 15
            opacity: root.loading ? 0.7 : 1.0

            Behavior on opacity { NumberAnimation { duration: 200 } }
            Behavior on color { ColorAnimation { duration: 200 } }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 2
            text: root.weatherText
            color: Theme.fg
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
        }
    }
}
