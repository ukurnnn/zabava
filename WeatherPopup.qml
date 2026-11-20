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
    WlrLayershell.namespace: "quickshell-weather"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property var weatherModule: null

    IpcHandler {
        target: "weather"
        function toggle(): void { root.visible = !root.visible }
    }

    function weatherIcon(cond) {
        if (weatherModule && typeof weatherModule.weatherIcon === "function")
            return weatherModule.weatherIcon(cond)
        var c = (cond || "").toLowerCase()
        if (c.indexOf("thunder") !== -1 || c.indexOf("storm") !== -1) return "󰙾"
        if (c.indexOf("snow") !== -1 || c.indexOf("sleet") !== -1) return "󰖘"
        if (c.indexOf("rain") !== -1 || c.indexOf("drizzle") !== -1 || c.indexOf("shower") !== -1) return "󰖗"
        if (c.indexOf("fog") !== -1 || c.indexOf("mist") !== -1 || c.indexOf("haze") !== -1) return "󰖑"
        if (c.indexOf("partly") !== -1) return "󰖕"
        if (c.indexOf("cloud") !== -1 || c.indexOf("overcast") !== -1) return "󰖐"
        if (c.indexOf("sun") !== -1 || c.indexOf("clear") !== -1) return "󰖙"
        return "󰖐"
    }

    function updatedText() {
        if (!weatherModule || !weatherModule.lastUpdated) return "нет данных"
        return Qt.formatDateTime(new Date(weatherModule.lastUpdated), "HH:mm")
    }

    function infoValue(v) {
        return v && v !== "" ? v : "—"
    }

    onVisibleChanged: {
        if (visible && weatherModule) {
            if (!weatherModule.lastUpdated || (Date.now() - weatherModule.lastUpdated > 10 * 60 * 1000))
                weatherModule.refresh()
        }
    }

    CloseHandler { target: root }

    Rectangle {
        id: popupBox
        anchors.horizontalCenter: parent.horizontalCenter
        width: 360
        radius: 16
        color: Theme.glassPanel
        border.color: Theme.glassBorderStrong
        border.width: 1
        opacity: root.visible ? 1 : 0
        scale: root.visible ? 1 : 0.97
        transformOrigin: Item.Top
        implicitHeight: contentCol.implicitHeight + 32

        y: root.visible ? 38 : -implicitHeight - 20

        Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on border.color { ColorAnimation { duration: 180 } }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 1
            height: Math.max(0, parent.height * 0.22)
            radius: Math.max(0, parent.radius - 1)
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.glassHighlight }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        ColumnLayout {
            id: contentCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 16
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "󰖐"
                    color: Theme.accent
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 16
                }

                Text {
                    Layout.fillWidth: true
                    text: "Погода"
                    color: Theme.fg
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 15
                    font.bold: true
                    elide: Text.ElideRight
                }

                Rectangle {
                    width: 28; height: 28; radius: 8
                    color: refreshArea.containsMouse ? Theme.surface : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Text {
                        anchors.centerIn: parent
                        text: (weatherModule && weatherModule.loading) ? "󰑓" : "󰑐"
                        color: refreshArea.containsMouse ? Theme.accent : Theme.fgMuted
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
                    }
                    MouseArea {
                        id: refreshArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { if (weatherModule) weatherModule.refresh() }
                    }
                }

                Rectangle {
                    width: 28; height: 28; radius: 8
                    color: closeArea.containsMouse ? Theme.surface : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        color: closeArea.containsMouse ? Theme.red : Theme.fgMuted
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
                    }
                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.visible = false
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                radius: 14
                color: Theme.surface
                implicitHeight: mainInfo.implicitHeight + 24

                RowLayout {
                    id: mainInfo
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 12
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 64
                        Layout.preferredHeight: 64
                        radius: 16
                        color: Theme.surface1

                        Text {
                            anchors.centerIn: parent
                            text: root.weatherIcon(weatherModule ? weatherModule.condition : "")
                            color: Theme.accent
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 30
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: weatherModule ? infoValue(weatherModule.weatherText) : "--"
                            color: Theme.fg
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 28
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: weatherModule && weatherModule.condition !== "" ? weatherModule.condition : "Нет данных о погоде"
                            color: Theme.fgMuted
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            elide: Text.ElideRight
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                        }
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 8
                rowSpacing: 8

                Repeater {
                    model: [
                        { icon: "󰖐", label: "Ощущается", value: weatherModule ? root.infoValue(weatherModule.feelsLike) : "—" },
                        { icon: "󰖌", label: "Влажность", value: weatherModule ? root.infoValue(weatherModule.humidity) : "—" },
                        { icon: "󰖝", label: "Ветер", value: weatherModule ? root.infoValue(weatherModule.wind) : "—" },
                        { icon: "󰍎", label: "Место", value: weatherModule ? root.infoValue(weatherModule.location) : "—" }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 58
                        radius: 12
                        color: Theme.surface
                        border.color: Theme.surface1
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            Text {
                                text: modelData.icon
                                color: Theme.accent
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 15
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    text: modelData.label
                                    color: Theme.fgMuted
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 10
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.value
                                    color: Theme.fg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: weatherModule && weatherModule.loading ? "Обновление..." : ("Обновлено: " + root.updatedText())
                    color: Theme.fgMuted
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }

                Text {
                    visible: weatherModule && weatherModule.city !== ""
                    text: weatherModule ? weatherModule.city : ""
                    color: Theme.overlay
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }
        }
    }
}
