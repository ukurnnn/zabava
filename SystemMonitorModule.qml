import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    implicitWidth: contentRow.implicitWidth
    implicitHeight: 24

    property real cpuUsage: 0
    property var prevCpuStats: null
    property real ramUsage: 0

    // Один процесс на оба счётчика вместо двух отдельных таймеров
    Process {
        id: statsProc
        command: ["cat", "/proc/stat", "/proc/meminfo"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n")
                // CPU — первая строка /proc/stat
                const parts = lines[0].split(/\s+/).slice(1).map(Number)
                const idle = parts[3] + parts[4]
                const total = parts.reduce((a, b) => a + b, 0)
                if (root.prevCpuStats) {
                    const dTotal = total - root.prevCpuStats.total
                    const dIdle = idle - root.prevCpuStats.idle
                    if (dTotal > 0)
                        root.cpuUsage = (1 - dIdle / dTotal) * 100
                }
                root.prevCpuStats = { total, idle }

                // RAM
                let memTotal = 0, memAvail = 0
                for (const l of lines) {
                    if (l.startsWith("MemTotal:")) memTotal = parseInt(l.split(/\s+/)[1])
                    else if (l.startsWith("MemAvailable:")) memAvail = parseInt(l.split(/\s+/)[1])
                }
                if (memTotal > 0) root.ramUsage = (memTotal - memAvail) / memTotal * 100
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: statsProc.running = true
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 12

        Text {
            text: "󰍛  " + root.cpuUsage.toFixed(0) + "%"
            color: root.cpuUsage > 80 ? Theme.red
                 : root.cpuUsage > 50 ? Theme.yellow
                 : Theme.fg
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 15
            Behavior on color { ColorAnimation { duration: 300 } }
        }

        Text {
            text: "󰘚  " + root.ramUsage.toFixed(0) + "%"
            color: root.ramUsage > 80 ? Theme.red
                 : root.ramUsage > 50 ? Theme.yellow
                 : Theme.fg
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 15
            Behavior on color { ColorAnimation { duration: 300 } }
        }
    }
}
