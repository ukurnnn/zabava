import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

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
    WlrLayershell.namespace: "quickshell-thememenu"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property int focusIndex: 0

    IpcHandler {
        target: "thememenu"
        function toggle(): void { root.visible = !root.visible }
    }

    onVisibleChanged: {
        if (visible) {
            root.focusIndex = Theme.current === "mocha" ? 0 : 1
            keyHandler.forceActiveFocus()
        }
    }

    Item {
        id: keyHandler
        anchors.fill: parent
        focus: true

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                root.focusIndex = 0
                event.accepted = true
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                root.focusIndex = 1
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                Theme.setTheme(root.focusIndex === 0 ? "mocha" : "latte")
                root.visible = false
                event.accepted = true
            } else if (event.key === Qt.Key_Escape) {
                root.visible = false
                event.accepted = true
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.visible = false
    }

    Rectangle {
        id: menuBox
        anchors.centerIn: parent

        width: 360
        height: 200
        radius: 16
        color: Theme.glassPanel
        border.color: Theme.glassBorderStrong
        border.width: 1

        opacity: root.visible ? 1 : 0
        scale: root.visible ? 1.0 : 0.94

        Behavior on opacity { NumberAnimation { duration: 180 } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on border.color { ColorAnimation { duration: 180 } }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 1
            height: Math.max(0, parent.height * 0.3)
            radius: Math.max(0, parent.radius - 1)
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.glassHighlight }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "󰔎"
                    color: Theme.accent
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 18
                }

                Text {
                    Layout.fillWidth: true
                    text: "Тема оформления"
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
                Layout.fillHeight: true
                spacing: 12

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12
                    color: root.focusIndex === 0 ? Theme.accent : (Theme.current === "mocha" ? Theme.surface1 : Theme.surface)
                    border.color: root.focusIndex === 0 ? Theme.accent : (Theme.current === "mocha" ? Theme.accent : Theme.surface1)
                    border.width: 2

                    Behavior on color { ColorAnimation { duration: 150 } }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "󰖙"
                            color: root.focusIndex === 0 || Theme.current === "mocha" ? Theme.bg : Theme.fg
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 32
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Mocha"
                            color: root.focusIndex === 0 || Theme.current === "mocha" ? Theme.bg : Theme.fg
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                            font.bold: true
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Тёмная"
                            color: root.focusIndex === 0 || Theme.current === "mocha" ? Theme.bg : Theme.fgMuted
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Theme.setTheme("mocha")
                            root.visible = false
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12
                    color: root.focusIndex === 1 ? Theme.accent : (Theme.current === "latte" ? Theme.surface1 : Theme.surface)
                    border.color: root.focusIndex === 1 ? Theme.accent : (Theme.current === "latte" ? Theme.accent : Theme.surface1)
                    border.width: 2

                    Behavior on color { ColorAnimation { duration: 150 } }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "󰖚"
                            color: root.focusIndex === 1 || Theme.current === "latte" ? Theme.bg : Theme.fg
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 32
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Latte"
                            color: root.focusIndex === 1 || Theme.current === "latte" ? Theme.bg : Theme.fg
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                            font.bold: true
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Светлая"
                            color: root.focusIndex === 1 || Theme.current === "latte" ? Theme.bg : Theme.fgMuted
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Theme.setTheme("latte")
                            root.visible = false
                        }
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "← → выбрать · Enter применить · Esc закрыть"
                color: Theme.fgMuted
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 10
            }
        }
    }
}
