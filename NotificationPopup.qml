import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    anchors {
        top: true
        right: true
    }
    color: "transparent"
    visible: false
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    implicitWidth: 380
    implicitHeight: popupColumn.implicitHeight + 16

    Connections {
        target: NotificationService.history
        function onCountChanged() {
            root.visible = NotificationService.history.count > 0
        }
    }

    Column {
        id: popupColumn
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 8
        anchors.rightMargin: 8
        spacing: 8

        Repeater {
            model: NotificationService.history

            delegate: Rectangle {
                required property var modelData
                required property int index

                width: 360
                height: contentLayout.implicitHeight + 24
                radius: 12
                color: Theme.bg
                border.color: modelData.urgency === 2 ? Theme.red : Theme.surface1
                border.width: modelData.urgency === 2 ? 2 : 1

                opacity: 0
                scale: 0.985
                property real slideOffset: 24
                Component.onCompleted: { opacity = 1; slideOffset = 0; scale = 1 }
                transform: Translate { x: slideOffset; Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } } }
                Behavior on opacity { NumberAnimation { duration: 200 } }
                Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                Behavior on border.color { ColorAnimation { duration: 180 } }

                Timer {
                    interval: 8000
                    running: modelData.urgency !== 2
                    repeat: false
                    onTriggered: NotificationService.dismiss(modelData.id)
                }

                ColumnLayout {
                    id: contentLayout
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6

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
                            text: modelData.appName
                            color: Theme.accent
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            text: "󰅖"
                            color: closeArea.containsMouse ? Theme.red : Theme.overlay
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                            Behavior on color { ColorAnimation { duration: 150 } }

                            MouseArea {
                                id: closeArea
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
                        font.pixelSize: 14
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: modelData.body !== ""
                        text: modelData.body
                        color: Theme.fgMuted
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: NotificationService.dismiss(modelData.id)
                }
            }
        }
    }
}
