import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

PopupWindow {
    id: root

    anchor.window: panelWindow
    anchor.rect.x: anchorItem && panelWindow
        ? Math.max(8, Math.min(panelWindow.width - width - 8,
            anchorItem.mapToItem(panelWindow.contentItem, 0, 0).x + anchorItem.width / 2 - width / 2))
        : (panelWindow ? (panelWindow.width - width) / 2 : 0)
    anchor.rect.y: 48
    anchor.rect.width: 1
    anchor.rect.height: 1

    implicitWidth: 360
    implicitHeight: Math.min(contentCol.implicitHeight + 28, 420)
    visible: false
    color: "transparent"

    property var panelWindow: null
    property var anchorItem: null
    property var osd: null
    property var sink: Pipewire.defaultAudioSink
    property var sinkAudio: sink ? sink.audio : null
    property var source: Pipewire.defaultAudioSource
    property var sourceAudio: source ? source.audio : null
    property var headphoneBatteries: []

    readonly property var nodes: {
        var n = Pipewire.nodes
        if (!n) return []
        var v = n.values !== undefined ? n.values : n
        return v || []
    }

    IpcHandler {
        target: "audiopopup"
        function toggle(): void { root.visible = !root.visible }
    }

    PwObjectTracker {
        objects: {
            var list = [root.sink, root.source]
            var n = root.nodes || []
            for (var i = 0; i < n.length; i++) list.push(n[i])
            return list
        }
    }

    function batteryIcon(percent) {
        var p = Math.max(0, Math.min(100, percent))
        if (p >= 95) return "󰥈"
        if (p >= 85) return "󰥆"
        if (p >= 75) return "󰥅"
        if (p >= 65) return "󰥄"
        if (p >= 55) return "󰥃"
        if (p >= 45) return "󰥂"
        if (p >= 35) return "󰥁"
        if (p >= 25) return "󰥀"
        if (p >= 15) return "󰤿"
        if (p >= 5)  return "󰤾"
        return "󰥇"
    }

    function batteryColor(percent) {
        if (percent <= 15) return Theme.red
        if (percent <= 30) return Theme.orange
        return Theme.green
    }

    function refreshBatteries() {
        batteryProc.running = true
    }

    Process {
        id: batteryProc
        command: ["bash", "-lc",
            "out=''; " +
            "def_sink=$(pactl get-default-sink 2>/dev/null || pactl info 2>/dev/null | awk -F': ' '/Default Sink:/{print $2; exit}'); " +
            "out=$(pactl list sinks 2>/dev/null | awk -v def=\"$def_sink\" ' " +
            "  $1==\"Sink\"{inb=0} " +
            "  $1==\"Name:\"{inb=1; sname=$2; desc=sname; pr=(sname==def?0:1)} " +
            "  inb && $1==\"Description:\"{sub(/^.*Description: /,\"\"); desc=$0} " +
            "  inb && index($0,\"battery\") && $0 ~ /%/{ " +
            "    line=$0; gsub(/^[ \\t]+/,\"\",line); " +
            "    if (match(line,/([0-9]{1,3})%/,m)) pct=m[1]; else pct=\"\"; " +
            "    sub(/:.*/,\"\",line); lbl=line; " +
            "    gsub(/bluetooth\\\\.battery\\\\.percentage|\\\\.percentage|\\\\.battery/,\"\",lbl); " +
            "    gsub(/[_\\\\.]+/,\" \",lbl); gsub(/^[ \\t]+|[ \\t]+$/,\"\",lbl); " +
            "    if (lbl==\"\") lbl=\"Battery\"; " +
            "    if (pct!=\"\") print pr \"\\t\" desc \"\\t\" lbl \"\\t\" pct; " +
            "  } " +
            "' | sort -n | cut -f2-); " +
            "if [ -n \"$out\" ]; then printf '%s\\n' \"$out\"; exit 0; fi; " +
            "if command -v headsetcontrol >/dev/null 2>&1; then " +
            "  hc=$(headsetcontrol -b 2>/dev/null || true); " +
            "  pct=$(printf '%s\\n' \"$hc\" | awk 'match($0,/([0-9]{1,3})%/,m){print m[1]; exit}'); " +
            "  if [ -n \"$pct\" ]; then printf '%s\\t%s\\t%s\\n' \"Headset\" \"\" \"$pct\"; exit 0; fi; " +
            "fi; " +
            "for dev in $(upower -e 2>/dev/null); do " +
            "  info=$(upower -i \"$dev\" 2>/dev/null) || continue; " +
            "  pct=$(printf '%s\\n' \"$info\" | awk '/^[[:space:]]*percentage:/{gsub(/%/,\"\",$2); print $2; exit}'); " +
            "  [ -z \"$pct\" ] && continue; " +
            "  model=$(printf '%s\\n' \"$info\" | awk -F: '/^[[:space:]]*model:/{sub(/^[^:]*:/,\"\",$0); gsub(/^[ \\t]+|[ \\t]+$/, \"\", $0); print $0; exit}'); " +
            "  icon=$(printf '%s\\n' \"$info\" | awk -F: '/^[[:space:]]*icon-name:/{sub(/^[^:]*:/,\"\",$0); gsub(/^[ \\t]+|[ \\t]+$/, \"\", $0); print $0; exit}'); " +
            "  np=$(printf '%s\\n' \"$info\" | awk -F: '/^[[:space:]]*native-path:/{sub(/^[^:]*:/,\"\",$0); gsub(/^[ \\t]+|[ \\t]+$/, \"\", $0); print $0; exit}'); " +
            "  low=$(printf '%s' \"$dev $model $icon $np\" | tr '[:upper:]' '[:lower:]'); " +
            "  case \"$low\" in " +
            "    *displaydevice*|*line_power*|*/ac*|*battery_bat*) continue ;; " +
            "  esac; " +
            "  case \"$low\" in " +
            "    *headset*|*headphone*|*earbud*|*airpod*|*buds*|*handsfree*|*audio-head*|*headset_dev*|*audio*) " +
            "      name=\"$model\"; [ -z \"$name\" ] && name=$(basename \"$dev\"); " +
            "      printf '%s\\t%s\\t%s\\n' \"$name\" \"\" \"${pct%.*}\" ;; " +
            "  esac; " +
            "done | awk -F'\\t' '!seen[$1\"\\t\"$3]++'"
        ]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = (this.text || "").trim().split("\n")
                var out = []
                for (var i = 0; i < lines.length; i++) {
                    var line = (lines[i] || "").trim()
                    if (line === "") continue
                    var parts = line.split("\t")
                    var name = (parts[0] || "Headphones").trim()
                    var label = ""
                    var pct = NaN
                    if (parts.length >= 3) {
                        label = (parts[1] || "").trim()
                        pct = parseInt(parts[2])
                    } else {
                        pct = parseInt(parts[1])
                    }
                    if (isNaN(pct)) continue
                    var shownName = label && label !== "" && label.toLowerCase() !== "battery"
                        ? name + " (" + label + ")"
                        : name
                    out.push({ name: shownName, percent: pct })
                }
                root.headphoneBatteries = out
            }
        }
    }

    onVisibleChanged: {
        if (visible) refreshBatteries()
    }

    Timer {
        interval: 15000
        running: root.visible
        repeat: true
        onTriggered: root.refreshBatteries()
    }

    function nodeName(node) {
        if (!node) return "Unknown device"
        return node.description || node.nickname || node.name || "Unknown device"
    }

    function isOutputNode(node) {
        if (!node) return false
        var t = (node.type || "").toString()
        var n = (node.name || "").toString().toLowerCase()
        return t.indexOf("Sink") !== -1 || n.indexOf("sink") !== -1
    }

    function isInputNode(node) {
        if (!node) return false
        var t = (node.type || "").toString()
        var n = (node.name || "").toString().toLowerCase()
        return t.indexOf("Source") !== -1 || n.indexOf("source") !== -1
    }

    function outputNodes() {
        var out = []
        var list = root.nodes || []
        for (var i = 0; i < list.length; i++) {
            var n = list[i]
            if (isOutputNode(n) && !isInputNode(n)) out.push(n)
        }
        return out
    }

    function inputNodes() {
        var out = []
        var list = root.nodes || []
        for (var i = 0; i < list.length; i++) {
            var n = list[i]
            if (isInputNode(n) && !isOutputNode(n)) out.push(n)
        }
        return out
    }

    function setDefaultSink(node) {
        if (!node) return
        try {
            if (Pipewire.preferredDefaultAudioSink !== undefined) {
                Pipewire.preferredDefaultAudioSink = node
                return
            }
        } catch (e) {}
        try {
            if (node.isDefault !== undefined) node.isDefault = true
        } catch (e2) {}
    }

    function setDefaultSource(node) {
        if (!node) return
        try {
            if (Pipewire.preferredDefaultAudioSource !== undefined) {
                Pipewire.preferredDefaultAudioSource = node
                return
            }
        } catch (e) {}
        try {
            if (node.isDefault !== undefined) node.isDefault = true
        } catch (e2) {}
    }

    CloseHandler {
        target: root
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: 20
        color: Theme.bg
        border.color: Theme.surface1
        border.width: 1
        opacity: root.visible ? 1 : 0
        scale: root.visible ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: 150 } }
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: 180 } }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: 14
            clip: true
            contentWidth: width
            contentHeight: contentCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: contentCol
                width: flick.width
                spacing: 14

                Row {
                    width: parent.width
                    spacing: 8

                    Text {
                        text: "󰕾"
                        color: Theme.accent
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
                    }

                    Text {
                        text: "Звук"
                        color: Theme.fg
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 15
                        font.bold: true
                    }
                }

                // Output volume
                Rectangle {
                    width: parent.width
                    radius: 14
                    color: Theme.surface
                    implicitHeight: outCol.implicitHeight + 20

                    Column {
                        id: outCol
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        Row {
                            width: parent.width
                            spacing: 8

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.sinkAudio && root.sinkAudio.muted ? "󰝟" : "󰕾"
                                color: root.sinkAudio && root.sinkAudio.muted ? Theme.red : Theme.accent
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 16

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.sinkAudio) root.sinkAudio.muted = !root.sinkAudio.muted
                                    }
                                }
                            }

                            Column {
                                width: parent.width - 60
                                spacing: 2

                                Text {
                                    width: parent.width
                                    text: root.nodeName(root.sink)
                                    color: Theme.fg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: "Вывод"
                                    color: Theme.fgMuted
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 10
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.sinkAudio ? Math.round(root.sinkAudio.volume * 100) + "%" : "--"
                                color: Theme.fgMuted
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                            }
                        }

                        Item {
                            id: outSlider
                            width: parent.width
                            height: 18
                            property bool dragging: false

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: 6
                                radius: 3
                                color: Theme.bg

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width * Math.max(0, Math.min(1, root.sinkAudio ? root.sinkAudio.volume : 0))
                                    height: parent.height
                                    radius: 3
                                    color: root.sinkAudio && root.sinkAudio.muted ? Theme.fgMuted : Theme.accent
                                    Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: (mouse) => {
                                    outSlider.dragging = true
                                    if (root.sinkAudio) root.sinkAudio.volume = Math.max(0, Math.min(1, mouse.x / outSlider.width))
                                }
                                onPositionChanged: (mouse) => {
                                    if (pressed && root.sinkAudio)
                                        root.sinkAudio.volume = Math.max(0, Math.min(1, mouse.x / outSlider.width))
                                }
                                onReleased: outSlider.dragging = false
                                onWheel: (wheel) => {
                                    if (!root.sinkAudio) return
                                    var step = 0.05
                                    root.sinkAudio.volume = Math.max(0, Math.min(1, root.sinkAudio.volume + (wheel.angleDelta.y > 0 ? step : -step)))
                                }
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: 4
                            visible: root.headphoneBatteries.length > 0

                            Repeater {
                                model: root.headphoneBatteries

                                delegate: Row {
                                    required property var modelData
                                    width: outCol.width
                                    spacing: 8

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: root.batteryIcon(modelData.percent)
                                        color: root.batteryColor(modelData.percent)
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 14
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 90
                                        text: modelData.name
                                        color: Theme.fg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.percent + "%"
                                        color: Theme.fgMuted
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                    }
                                }
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: 4
                            visible: root.outputNodes().length > 0

                            Repeater {
                                model: root.outputNodes()

                                delegate: Rectangle {
                                    required property var modelData
                                    width: outCol.width
                                    height: 30
                                    radius: 8
                                    color: (root.sink && root.sink === modelData) ? Theme.accent : (devMouse.containsMouse ? Theme.surface1 : Theme.bg)
                                    border.color: (root.sink && root.sink === modelData) ? Theme.accent : Theme.surface1
                                    border.width: 1
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }

                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        spacing: 8

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: (root.sink && root.sink === modelData) ? "󰄬" : "󰓃"
                                            color: (root.sink && root.sink === modelData) ? Theme.bg : Theme.fgMuted
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 12
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - 28
                                            text: root.nodeName(modelData)
                                            color: (root.sink && root.sink === modelData) ? Theme.bg : Theme.fg
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                        }
                                    }

                                    MouseArea {
                                        id: devMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.setDefaultSink(modelData)
                                    }
                                }
                            }
                        }
                    }
                }

                // Input / mic
                Rectangle {
                    width: parent.width
                    radius: 14
                    color: Theme.surface
                    implicitHeight: inCol.implicitHeight + 20

                    Column {
                        id: inCol
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        Row {
                            width: parent.width
                            spacing: 8

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.sourceAudio && root.sourceAudio.muted ? "󰍭" : "󰍬"
                                color: root.sourceAudio && root.sourceAudio.muted ? Theme.red : Theme.accent
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 16

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.sourceAudio) {
                                            Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_SOURCE@", "toggle"])
                                        }
                                    }
                                }
                            }

                            Column {
                                width: parent.width - 60
                                spacing: 2

                                Text {
                                    width: parent.width
                                    text: root.nodeName(root.source)
                                    color: Theme.fg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: "Микрофон"
                                    color: Theme.fgMuted
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 10
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.sourceAudio ? Math.round(root.sourceAudio.volume * 100) + "%" : "--"
                                color: Theme.fgMuted
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                            }
                        }

                        Item {
                            id: inSlider
                            width: parent.width
                            height: 18

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: 6
                                radius: 3
                                color: Theme.bg

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width * Math.max(0, Math.min(1, root.sourceAudio ? root.sourceAudio.volume : 0))
                                    height: parent.height
                                    radius: 3
                                    color: root.sourceAudio && root.sourceAudio.muted ? Theme.fgMuted : Theme.green
                                    Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: (mouse) => {
                                    if (root.sourceAudio) root.sourceAudio.volume = Math.max(0, Math.min(1, mouse.x / inSlider.width))
                                }
                                onPositionChanged: (mouse) => {
                                    if (pressed && root.sourceAudio)
                                        root.sourceAudio.volume = Math.max(0, Math.min(1, mouse.x / inSlider.width))
                                }
                                onWheel: (wheel) => {
                                    if (!root.sourceAudio) return
                                    var step = 0.05
                                    root.sourceAudio.volume = Math.max(0, Math.min(1, root.sourceAudio.volume + (wheel.angleDelta.y > 0 ? step : -step)))
                                }
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: 4
                            visible: root.inputNodes().length > 0

                            Repeater {
                                model: root.inputNodes()

                                delegate: Rectangle {
                                    required property var modelData
                                    width: inCol.width
                                    height: 30
                                    radius: 8
                                    color: (root.source && root.source === modelData) ? Theme.accent : (inDevMouse.containsMouse ? Theme.surface1 : Theme.bg)
                                    border.color: (root.source && root.source === modelData) ? Theme.accent : Theme.surface1
                                    border.width: 1
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }

                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        spacing: 8

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: (root.source && root.source === modelData) ? "󰄬" : "󰍬"
                                            color: (root.source && root.source === modelData) ? Theme.bg : Theme.fgMuted
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 12
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - 28
                                            text: root.nodeName(modelData)
                                            color: (root.source && root.source === modelData) ? Theme.bg : Theme.fg
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                        }
                                    }

                                    MouseArea {
                                        id: inDevMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.setDefaultSource(modelData)
                                    }
                                }
                            }
                        }
                    }

                Rectangle {
                    width: parent.width
                    radius: 14
                    color: Theme.surface
                    visible: BrightnessService.available || BrightnessService.ready
                    implicitHeight: brightCol.implicitHeight + 20

                    Column {
                        id: brightCol
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        Row {
                            width: parent.width
                            spacing: 8

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: BrightnessService.percent >= 67 ? "󰃠" : (BrightnessService.percent >= 34 ? "󰃟" : "󰃞")
                                color: Theme.yellow
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 16
                            }

                            Column {
                                width: parent.width - 60
                                spacing: 2

                                Text {
                                    width: parent.width
                                    text: "Яркость"
                                    color: Theme.fg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: BrightnessService.available ? (BrightnessService.device || "backlight") : "Не найдено устройство подсветки"
                                    color: Theme.fgMuted
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 10
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: BrightnessService.available ? BrightnessService.percent + "%" : "--"
                                color: Theme.fgMuted
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                            }
                        }

                        Item {
                            width: parent.width
                            height: 18
                            visible: BrightnessService.available

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: 6
                                radius: 3
                                color: Theme.bg

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width * Math.max(0, Math.min(1, BrightnessService.percent / 100))
                                    height: parent.height
                                    radius: 3
                                    color: Theme.yellow
                                    Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: BrightnessService.available
                                function updateFromX(x) {
                                    var p = Math.round(Math.max(0, Math.min(1, x / width)) * 100)
                                    BrightnessService.setPercent(p)
                                    if (root.osd) root.osd.showOsd({ icon: "󰃟", label: "Яркость: " + p + "%", value: p })
                                }
                                onPressed: (mouse) => updateFromX(mouse.x)
                                onPositionChanged: (mouse) => { if (pressed) updateFromX(mouse.x) }
                                onWheel: (wheel) => {
                                    var step = wheel.angleDelta.y > 0 ? 5 : -5
                                    var p = Math.max(0, Math.min(100, BrightnessService.percent + step))
                                    BrightnessService.setPercent(p)
                                    if (root.osd) root.osd.showOsd({ icon: "󰃟", label: "Яркость: " + p + "%", value: p })
                                }
                            }
                        }
                    }
                }
                }
            }
        }
    }
}
