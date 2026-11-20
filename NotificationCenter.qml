import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

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
    WlrLayershell.namespace: "quickshell-notification-center"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property color bgColor: "#1e1e2e"
    property color surfaceColor: "#313244"
    property color fgColor: "#cdd6f4"
    property color accentColor: "#89b4fa"

    MouseArea {
        anchors.fill: parent
        onClicked: root.visible = false
    }

    Rectangle {
        id: centerBox
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.rightMargin: root.visible ? 8 : -width - 20
        anchors.topMargin: 8
        anchors.bottomMargin: 8

        width: 360
        radius: 16
        color: root.bgColor
        border.color: root.surfaceColor
        border.width: 1

        Behavior on anchors.rightMargin {
            NumberAnimation {
                duration: 260
                easing.type: Easing.OutCubic
            }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "󰂚"
                    color: root.accentColor
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 16
                }

                Text {
                    Layout.fillWidth: true
                    text: "Уведомления"
                    color: root.fgColor
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 15
                    font.bold: true
                }

                Text {
                    text: NotificationService.dnd ? "DND: ON" : "DND: OFF"
                    color: NotificationService.dnd ? "#f38ba8" : "#a6adc8"
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
                    text: "󰅖"
                    color: clearArea.containsMouse ? "#f38ba8" : "#6c7086"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
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

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: root.surfaceColor
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
                    color: root.surfaceColor
                    border.color: modelData.urgency === 2 ? "#f38ba8" : "transparent"
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
                                color: root.accentColor
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Text {
                                text: "󰅖"
                                color: closeCenterArea.containsMouse ? "#f38ba8" : "#6c7086"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                Behavior on color { ColorAnimation { duration: 150 } }

                                MouseArea {
                                    id: closeCenterArea
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
                            color: root.fgColor
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: modelData.body !== ""
                            text: modelData.body
                            color: "#a6adc8"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }
                    }
                }

                // Если пусто
                Text {
                    anchors.centerIn: parent
                    visible: NotificationService.history.count === 0
                    text: "Нет уведомлений"
                    color: "#6c7086"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                }
            }
        }
    }
}
