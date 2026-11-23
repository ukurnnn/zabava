//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "."

ShellRoot {
    id: rootShell

    NotificationServer {
        id: notifServer
        keepOnReload: true

        onNotification: (notif) => {
            NotificationService.addNotification(notif)
            notif.tracked = true
        }
    }

    property bool _brightnessOsdReady: false

    PanelWindow {
        id: mainPanel
        anchors {
            top: true
            left: true
            right: true
        }
        implicitHeight: BarConfig.style === "full" ? 44 : 52
        color: "transparent"
        exclusiveZone: BarConfig.style === "full" ? 40 : 48

        property var moduleItems: ({
            workspaces: wsIsland,
            mpris: mprisIsland,
            clock: centerIsland,
            volume: volIsland,
            sysmon: sysIsland,
            layout: layoutIsland,
            network: netIsland,
            tray: trayIsland,
            power: powerIsland
        })

        function applyBarLayout() {
            var style = BarConfig.style
            var edgeMargin = (style === "full") ? 4 : 8
            var gap = (style === "islands") ? 6 : 0
            var topMargin = (style === "full") ? 4 : 6

            function applySection(section, side) {
                var order = BarConfig.visibleOrder(section) || []
                var allIds = (BarConfig.defaultModuleOrder[section] || []).slice()
                for (var h = 0; h < allIds.length; h++) {
                    var hid = allIds[h]
                    if (moduleItems[hid]) moduleItems[hid].visible = false
                }
                var prev = null
                for (var i = 0; i < order.length; i++) {
                    var id = order[i]
                    var item = moduleItems[id]
                    if (!item) continue
                    item.visible = true
                    item.anchors.topMargin = topMargin
                    if (side === "left") {
                        item.anchors.right = undefined
                        item.anchors.horizontalCenter = undefined
                        if (prev === null) {
                            item.anchors.left = mainPanel.contentItem.left
                            item.anchors.leftMargin = edgeMargin
                        } else {
                            item.anchors.left = prev.right
                            item.anchors.leftMargin = gap
                        }
                    } else if (side === "right") {
                        item.anchors.left = undefined
                        item.anchors.horizontalCenter = undefined
                        if (prev === null) {
                            item.anchors.right = mainPanel.contentItem.right
                            item.anchors.rightMargin = edgeMargin
                        } else {
                            item.anchors.right = prev.left
                            item.anchors.rightMargin = gap
                        }
                    } else if (side === "center") {
                        item.anchors.left = undefined
                        item.anchors.right = undefined
                        item.anchors.leftMargin = 0
                        item.anchors.rightMargin = 0
                        item.anchors.horizontalCenter = mainPanel.contentItem.horizontalCenter
                    }
                    prev = item
                }
            }

            applySection("left", "left")
            applySection("right", "right")
            applySection("center", "center")
        }

        Component.onCompleted: Qt.callLater(applyBarLayout)
        Connections {
            target: BarConfig
            function onStyleChanged() { mainPanel.applyBarLayout() }
            function onModuleOrderChanged() { mainPanel.applyBarLayout() }
            function onHiddenModulesChanged() { mainPanel.applyBarLayout() }
        }

        Behavior on implicitHeight { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

        Rectangle {
            id: monoBarBg
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: BarConfig.style === "full" ? 0 : 8
            anchors.rightMargin: BarConfig.style === "full" ? 0 : 8
            anchors.topMargin: BarConfig.style === "full" ? 0 : 6
            height: BarConfig.style === "full" ? mainPanel.implicitHeight : 40
            radius: BarConfig.style === "full" ? 0 : 20
            color: Theme.glassPanel
            border.color: Theme.glassBorder
            border.width: BarConfig.style === "full" ? 0 : 1
            opacity: BarConfig.style !== "islands" ? 1 : 0
            visible: opacity > 0
            z: -1

            Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
            Behavior on anchors.leftMargin { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
            Behavior on anchors.rightMargin { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
            Behavior on anchors.topMargin { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
            Behavior on radius { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.InOutQuad } }
            // color/border animations removed to avoid glass-mode flicker

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 1
                height: Math.max(0, parent.height * 0.45)
                radius: Math.max(0, parent.radius - 1)
                visible: BarConfig.style !== "full"
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.glassHighlight }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
        }

        Rectangle {
            id: wsIsland
            property string moduleId: "workspaces"
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: BarConfig.style === "full" ? 4 : 8
            anchors.topMargin: BarConfig.style === "full" ? 4 : 6
            height: BarConfig.style === "full" ? 36 : 40
            width: wsRow.implicitWidth + (BarConfig.style === "full" ? 32 : 20)
            radius: BarConfig.style === "full" ? 14 : 20
            color: BarConfig.style === "islands" ? Theme.glassIsland : "transparent"
            border.color: BarConfig.style === "islands" ? Theme.glassBorder : "transparent"
            border.width: BarConfig.style === "islands" ? 1 : 0
            Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on anchors.leftMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on anchors.rightMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on anchors.topMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            // color/border animations removed to avoid glass-mode flicker
            Behavior on radius { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: Math.max(0, parent.radius - 1)
                visible: BarConfig.style === "islands"
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.glassHighlight }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            Row {
                id: wsRow
                anchors.centerIn: parent
                spacing: 6

                Repeater {
                    model: NiriService.allWorkspaces

                    delegate: Rectangle {
                        id: wsDot
                        required property var modelData
                        required property int index

                        width: 28
                        height: 28
                        radius: 14
                        color: modelData.is_active ? Theme.accent : Theme.surface

                        Text {
                            anchors.centerIn: parent
                            text: wsDot.modelData.idx
                            color: wsDot.modelData.is_active ? Theme.bg : Theme.fg
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NiriService.focusWorkspace(wsDot.modelData.idx)
                        }
                    }
                }
            }
        }

        Rectangle {
            id: mprisIsland
            property string moduleId: "mpris"
            anchors.left: wsIsland.right
            anchors.top: parent.top
            anchors.leftMargin: BarConfig.style === "islands" ? 6 : 0
            anchors.topMargin: BarConfig.style === "full" ? 4 : 6
            height: BarConfig.style === "full" ? 36 : 40
            width: mprisContent.implicitWidth + 28 + (cavaRow.active ? cavaRow.implicitWidth + 10 : 0)
            radius: BarConfig.style === "full" ? 14 : 20
            color: BarConfig.style === "islands" ? Theme.glassIsland : "transparent"
            border.color: "transparent"
            border.width: 0
            Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on anchors.leftMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on anchors.rightMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on anchors.topMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            // color/border animations removed to avoid glass-mode flicker
            Behavior on radius { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: Math.max(0, parent.radius - 1)
                visible: BarConfig.style === "islands"
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.mediaAccentActive ? Qt.rgba(Theme.mediaAccent.r, Theme.mediaAccent.g, Theme.mediaAccent.b, Math.min(0.5, Theme.glassHighlight.a + 0.12)) : Theme.glassHighlight }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            Row {
                anchors.centerIn: parent
                spacing: 10

                MprisModule {
                    id: mprisContent
                    anchors.verticalCenter: parent.verticalCenter
                }

                CavaModule {
                    id: cavaRow
                    anchors.verticalCenter: parent.verticalCenter
                    active: mprisContent.player !== null && mprisContent.player.isPlaying === true
                }
            }
        }

        // ===== ЦЕНТР: Один островок =====
        Rectangle {
            id: centerIsland
            property string moduleId: "clock"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: BarConfig.style === "full" ? 4 : 6
            height: BarConfig.style === "full" ? 36 : 40
            width: centerRow.implicitWidth + 24
            radius: BarConfig.style === "full" ? 14 : 20
            color: BarConfig.style === "islands" ? Theme.glassIsland : "transparent"
            border.color: "transparent"
            border.width: 0
            Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on anchors.leftMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on anchors.rightMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on anchors.topMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            // color/border animations removed to avoid glass-mode flicker
            Behavior on radius { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: Math.max(0, parent.radius - 1)
                visible: BarConfig.style === "islands"
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.glassHighlight }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            Column {
                id: centerRow
                anchors.centerIn: parent
                spacing: 0

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8

                    CaffeineModule {
                        id: caffeineModule
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    SystemClock {
                        id: clock
                        precision: SystemClock.Seconds
                    }

                    Text {
                        id: clockText
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰥔 " + (clock.precision === SystemClock.Seconds
                              ? Qt.formatDateTime(clock.date, "HH:mm:ss")
                              : Qt.formatDateTime(clock.date, "HH:mm"))
                        color: clockMouse.containsMouse ? Theme.yellow : Theme.fg
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 15

                        Behavior on color { ColorAnimation { duration: 150 } }

                        MouseArea {
                            id: clockMouse
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.LeftButton) {
                                    calendarPopup.visible = !calendarPopup.visible
                                } else if (mouse.button === Qt.RightButton) {
                                    clock.precision = clock.precision === SystemClock.Seconds
                                                      ? SystemClock.Minutes
                                                      : SystemClock.Seconds
                                }
                            }
                        }
                    }

                    WeatherModule {
                        id: weatherModule
                        anchors.verticalCenter: parent.verticalCenter
                        popup: weatherPopup
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(new Date(), "ddd, d MMM")
                    color: Theme.fgMuted
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 9
                }
            }
        }

        // ===== ПРАВЫЕ ОСТРОВКИ =====

        Rectangle {
            id: powerIsland
            property string moduleId: "power"
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: BarConfig.style === "full" ? 4 : 8
            anchors.topMargin: BarConfig.style === "full" ? 4 : 6
            height: BarConfig.style === "full" ? 36 : 40
            width: powerRow.implicitWidth + (BarConfig.style === "full" ? 32 : 20)
            radius: BarConfig.style === "full" ? 14 : 20
            color: BarConfig.style === "islands" ? Theme.glassIsland : "transparent"
            border.color: BarConfig.style === "islands" ? Theme.glassBorder : "transparent"
            border.width: BarConfig.style === "islands" ? 1 : 0
            Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on anchors.leftMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on anchors.rightMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on anchors.topMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            // color/border animations removed to avoid glass-mode flicker
            Behavior on radius { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: Math.max(0, parent.radius - 1)
                visible: BarConfig.style === "islands"
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.glassHighlight }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            PowerButton {
                id: powerRow
                anchors.centerIn: parent
                target: powerMenu
            }
        }

        Rectangle {
            id: trayIsland
            property string moduleId: "tray"
            anchors.right: powerIsland.left
            anchors.top: parent.top
            anchors.rightMargin: BarConfig.style === "islands" ? 6 : 0
            anchors.topMargin: BarConfig.style === "full" ? 4 : 6
            height: BarConfig.style === "full" ? 36 : 40
            width: trayRow.implicitWidth + 20
            radius: BarConfig.style === "full" ? 14 : 20
            color: BarConfig.style === "islands" ? Theme.glassIsland : "transparent"
            border.color: BarConfig.style === "islands" ? Theme.glassBorder : "transparent"
            border.width: BarConfig.style === "islands" ? 1 : 0
            Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on anchors.leftMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on anchors.rightMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on anchors.topMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            // color/border animations removed to avoid glass-mode flicker
            Behavior on radius { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: Math.max(0, parent.radius - 1)
                visible: BarConfig.style === "islands"
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.glassHighlight }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            TrayModule {
                id: trayRow
                anchors.centerIn: parent
                panelWindow: mainPanel
            }
        }

        Rectangle {
            id: netIsland
            property string moduleId: "network"
            anchors.right: trayIsland.left
            anchors.top: parent.top
            anchors.rightMargin: BarConfig.style === "islands" ? 6 : 0
            anchors.topMargin: BarConfig.style === "full" ? 4 : 6
            height: BarConfig.style === "full" ? 36 : 40
            width: netRow.implicitWidth + 20
            radius: BarConfig.style === "full" ? 14 : 20
            color: BarConfig.style === "islands" ? Theme.glassIsland : "transparent"
            border.color: BarConfig.style === "islands" ? Theme.glassBorder : "transparent"
            border.width: BarConfig.style === "islands" ? 1 : 0
            Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on anchors.leftMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on anchors.rightMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on anchors.topMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            // color/border animations removed to avoid glass-mode flicker
            Behavior on radius { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: Math.max(0, parent.radius - 1)
                visible: BarConfig.style === "islands"
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.glassHighlight }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            NetworkModule {
                id: netRow
                anchors.centerIn: parent
                popup: networkPopup
            }
        }

        Rectangle {
            id: layoutIsland
            property string moduleId: "layout"
            anchors.right: netIsland.left
            anchors.top: parent.top
            anchors.rightMargin: BarConfig.style === "islands" ? 6 : 0
            anchors.topMargin: BarConfig.style === "full" ? 4 : 6
            height: BarConfig.style === "full" ? 36 : 40
            width: layoutRow.implicitWidth + 20
            radius: BarConfig.style === "full" ? 14 : 20
            color: BarConfig.style === "islands" ? Theme.glassIsland : "transparent"
            border.color: BarConfig.style === "islands" ? Theme.glassBorder : "transparent"
            border.width: BarConfig.style === "islands" ? 1 : 0
            Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on anchors.leftMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on anchors.rightMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on anchors.topMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            // color/border animations removed to avoid glass-mode flicker
            Behavior on radius { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: Math.max(0, parent.radius - 1)
                visible: BarConfig.style === "islands"
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.glassHighlight }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            LayoutModule {
                id: layoutRow
                anchors.centerIn: parent
            }
        }

        Rectangle {
            id: sysIsland
            property string moduleId: "sysmon"
            anchors.right: layoutIsland.left
            anchors.top: parent.top
            anchors.rightMargin: BarConfig.style === "islands" ? 6 : 0
            anchors.topMargin: BarConfig.style === "full" ? 4 : 6
            height: BarConfig.style === "full" ? 36 : 40
            width: sysRow.implicitWidth + 20
            radius: BarConfig.style === "full" ? 14 : 20
            color: BarConfig.style === "islands" ? Theme.glassIsland : "transparent"
            border.color: BarConfig.style === "islands" ? Theme.glassBorder : "transparent"
            border.width: BarConfig.style === "islands" ? 1 : 0
            Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on anchors.leftMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on anchors.rightMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on anchors.topMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            // color/border animations removed to avoid glass-mode flicker
            Behavior on radius { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: Math.max(0, parent.radius - 1)
                visible: BarConfig.style === "islands"
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.glassHighlight }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            SystemMonitorModule {
                id: sysRow
                anchors.centerIn: parent
            }
        }

        Rectangle {
            id: volIsland
            property string moduleId: "volume"
            anchors.right: sysIsland.left
            anchors.top: parent.top
            anchors.rightMargin: BarConfig.style === "islands" ? 6 : 0
            anchors.topMargin: BarConfig.style === "full" ? 4 : 6
            height: BarConfig.style === "full" ? 36 : 40
            width: volRow.implicitWidth + 20
            radius: BarConfig.style === "full" ? 14 : 20
            color: BarConfig.style === "islands" ? Theme.glassIsland : "transparent"
            border.color: BarConfig.style === "islands" ? Theme.glassBorder : "transparent"
            border.width: BarConfig.style === "islands" ? 1 : 0
            Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on anchors.leftMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on anchors.rightMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on anchors.topMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            // color/border animations removed to avoid glass-mode flicker
            Behavior on radius { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: Math.max(0, parent.radius - 1)
                visible: BarConfig.style === "islands"
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.glassHighlight }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            VolumeModule {
                id: volRow
                anchors.centerIn: parent
                popup: audioPopup
                osd: osd
            }
        }
    }

    AppLauncher {
        id: appLauncher
    }

    PowerMenu {
        id: powerMenu
    }

    CalendarPopup {
        id: calendarPopup
    }

    WeatherPopup {
        id: weatherPopup
        weatherModule: weatherModule
    }

    NotificationPopup {
        id: notificationPopup
    }

    ClipboardMenu {
        id: clipboardMenu
    }

    ThemeMenu {
        id: themeMenu
    }

    PlayerPopup {
        id: playerPopup
        anchorItem: mprisContent
    }

    AudioPopup {
        id: audioPopup
        panelWindow: mainPanel
        anchorItem: volRow
        osd: osd
    }

    NetworkPopup {
        id: networkPopup
        panelWindow: mainPanel
        anchorItem: netRow
    }

    ControlCenter {
        id: controlCenter
        panelWindow: mainPanel
        appLauncher: appLauncher
        clipboardMenu: clipboardMenu
        calendarPopup: calendarPopup
        weatherPopup: weatherPopup
        themeMenu: themeMenu
        powerMenu: powerMenu
        audioPopup: audioPopup
        networkPopup: networkPopup
        playerPopup: playerPopup
        caffeineModule: caffeineModule
        networkModule: netRow
        weatherModule: weatherModule
        osd: osd
    }

    Osd {
        id: osd
    }

    Connections {
        target: BrightnessService
        function onPercentChanged() {
            if (!BrightnessService.available) return
            if (!rootShell._brightnessOsdReady) {
                rootShell._brightnessOsdReady = true
                return
            }
            osd.showOsd({
                icon: BrightnessService.percent >= 67 ? "󰃠" : (BrightnessService.percent >= 34 ? "󰃟" : "󰃞"),
                label: "Яркость: " + BrightnessService.percent + "%",
                value: BrightnessService.percent
            })
        }
    }

    Connections {
        target: NiriService
        function onKeyboardLayoutIdxChanged() {
            osd.showOsd({
                icon: "󰌌",
                label: "Раскладка: " + (NiriService.keyboardLayoutIdx === 0 ? "EN" : "RU"),
                value: -1
            })
        }
    }
}
