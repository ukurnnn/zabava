import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Widgets

PanelWindow {
    id: root
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    visible: false
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-powermenu"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    IpcHandler {
        target: "powermenu"
        function toggle(): void { root.visible = !root.visible }
    }

    readonly property var actions: [
        { icon: "󰌾", label: "Lock", cmd: ["loginctl", "lock-session"], dangerous: false },
        { icon: "󰍃", label: "Logout", cmd: ["niri", "msg", "action", "quit", "-s"], dangerous: false },
        { icon: "󰒲", label: "Sleep", cmd: ["systemctl", "suspend"], dangerous: false },
        { icon: "󰜉", label: "Reboot", cmd: ["systemctl", "reboot"], dangerous: true },
        { icon: "󰐥", label: "Power Off", cmd: ["systemctl", "poweroff"], dangerous: true }
    ]

    CloseHandler {
        target: root
    }

    Rectangle {
        id: sideWall
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.rightMargin: root.visible ? 8 : -width - 20
        anchors.topMargin: 8
        anchors.bottomMargin: 8

        width: 380
        radius: 16
        color: Theme.bg
        border.color: Theme.surface1
        border.width: 1
        opacity: root.visible ? 1 : 0

        Behavior on anchors.rightMargin {
            NumberAnimation {
                duration: 280
                easing.type: Easing.OutCubic
            }
        }
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Behavior on border.color { ColorAnimation { duration: 180 } }

        MouseArea { anchors.fill: parent; onClicked: {} }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "󰒓"
                    color: Theme.accent
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 18
                }

                Text {
                    Layout.fillWidth: true
                    text: "Центр управления"
                    color: Theme.fg
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 16
                    font.bold: true
                }

                Text {
                    text: "󰅖"
                    color: closeArea.containsMouse ? Theme.red : Theme.overlay
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 16
                    Behavior on color { ColorAnimation { duration: 150 } }

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.visible = false
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.surface
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "󰂚"
                    color: Theme.accent
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                }

                Text {
                    Layout.fillWidth: true
                    text: "Уведомления"
                    color: Theme.fg
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    font.bold: true
                }

                Text {
                    text: NotificationService.dnd ? "DND: ON" : "DND: OFF"
                    color: NotificationService.dnd ? Theme.red : Theme.fgMuted
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NotificationService.toggleDnd()
                    }
                }

                Text {
                    text: "󰆴"
                    color: clearArea.containsMouse ? Theme.red : Theme.overlay
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    Behavior on color { ColorAnimation { duration: 150 } }

                    MouseArea {
                        id: clearArea
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NotificationService.dismissAll()
                    }
                }
            }

            ListView {
                id: notifList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 8
                model: NotificationService.history

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    width: notifList.width
                    height: contentCol.implicitHeight + 20
                    radius: 10
                    color: Theme.surface
                    border.color: modelData.urgency === 2 ? Theme.red : "transparent"
                    border.width: modelData.urgency === 2 ? 1 : 0

                    ColumnLayout {
                        id: contentCol
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                Layout.fillWidth: true
                                text: modelData.appName
                                color: Theme.accent
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Text {
                                text: "󰅖"
                                color: closeItemArea.containsMouse ? Theme.red : Theme.overlay
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                Behavior on color { ColorAnimation { duration: 150 } }

                                MouseArea {
                                    id: closeItemArea
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: NotificationService.dismiss(modelData.id)
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: modelData.summary !== ""
                            text: modelData.summary
                            color: Theme.fg
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: modelData.body !== ""
                            text: modelData.body
                            color: Theme.fgMuted
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: NotificationService.history.count === 0
                    text: "Нет уведомлений"
                    color: Theme.overlay
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.surface
            }

            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8

                Repeater {
                    model: root.actions

                    delegate: Rectangle {
                        required property var modelData

                        width: 60
                        height: 60
                        radius: 12
                        color: holdArea.containsMouse
                            ? (modelData.dangerous ? Theme.red : Theme.accent)
                            : Theme.surface

                        Behavior on color { ColorAnimation { duration: 150 } }

                        Column {
                            anchors.centerIn: parent
                            spacing: 2

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.icon
                                color: holdArea.containsMouse ? Theme.bg : Theme.fg
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 20
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.label
                                color: holdArea.containsMouse ? Theme.bg : Theme.fg
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 9
                            }
                        }

                        Rectangle {
                            id: holdFill
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: parent.width * holdArea.holdProgress
                            radius: 12
                            color: modelData.dangerous ? Theme.red : Theme.accent
                            opacity: holdArea.pressed ? 0.35 : 0.18
                            visible: modelData.dangerous
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 4
                            visible: modelData.dangerous && (holdArea.pressed || holdArea.holdProgress > 0)
                            text: holdArea.holdProgress >= 1 ? "✓" : "Удерж."
                            color: holdArea.containsMouse || holdArea.pressed ? Theme.bg : Theme.fgMuted
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 7
                            opacity: 0.9
                        }

                        MouseArea {
                            id: holdArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            property real holdProgress: 0
                            property bool triggered: false

                            NumberAnimation {
                                id: holdAnim
                                target: holdArea
                                property: "holdProgress"
                                from: holdArea.holdProgress
                                to: 1
                                duration: Math.max(120, Math.round(900 * (1 - holdArea.holdProgress)))
                                easing.type: Easing.Linear
                                onFinished: {
                                    if (holdArea.pressed && !holdArea.triggered && holdArea.holdProgress >= 0.999) {
                                        holdArea.triggered = true
                                        Quickshell.execDetached(modelData.cmd)
                                        root.visible = false
                                    }
                                }
                            }
                            NumberAnimation {
                                id: holdCancelAnim
                                target: holdArea
                                property: "holdProgress"
                                to: 0
                                duration: 180
                                easing.type: Easing.OutQuad
                            }

                            onPressed: {
                                triggered = false
                                if (modelData.dangerous) {
                                    holdCancelAnim.stop()
                                    holdAnim.from = holdProgress
                                    holdAnim.duration = Math.max(120, Math.round(900 * (1 - holdProgress)))
                                    holdAnim.start()
                                }
                            }
                            onReleased: {
                                if (!modelData.dangerous) {
                                    if (containsMouse && !triggered) {
                                        triggered = true
                                        Quickshell.execDetached(modelData.cmd)
                                        root.visible = false
                                    }
                                    holdProgress = 0
                                    return
                                }
                                if (!triggered) {
                                    holdAnim.stop()
                                    holdCancelAnim.start()
                                }
                            }
                            onCanceled: {
                                holdAnim.stop()
                                triggered = false
                                holdCancelAnim.start()
                            }
                        }
                    }
                }
            }
        }
    }
}
