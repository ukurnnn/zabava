import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    implicitWidth: 32
    implicitHeight: 24

    property bool isInhibited: false

    Process {
        id: checkProc
        command: ["pgrep", "-f", "systemd-inhibit.*idle.*quickshell"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.isInhibited = this.text.trim() !== ""
            }
        }
    }

    Process {
        id: inhibitProc
        command: ["systemd-inhibit", "--what=idle", "--who=quickshell", "--why=User requested", "sleep", "infinity"]
        running: false
    }

    Process {
        id: uninhibitProc
        command: ["pkill", "-f", "systemd-inhibit --what=idle --who=quickshell"]
        running: false
    }

    Component.onCompleted: checkProc.running = true

    function toggle() {
        if (isInhibited) {
            uninhibitProc.running = true
            isInhibited = false
        } else {
            inhibitProc.running = true
            isInhibited = true
        }
    }

    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 2
        text: root.isInhibited ? "󰅶" : "󰾪"
        color: root.isInhibited ? Theme.yellow : Theme.fgMuted
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 15
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggle()
    }
}
