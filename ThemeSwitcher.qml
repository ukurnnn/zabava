import QtQuick
import Quickshell

Item {
    id: root
    implicitWidth: 32
    implicitHeight: 24

    Text {
        anchors.centerIn: parent
        text: Theme.isDark ? "󰖙" : "󰖚"
        color: switchArea.containsMouse ? Theme.yellow : Theme.fg
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 15
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    MouseArea {
        id: switchArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Theme.toggle()
    }
}
