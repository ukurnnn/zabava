import QtQuick
import Quickshell

Item {
    id: root
    implicitWidth: 32
    implicitHeight: 24

    property string icon: "󰐥"
    property var target: null   // окно PowerMenu — переключаем напрямую

    Text {
        anchors.centerIn: parent
        text: root.icon
        color: powerArea.containsMouse ? Theme.red : Theme.fg
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 15
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    MouseArea {
        id: powerArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.target) root.target.visible = !root.target.visible
        }
    }
}
