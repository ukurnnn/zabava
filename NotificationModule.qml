import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Item {
    id: root
    implicitWidth: iconText.implicitWidth + badge.width + 8
    implicitHeight: 24

    readonly property int count: NotificationService.history.length

    Row {
        anchors.centerIn: parent
        spacing: 4

        Text {
            id: iconText
            anchors.verticalCenter: parent.verticalCenter
            text: NotificationService.dnd ? "󰂛" : (root.count > 0 ? "󰂚" : "󰂜")
            color: NotificationService.dnd ? "#f38ba8" : (root.count > 0 ? "#f9e2af" : "#cdd6f4")
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 15
            Behavior on color { ColorAnimation { duration: 150 } }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: notificationCenter.visible = !notificationCenter.visible
            }
        }

        Rectangle {
            id: badge
            anchors.verticalCenter: parent.verticalCenter
            visible: root.count > 0 && !NotificationService.dnd
            width: Math.max(badgeText.implicitWidth + 6, 16)
            height: 16
            radius: 8
            color: "#f38ba8"

            Text {
                id: badgeText
                anchors.centerIn: parent
                text: root.count > 99 ? "99+" : root.count
                color: "#1e1e2e"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 10
                font.bold: true
            }
        }
    }
}
