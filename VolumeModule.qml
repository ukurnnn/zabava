import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Item {
    id: root
    implicitWidth: contentRow.implicitWidth + 8
    implicitHeight: 24

    property var popup: null

    property var sink: Pipewire.defaultAudioSink
    property var sinkAudio: sink ? sink.audio : null

    property var source: Pipewire.defaultAudioSource
    property var sourceAudio: source ? source.audio : null

    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 10

        // МИКРОФОН
        Item {
            width: micText.implicitWidth + 4
            height: 24

            Text {
                id: micText
                anchors.centerIn: parent
                text: {
                    if (!root.sourceAudio) return "󰍬 ---"
                    if (root.sourceAudio.muted) return "󰍭 " + Math.round(root.sourceAudio.volume * 100) + "%"
                    if (root.sourceAudio.volume < 0.3) return "󰍬 " + Math.round(root.sourceAudio.volume * 100) + "%"
                    return "󰍮 " + Math.round(root.sourceAudio.volume * 100) + "%"
                }
                color: (micArea.containsMouse || (root.popup && root.popup.visible)) ? Theme.yellow : Theme.fg
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 15
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            MouseArea {
                id: micArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton || mouse.button === Qt.MiddleButton) {
                        if (root.sourceAudio) {
                            Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_SOURCE@", "toggle"])
                        }
                        return
                    }
                    if (root.popup) root.popup.visible = !root.popup.visible
                }

                onWheel: (wheel) => {
                    if (!root.sourceAudio) return
                    const step = 0.05
                    if (wheel.angleDelta.y > 0) {
                        root.sourceAudio.volume = Math.min(1.0, root.sourceAudio.volume + step)
                    } else {
                        root.sourceAudio.volume = Math.max(0.0, root.sourceAudio.volume - step)
                    }
                }
            }
        }

        // ЗВУК
        Item {
            width: volText.implicitWidth + 4
            height: 24

            Text {
                id: volText
                anchors.centerIn: parent
                text: {
                    if (!root.sinkAudio) return "󰕾 ---"
                    if (root.sinkAudio.muted) return "󰝟 " + Math.round(root.sinkAudio.volume * 100) + "%"
                    if (root.sinkAudio.volume < 0.3) return "󰕿 " + Math.round(root.sinkAudio.volume * 100) + "%"
                    if (root.sinkAudio.volume < 0.7) return "󰖀 " + Math.round(root.sinkAudio.volume * 100) + "%"
                    return "󰕾 " + Math.round(root.sinkAudio.volume * 100) + "%"
                }
                color: (volArea.containsMouse || (root.popup && root.popup.visible)) ? Theme.yellow : Theme.fg
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 15
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            MouseArea {
                id: volArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton || mouse.button === Qt.MiddleButton) {
                        if (root.sinkAudio) root.sinkAudio.muted = !root.sinkAudio.muted
                        return
                    }
                    if (root.popup) root.popup.visible = !root.popup.visible
                }

                onWheel: (wheel) => {
                    if (!root.sinkAudio) return
                    const step = 0.05
                    if (wheel.angleDelta.y > 0) {
                        root.sinkAudio.volume = Math.min(1.0, root.sinkAudio.volume + step)
                    } else {
                        root.sinkAudio.volume = Math.max(0.0, root.sinkAudio.volume - step)
                    }
                }
            }
        }
    }
}
