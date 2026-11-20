import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

Item {
    id: root
    implicitWidth: trayRow.implicitWidth
    implicitHeight: 24

    property var panelWindow: null

    Row {
        id: trayRow
        anchors.centerIn: parent
        spacing: 8

        Repeater {
            model: SystemTray.items

            delegate: Item {
                id: trayItem
                required property var modelData
                width: 20
                height: 20

                Image {
                    id: trayIcon
                    anchors.fill: parent
                    source: modelData.icon
                    sourceSize.width: 20
                    sourceSize.height: 20
                    smooth: true
                }

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    onClicked: (mouse) => {
                        if (mouse.button === Qt.RightButton) {
                            if (modelData.hasMenu && root.panelWindow) {
                                menuAnchor.open()
                            }
                        } else if (mouse.button === Qt.LeftButton) {
                            modelData.activate()
                        }
                    }
                }

                QsMenuAnchor {
                    id: menuAnchor
                    menu: modelData.menu
                    anchor.window: root.panelWindow

                    // Вычисляем абсолютную позицию иконки внутри PanelWindow
                    property point globalPos: root.panelWindow
                        ? trayIcon.mapToItem(root.panelWindow.contentItem, 0, 0)
                        : Qt.point(0, 0)

                    anchor.edges: Edges.Bottom | Edges.Left
                    anchor.gravity: Edges.Bottom | Edges.Right
                    anchor.rect.x: globalPos.x
                    anchor.rect.y: globalPos.y + trayIcon.height
                    anchor.rect.width: trayIcon.width
                    anchor.rect.height: trayIcon.height
                }
            }
        }
    }
}
