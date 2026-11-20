//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "."

ShellRoot {
    NotificationServer {
        id: notifServer
        keepOnReload: true

        onNotification: (notif) => {
            NotificationService.addNotification(notif)
            notif.tracked = true
        }
    }

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
            color: Theme.bg
            opacity: BarConfig.style !== "islands" ? 1 : 0
            visible: opacity > 0
            z: -1

            Behavior on anchors.leftMargin { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
            Behavior on anchors.rightMargin { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
            Behavior on anchors.topMargin { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
            Behavior on radius { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.InOutQuad } }
        }

        Rectangle {
            id: wsIsland
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: BarConfig.style === "full" ? 4 : 8
            anchors.topMargin: BarConfig.style === "full" ? 4 : 6
            height: BarConfig.style === "full" ? 36 : 40
            width: wsRow.implicitWidth + (BarConfig.style === "full" ? 32 : 20)
            radius: BarConfig.style === "full" ? 14 : 20
            color: BarConfig.style === "islands" ? Theme.bg : "transparent"
            Behavior on anchors.leftMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on anchors.rightMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on anchors.topMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 220 } }
            Behavior on radius { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

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
            anchors.left: wsIsland.right
            anchors.top: parent.top
            anchors.leftMargin: BarConfig.style === "islands" ? 6 : 0
            anchors.topMargin: BarConfig.style === "full" ? 4 : 6
            height: BarConfig.style === "full" ? 36 : 40
            width: mprisContent.implicitWidth + 28 + (cavaRow.active ? cavaRow.implicitWidth + 10 : 0)
            radius: BarConfig.style === "full" ? 14 : 20
            color: BarConfig.style === "islands" ? Theme.bg : "transparent"
            Behavior on anchors.leftMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on anchors.rightMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on anchors.topMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 220 } }
            Behavior on radius { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

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
                    // cava работает только когда трек реально играет
                    active: mprisContent.player !== null && mprisContent.player.isPlaying === true
                }
            }
        }

        // ===== ЦЕНТР: Один островок =====
        Rectangle {
            id: centerIsland
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: BarConfig.style === "full" ? 4 : 6
            height: BarConfig.style === "full" ? 36 : 40
            width: centerRow.implicitWidth + 24
            radius: BarConfig.style === "full" ? 14 : 20
            color: BarConfig.style === "islands" ? Theme.bg : "transparent"
            Behavior on anchors.leftMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on anchors.rightMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on anchors.topMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 220 } }
            Behavior on radius { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

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
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: BarConfig.style === "full" ? 4 : 8
            anchors.topMargin: BarConfig.style === "full" ? 4 : 6
            height: BarConfig.style === "full" ? 36 : 40
            width: powerRow.implicitWidth + (BarConfig.style === "full" ? 32 : 20)
            radius: BarConfig.style === "full" ? 14 : 20
            color: BarConfig.style === "islands" ? Theme.bg : "transparent"
            Behavior on anchors.leftMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on anchors.rightMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on anchors.topMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 220 } }
            Behavior on radius { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

            PowerButton {
                id: powerRow
                anchors.centerIn: parent
                target: powerMenu
            }
        }

        Rectangle {
            id: trayIsland
            anchors.right: powerIsland.left
            anchors.top: parent.top
            anchors.rightMargin: BarConfig.style === "islands" ? 6 : 0
            anchors.topMargin: BarConfig.style === "full" ? 4 : 6
            height: BarConfig.style === "full" ? 36 : 40
            width: trayRow.implicitWidth + 20
            radius: BarConfig.style === "full" ? 14 : 20
            color: BarConfig.style === "islands" ? Theme.bg : "transparent"
            Behavior on anchors.leftMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on anchors.rightMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on anchors.topMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 220 } }
            Behavior on radius { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

            TrayModule {
                id: trayRow
                anchors.centerIn: parent
                panelWindow: mainPanel
            }
        }

        Rectangle {
            id: netIsland
            anchors.right: trayIsland.left
            anchors.top: parent.top
            anchors.rightMargin: BarConfig.style === "islands" ? 6 : 0
            anchors.topMargin: BarConfig.style === "full" ? 4 : 6
            height: BarConfig.style === "full" ? 36 : 40
            width: netRow.implicitWidth + 20
            radius: BarConfig.style === "full" ? 14 : 20
            color: BarConfig.style === "islands" ? Theme.bg : "transparent"
            Behavior on anchors.leftMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on anchors.rightMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on anchors.topMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 220 } }
            Behavior on radius { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

            NetworkModule {
                id: netRow
                anchors.centerIn: parent
                popup: networkPopup
            }
        }

        Rectangle {
            id: layoutIsland
            anchors.right: netIsland.left
            anchors.top: parent.top
            anchors.rightMargin: BarConfig.style === "islands" ? 6 : 0
            anchors.topMargin: BarConfig.style === "full" ? 4 : 6
            height: BarConfig.style === "full" ? 36 : 40
            width: layoutRow.implicitWidth + 20
            radius: BarConfig.style === "full" ? 14 : 20
            color: BarConfig.style === "islands" ? Theme.bg : "transparent"
            Behavior on anchors.leftMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on anchors.rightMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on anchors.topMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 220 } }
            Behavior on radius { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

            LayoutModule {
                id: layoutRow
                anchors.centerIn: parent
            }
        }

        Rectangle {
            id: sysIsland
            anchors.right: layoutIsland.left
            anchors.top: parent.top
            anchors.rightMargin: BarConfig.style === "islands" ? 6 : 0
            anchors.topMargin: BarConfig.style === "full" ? 4 : 6
            height: BarConfig.style === "full" ? 36 : 40
            width: sysRow.implicitWidth + 20
            radius: BarConfig.style === "full" ? 14 : 20
            color: BarConfig.style === "islands" ? Theme.bg : "transparent"
            Behavior on anchors.leftMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on anchors.rightMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on anchors.topMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 220 } }
            Behavior on radius { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

            SystemMonitorModule {
                id: sysRow
                anchors.centerIn: parent
            }
        }

        Rectangle {
            id: volIsland
            anchors.right: sysIsland.left
            anchors.top: parent.top
            anchors.rightMargin: BarConfig.style === "islands" ? 6 : 0
            anchors.topMargin: BarConfig.style === "full" ? 4 : 6
            height: BarConfig.style === "full" ? 36 : 40
            width: volRow.implicitWidth + 20
            radius: BarConfig.style === "full" ? 14 : 20
            color: BarConfig.style === "islands" ? Theme.bg : "transparent"
            Behavior on anchors.leftMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on anchors.rightMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on anchors.topMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 220 } }
            Behavior on radius { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

            VolumeModule {
                id: volRow
                anchors.centerIn: parent
                popup: audioPopup
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
        themeMenu: themeMenu
        powerMenu: powerMenu
        audioPopup: audioPopup
        networkPopup: networkPopup
        playerPopup: playerPopup
        caffeineModule: caffeineModule
        networkModule: netRow
        weatherModule: weatherModule
    }
}
