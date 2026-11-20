import QtQuick
import Quickshell

Item {
    id: root
    anchors.fill: parent

    property var target: null
    property int clickCount: 0

    Timer {
        id: resetTimer
        interval: 300
        repeat: false
        onTriggered: root.clickCount = 0
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton

        onClicked: {
            root.clickCount++
            if (root.clickCount >= 2) {
                root.clickCount = 0
                resetTimer.stop()
                if (root.target) root.target.visible = false
            } else {
                resetTimer.restart()
            }
        }
    }

    // Esc тоже закрывает
    Item {
        anchors.fill: parent
        focus: true
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                if (root.target) root.target.visible = false
                event.accepted = true
            }
        }
    }
}
