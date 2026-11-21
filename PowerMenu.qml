import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: root
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    visible: false
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-powermenu"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    IpcHandler { target: "powermenu"; function toggle(): void { root.visible = !root.visible } }

    readonly property var actions: [
        { icon: "󰌾", label: "Заблокировать", cmd: ["loginctl", "lock-session"], dangerous: false },
        { icon: "󰍃", label: "Выйти", cmd: ["niri", "msg", "action", "quit", "-s"], dangerous: true },
        { icon: "󰒲", label: "Сон", cmd: ["systemctl", "suspend"], dangerous: true },
        { icon: "󰜉", label: "Перезагрузка", cmd: ["systemctl", "reboot"], dangerous: true },
        { icon: "󰐥", label: "Выключение", cmd: ["systemctl", "poweroff"], dangerous: true }
    ]
    property int holdDuration: 900

    function runAction(cmd) { Quickshell.execDetached(cmd); root.visible = false }
    CloseHandler { target: root }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.18)
        opacity: root.visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160 } }
        MouseArea { anchors.fill: parent; onClicked: root.visible = false }
    }

    Rectangle {
        id: panel
        anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
        anchors.rightMargin: root.visible ? 10 : -width - 24
        anchors.topMargin: 10; anchors.bottomMargin: 10
        width: 340
        radius: 20
        color: Theme.glassPanel
        border.color: Theme.glassBorderStrong
        border.width: 1
        opacity: root.visible ? 1 : 0

        Behavior on anchors.rightMargin { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 160 } }

        Rectangle {
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            anchors.margins: 1; height: parent.height * 0.22; radius: Math.max(0, parent.radius - 1)
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.glassHighlight }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                Text { text: "󰐥"; color: Theme.accent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 20 }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 0
                    Text { text: "Питание"; color: Theme.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16; font.bold: true }
                    Text { text: "Профиль и действия системы"; color: Theme.fgMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10 }
                }
                Rectangle {
                    width: 28; height: 28; radius: 8
                    color: closeArea.containsMouse ? Theme.surface1 : "transparent"
                    Text { anchors.centerIn: parent; text: "󰅖"; color: closeArea.containsMouse ? Theme.red : Theme.fgMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14 }
                    MouseArea { id: closeArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.visible = false }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: ppCol.implicitHeight + 20
                radius: 14
                color: Theme.glassPanelSoft
                border.color: Theme.glassBorder; border.width: 1

                ColumnLayout {
                    id: ppCol
                    anchors.fill: parent; anchors.margins: 10; spacing: 8
                    Text { text: "Профиль питания"; color: Theme.fgMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true }
                    Text {
                        Layout.fillWidth: true
                        text: PowerProfileService.available ? PowerProfileService.statusMessage : PowerProfileService.statusMessage
                        color: Theme.fgMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9; wrapMode: Text.WordWrap
                    }
                    Row {
                        Layout.fillWidth: true; spacing: 8
                        visible: PowerProfileService.available
                        Repeater {
                            model: PowerProfileService.profiles || []
                            delegate: Rectangle {
                                required property var modelData
                                width: (ppCol.width - 16) / Math.max(1, (PowerProfileService.profiles || []).length)
                                height: 52; radius: 12
                                property bool active: PowerProfileService.current === modelData
                                color: active ? Theme.accent : (ppMouse.containsMouse ? Theme.surface1 : Theme.surface)
                                border.color: active ? Theme.accent : Theme.surface1; border.width: 1
                                opacity: PowerProfileService.busy ? 0.65 : 1
                                Column {
                                    anchors.centerIn: parent; spacing: 2
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: PowerProfileService.iconFor(modelData); color: active ? Theme.bg : Theme.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16 }
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: PowerProfileService.labelFor(modelData); color: active ? Theme.bg : Theme.fgMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9 }
                                }
                                MouseArea { id: ppMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: PowerProfileService.setProfile(modelData) }
                            }
                        }
                    }
                }
            }

            Text { text: "Действия"; color: Theme.fgMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true }

            ColumnLayout {
                Layout.fillWidth: true; spacing: 8
                Repeater {
                    model: root.actions
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true; height: 50; radius: 14
                        color: holdArea.containsMouse ? Qt.rgba(Theme.surface1.r, Theme.surface1.g, Theme.surface1.b, 0.95) : Theme.surface
                        border.color: modelData.dangerous ? Qt.rgba(Theme.orange.r, Theme.orange.g, Theme.orange.b, 0.35) : Theme.surface1
                        border.width: 1
                        clip: true

                        Rectangle {
                            anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                            width: parent.width * holdArea.holdProgress
                            radius: parent.radius
                            visible: modelData.dangerous
                            color: Qt.rgba(Theme.orange.r, Theme.orange.g, Theme.orange.b, 0.32)
                            Rectangle {
                                anchors.fill: parent; radius: parent.radius
                                color: "transparent"
                                border.color: Qt.rgba(Theme.yellow.r, Theme.yellow.g, Theme.yellow.b, 0.35)
                                border.width: 1
                                opacity: holdArea.holdProgress > 0 ? 1 : 0
                            }
                        }

                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; spacing: 10
                            Rectangle {
                                width: 30; height: 30; radius: 9
                                color: modelData.dangerous ? Qt.rgba(Theme.red.r, Theme.red.g, Theme.red.b, 0.14) : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14)
                                Text { anchors.centerIn: parent; text: modelData.icon; color: modelData.dangerous ? Theme.red : Theme.accent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15 }
                            }
                            Text { Layout.fillWidth: true; text: modelData.label; color: Theme.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.bold: true }
                            Text {
                                visible: modelData.dangerous
                                text: holdArea.pressed ? Math.round(holdArea.holdProgress * 100) + "%" : "Удержать"
                                color: holdArea.pressed ? Theme.yellow : Theme.fgMuted
                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10
                            }
                        }

                        MouseArea {
                            id: holdArea
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            property real holdProgress: 0
                            property bool fired: false
                            onPressed: { fired = false; holdProgress = 0; if (modelData.dangerous) holdTimer.restart() }
                            onReleased: {
                                if (modelData.dangerous) { holdTimer.stop(); holdProgress = 0; return }
                                if (!fired) { fired = true; root.runAction(modelData.cmd) }
                            }
                            onCanceled: { holdTimer.stop(); holdProgress = 0; fired = false }
                            Timer {
                                id: holdTimer; interval: 16; repeat: true
                                onTriggered: {
                                    if (!holdArea.pressed) { stop(); holdArea.holdProgress = 0; return }
                                    holdArea.holdProgress = Math.min(1, holdArea.holdProgress + (16 / root.holdDuration))
                                    if (holdArea.holdProgress >= 1 && !holdArea.fired) {
                                        holdArea.fired = true; stop(); root.runAction(modelData.cmd); holdArea.holdProgress = 0
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
