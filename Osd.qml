import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    anchors { bottom: true; left: true; right: true }
    implicitHeight: 120
    color: "transparent"
    visible: showing
    exclusiveZone: 0
    mask: Region { item: pill }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    property bool showing: false
    property string icon: ""
    property string label: ""
    property real value: -1
    property real maxValue: 100
    property bool muted: false

    function showOsd(opts) {
        if (!opts) return
        root.icon = opts.icon || ""
        root.label = opts.label || ""
        root.value = (opts.value !== undefined) ? Number(opts.value) : -1
        root.maxValue = (opts.maxValue !== undefined) ? Number(opts.maxValue) : 100
        root.muted = opts.muted === true
        root.showing = true
        hideTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: 1600
        repeat: false
        onTriggered: root.showing = false
    }

    Rectangle {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.showing ? 60 : 30
        width: Math.max(240, content.implicitWidth + 32)
        height: content.implicitHeight + 20
        radius: 16
        color: Theme.glassPanelStrong
        border.color: Theme.glassBorderStrong
        border.width: 1
        opacity: root.showing ? 1 : 0
        scale: root.showing ? 1 : 0.96

        Behavior on anchors.bottomMargin { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on border.color { ColorAnimation { duration: 180 } }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 1
            height: Math.max(0, parent.height * 0.5)
            radius: Math.max(0, parent.radius - 1)
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.glassHighlight }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        ColumnLayout {
            id: content
            anchors.centerIn: parent
            width: Math.max(200, implicitWidth)
            spacing: 8

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 10

                Text {
                    text: root.icon
                    color: root.muted ? Theme.red : Theme.accent
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 18
                }

                Text {
                    text: root.label
                    color: Theme.fg
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.maximumWidth: 260
                }
            }

            Rectangle {
                visible: root.value >= 0
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 220
                Layout.preferredHeight: 6
                radius: 3
                color: Theme.surface1

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height
                    radius: 3
                    width: parent.width * Math.max(0, Math.min(1, root.maxValue > 0 ? root.value / root.maxValue : 0))
                    color: root.muted ? Theme.red : Theme.accent
                    Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }
        }
    }
}
