import QtQuick
import Quickshell

Item {
    id: root
    implicitWidth: row.implicitWidth + 8
    implicitHeight: 24

    property string icon: "󰐥"
    property var target: null

    function cycleProfile() {
        if (!PowerProfileService.available) return
        var ps = PowerProfileService.profiles && PowerProfileService.profiles.length > 0 ? PowerProfileService.profiles : ["power-saver", "balanced", "performance"]
        var idx = ps.indexOf(PowerProfileService.current)
        PowerProfileService.setProfile(ps[(idx + 1) % ps.length])
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Text {
            text: root.icon
            color: powerArea.containsMouse ? Theme.red : Theme.fg
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 15
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        Text {
            visible: PowerProfileService.available
            text: PowerProfileService.iconFor(PowerProfileService.current || "balanced")
            color: powerArea.containsMouse ? Theme.accent : Theme.fgMuted
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }

    MouseArea {
        id: powerArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) { root.cycleProfile(); return }
            if (root.target) root.target.visible = !root.target.visible
        }
    }
}
