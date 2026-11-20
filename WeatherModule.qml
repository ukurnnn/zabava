import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    implicitWidth: weatherRow.implicitWidth
    implicitHeight: 24

    property var popup: null
    property string weatherText: "--"
    property string condition: ""
    property string feelsLike: ""
    property string humidity: ""
    property string wind: ""
    property string location: ""
    property string city: ""
    property bool loading: false
    property double lastUpdated: 0

    function refresh() {
        if (!weatherProc.running) weatherProc.running = true
    }

    function weatherIcon(cond) {
        var c = (cond !== undefined ? cond : root.condition || "").toLowerCase()
        if (c.indexOf("thunder") !== -1 || c.indexOf("storm") !== -1) return "󰙾"
        if (c.indexOf("snow") !== -1 || c.indexOf("sleet") !== -1 || c.indexOf("blizzard") !== -1 || c.indexOf("ice") !== -1) return "󰖘"
        if (c.indexOf("rain") !== -1 || c.indexOf("drizzle") !== -1 || c.indexOf("shower") !== -1) return "󰖗"
        if (c.indexOf("fog") !== -1 || c.indexOf("mist") !== -1 || c.indexOf("haze") !== -1) return "󰖑"
        if (c.indexOf("partly") !== -1) return "󰖕"
        if (c.indexOf("cloud") !== -1 || c.indexOf("overcast") !== -1) return "󰖐"
        if (c.indexOf("sun") !== -1 || c.indexOf("clear") !== -1) return "󰖙"
        if (c.indexOf("wind") !== -1) return "󰖝"
        return "󰖐"
    }

    function lastUpdatedText() {
        if (!root.lastUpdated) return ""
        return Qt.formatDateTime(new Date(root.lastUpdated), "HH:mm")
    }

    Process {
        id: weatherProc
        command: ["bash", "-c",
            "curl -s --max-time 10 'https://wttr.in/" +
            (root.city !== "" ? encodeURIComponent(root.city) : "") + "?format=%C|%t|%f|%h|%w|%l' 2>/dev/null"
        ]
        running: true

        onStarted: root.loading = true

        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false
                var txt = (this.text || "").replace(/\r/g, "").trim()
                if (txt === "" || txt.charAt(0) === "<" || txt.indexOf("Unknown location") === 0 || txt.indexOf("Sorry") === 0) {
                    if (root.lastUpdated === 0) root.weatherText = "N/A"
                    return
                }

                var parts = txt.split("|")
                if (parts.length >= 2) {
                    root.condition = (parts[0] || "").trim()
                    root.weatherText = (parts[1] || "").trim()
                    root.feelsLike = parts.length > 2 ? (parts[2] || "").trim() : ""
                    root.humidity = parts.length > 3 ? (parts[3] || "").trim() : ""
                    root.wind = parts.length > 4 ? (parts[4] || "").trim() : ""
                    root.location = parts.length > 5 ? (parts[5] || "").trim() : ""
                } else {
                    var words = txt.split(/\s+/).filter(function(p) { return p !== "" })
                    if (words.length >= 2) {
                        root.weatherText = words[words.length - 1]
                        root.condition = words.slice(0, words.length - 1).join(" ")
                    } else if (words.length === 1) {
                        root.weatherText = words[0]
                    }
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

    Row {
        id: weatherRow
        anchors.centerIn: parent
        spacing: 6

        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 2
            text: root.weatherIcon()
            color: weatherMouse.containsMouse ? Theme.yellow : (root.loading && root.lastUpdated === 0 ? Theme.fgMuted : Theme.accent)
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 15
            opacity: root.loading ? 0.75 : 1.0

            Behavior on opacity { NumberAnimation { duration: 200 } }
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 2
            text: root.weatherText
            color: weatherMouse.containsMouse ? Theme.fg : Theme.fg
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
        }
    }

    MouseArea {
        id: weatherMouse
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        cursorShape: root.popup ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (root.popup) root.popup.visible = !root.popup.visible
        }
    }
}
