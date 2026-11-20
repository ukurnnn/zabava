import QtQuick
import QtQuick.Controls
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
    WlrLayershell.namespace: "quickshell-clipboard"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property var items: []
    property string searchText: ""
    property var filteredItems: []

    IpcHandler {
        target: "clipboard"
        function toggle(): void { root.visible = !root.visible }
    }

    function loadItems() {
        listProc.running = true
    }

    function filterItems(query) {
        if (!query || query.length === 0) {
            filteredItems = items
            return
        }
        var q = query.toLowerCase()
        filteredItems = items.filter(function(item) {
            return item.text.toLowerCase().includes(q)
        })
    }

    function copyItem(id) {
        copyProc.command = ["bash", "-c", "setsid -f nohup sh -c 'cliphist decode " + id + " | wl-copy' >/dev/null 2>&1"]
        copyProc.running = true
        root.visible = false
    }

    function deleteItem(id) {
        delProc.command = ["bash", "-c", "echo " + id + " | cliphist delete"]
        delProc.running = true
        refetchTimer.running = true
    }

    function clearAll() {
        clearProc.running = true
        refetchTimer.running = true
    }

    Process {
        id: listProc
        command: ["bash", "-c", "cliphist list | head -100"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n")
                var result = []
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i]
                    if (line === "") continue
                    var tabIdx = line.indexOf("\t")
                    if (tabIdx === -1) continue
                    var id = line.substring(0, tabIdx)
                    var preview = line.substring(tabIdx + 1)
                    result.push({ id: id, text: preview })
                }
                root.items = result
                root.filterItems(root.searchText)
            }
        }
    }

    Process {
        id: copyProc
        command: ["bash", "-c", "echo"]
        running: false
    }

    Process {
        id: delProc
        command: ["bash", "-c", "echo"]
        running: false
    }

    Process {
        id: clearProc
        command: ["cliphist", "wipe"]
        running: false
    }

    Timer {
        id: refetchTimer
        interval: 300
        repeat: false
        onTriggered: root.loadItems()
    }

    onVisibleChanged: {
        if (visible) {
            root.loadItems()
            searchField.text = ""
            root.searchText = ""
            root.filterItems("")
            searchField.forceActiveFocus()
        }
    }

    CloseHandler {
        target: root
    }

    Rectangle {
        id: clipboardBox
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom

        width: 600
        height: root.visible ? 420 : 0

        anchors.bottomMargin: root.visible ? 12 : -height - 20

        radius: 16
        color: Theme.glassPanel
        border.color: Theme.glassBorderStrong
        border.width: 1
        clip: true
        opacity: root.visible ? 1 : 0

        Behavior on height {
            NumberAnimation {
                duration: 280
                easing.type: Easing.OutCubic
            }
        }
        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on border.color { ColorAnimation { duration: 180 } }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 1
            height: Math.max(0, parent.height * 0.22)
            radius: Math.max(0, parent.radius - 1)
            z: 0
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.glassHighlight }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        Behavior on anchors.bottomMargin {
            NumberAnimation {
                duration: 280
                easing.type: Easing.OutCubic
            }
        }
        Behavior on opacity { NumberAnimation { duration: 160 } }
        Behavior on border.color { ColorAnimation { duration: 180 } }

        MouseArea { anchors.fill: parent; onClicked: {} }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "󰅇"
                    color: Theme.accent
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 18
                }

                Text {
                    Layout.fillWidth: true
                    text: "Буфер обмена"
                    color: Theme.fg
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 16
                    font.bold: true
                }

                Text {
                    text: "󰆴"
                    color: clearArea.containsMouse ? Theme.red : Theme.overlay
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 15
                    Behavior on color { ColorAnimation { duration: 150 } }

                    MouseArea {
                        id: clearArea
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.clearAll()
                    }
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
                Layout.preferredHeight: 40
                radius: 8
                color: Theme.surface

                TextField {
                    id: searchField
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    placeholderText: "Поиск..."
                    placeholderTextColor: Theme.fgMuted
                    color: Theme.fg
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    background: null
                    focus: true
                    selectByMouse: true

                    onTextChanged: {
                        root.searchText = text
                        root.filterItems(text)
                    }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape) {
                            root.visible = false
                            event.accepted = true
                        }
                    }
                }
            }

            ListView {
                id: itemsList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: root.filteredItems

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    width: itemsList.width
                    height: 60
                    radius: 10
                    color: hoverArea.containsMouse ? Theme.accent : Theme.surface

                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        Text {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            text: {
                                var t = modelData.text
                                if (t.length > 150) return t.substring(0, 150) + "..."
                                return t
                            }
                            color: hoverArea.containsMouse ? Theme.bg : Theme.fg
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            text: "󰆴"
                            color: deleteArea.containsMouse ? Theme.red : (hoverArea.containsMouse ? Theme.bg : Theme.overlay)
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                            Behavior on color { ColorAnimation { duration: 120 } }

                            MouseArea {
                                id: deleteArea
                                anchors.fill: parent
                                anchors.margins: -6
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.deleteItem(modelData.id)
                            }
                        }
                    }

                    MouseArea {
                        id: hoverArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.copyItem(modelData.id)
                        propagateComposedEvents: true
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.filteredItems.length === 0
                    text: root.searchText === "" ? "История пуста" : "Ничего не найдено"
                    color: Theme.overlay
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                }
            }
        }
    }
}
