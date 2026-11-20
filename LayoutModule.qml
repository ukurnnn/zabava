import QtQuick
import Quickshell

Item {
    id: root
    implicitWidth: contentRow.implicitWidth + 8
    implicitHeight: 24

    // Раскладка приходит из NiriService (event-stream), поллинг не нужен
    readonly property string currentLayout: NiriService.keyboardLayoutIdx === 0 ? "EN" : "RU"

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 4

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰌌"
            color: Theme.accent
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.currentLayout
            color: Theme.fg
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            font.bold: true
        }
    }
}
