import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    anchors { top: true; right: true }
    color: "transparent"
    visible: NotificationService.popups.length > 0
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    implicitWidth: 390
    implicitHeight: Math.min(popupColumn.implicitHeight + 16, 520)

    Timer {
        interval: 1000
        running: NotificationService.popups.length > 0
        repeat: true
        onTriggered: NotificationService.expirePopups()
    }

    Column {
        id: popupColumn
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 8
        anchors.rightMargin: 8
        spacing: 8
        width: 374

        Repeater {
            model: NotificationService.popups.slice(0, 5)
            delegate: Rectangle {
                required property var modelData
                property int notifId: modelData.id
                width: 374
                radius: 12
                color: Theme.glassPanelStrong
                border.color: modelData.urgency === 2 ? Theme.red : Theme.glassBorder
                border.width: 1
                implicitHeight: contentLayout.implicitHeight + 20

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    onEntered: modelData.expiresAt = Date.now() + 60000
                    onExited: modelData.expiresAt = Date.now() + NotificationService.timeoutFor(modelData.urgency)
                }

                ColumnLayout {
                    id: contentLayout
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Text {
                            Layout.fillWidth: true
                            text: (modelData.appName || "App") + ((modelData.count || 1) > 1 ? " • " + modelData.count : "")
                            color: Theme.accent
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; font.bold: true
                            elide: Text.ElideRight
                        }
                        Text {
                            text: "очистить"
                            color: clearAppArea.containsMouse ? Theme.red : Theme.fgMuted
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9
                            MouseArea { id: clearAppArea; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: NotificationService.dismissApp(modelData.appName) }
                        }
                        Text {
                            text: "󰅖"
                            color: closeArea.containsMouse ? Theme.red : Theme.overlay
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11
                            MouseArea { id: closeArea; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: NotificationService.dismiss(notifId) }
                        }
                    }

                    Text { Layout.fillWidth: true; visible: (modelData.summary || "") !== ""; text: modelData.summary || ""; color: Theme.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight }
                    Text { Layout.fillWidth: true; visible: (modelData.body || "") !== ""; text: modelData.body || ""; color: Theme.fgMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; wrapMode: Text.WordWrap; maximumLineCount: 3; elide: Text.ElideRight }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        visible: (modelData.actions || []).length > 0
                        Repeater {
                            model: modelData.actions || []
                            delegate: Rectangle {
                                required property var modelData
                                radius: 8; height: 24; width: actionText.implicitWidth + 14
                                color: actionArea.containsMouse ? Theme.accent : Theme.surface1
                                border.color: Theme.glassBorder; border.width: 1
                                Text { id: actionText; anchors.centerIn: parent; text: modelData.text || modelData.identifier || "Action"; color: actionArea.containsMouse ? Theme.bg : Theme.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9 }
                                MouseArea {
                                    id: actionArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: NotificationService.invokeAction(notifId, modelData.identifier)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
