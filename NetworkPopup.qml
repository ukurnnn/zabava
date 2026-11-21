import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

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
    implicitHeight: Math.min(contentCol.implicitHeight + 28, 460)
    visible: false
    color: "transparent"

    property var panelWindow: null
    property var anchorItem: null
    property string connType: "none"
    property string ssid: ""
    property int signal: -1
    property string device: ""
    property string ipAddr: ""
    property var wifiNetworks: []
    property bool scanning: false
    property bool wifiEnabled: true

    property double rxBytes: -1
    property double txBytes: -1
    property double rxSpeed: 0
    property double txSpeed: 0
    property var rxHistory: []
    property var txHistory: []
    property int speedSamples: 24

    function formatSpeed(bytesPerSec) {
        var b = Math.max(0, Number(bytesPerSec) || 0)
        var units = ["Б/с", "КиБ/с", "МиБ/с", "ГиБ/с"]
        var i = 0
        while (b >= 1024 && i < units.length - 1) { b /= 1024; i++ }
        var digits = i === 0 ? 0 : (b >= 100 ? 0 : (b >= 10 ? 1 : 2))
        return b.toFixed(digits) + " " + units[i]
    }

    function pushSpeedSample(rx, tx) {
        var rxh = (rxHistory || []).slice(- (speedSamples - 1))
        var txh = (txHistory || []).slice(- (speedSamples - 1))
        rxh.push(Math.max(0, rx))
        txh.push(Math.max(0, tx))
        while (rxh.length < speedSamples) rxh.unshift(0)
        while (txh.length < speedSamples) txh.unshift(0)
        rxHistory = rxh
        txHistory = txh
    }

    IpcHandler {
        target: "networkpopup"
        function toggle(): void { root.visible = !root.visible }
    }

    function signalIcon(sig) {
        if (sig >= 75) return "󰤨"
        if (sig >= 50) return "󰤥"
        if (sig >= 25) return "󰤢"
        if (sig >= 0) return "󰤟"
        return "󰤯"
    }

    function refresh() {
        statusProc.running = true
        scanProc.running = true
        root.scanning = true
    }

    onVisibleChanged: {
        if (visible) {
            root.rxBytes = -1; root.txBytes = -1; root.rxSpeed = 0; root.txSpeed = 0
            root.rxHistory = []; root.txHistory = []
            refresh()
            speedProc.running = true
        }
    }

    Process {
        id: statusProc
        command: ["bash", "-c",
            "nmcli -t -f TYPE,DEVICE,CONNECTION,STATE dev status | awk -F: '$4==\"connected\"{print $1\":\"$2\":\"$3; exit}'; " +
            "echo '---'; " +
            "nmcli -t -f IN-USE,SIGNAL dev wifi list --rescan no 2>/dev/null | awk -F: '$1==\"*\"{print $2; exit}'; " +
            "echo '---'; " +
            "ip -4 -o addr show scope global 2>/dev/null | awk '{print $4; exit}'; " +
            "echo '---'; " +
            "nmcli -t -f WIFI g 2>/dev/null | head -n 1"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.split("---")
                var line = ((parts[0] || "").trim().split("\n")[0] || "").trim()
                var sigLine = ((parts[1] || "").trim().split("\n")[0] || "").trim()
                root.ipAddr = ((parts[2] || "").trim().split("\n")[0] || "").trim()
                var wifiState = ((parts[3] || "").trim().split("\n")[0] || "").toLowerCase()
                if (wifiState.indexOf("disabled") !== -1 || wifiState === "off") root.wifiEnabled = false
                else if (wifiState.indexOf("enabled") !== -1 || wifiState === "on") root.wifiEnabled = true
                root.signal = (sigLine !== "" && !isNaN(parseInt(sigLine))) ? parseInt(sigLine) : -1

                if (line === "") {
                    root.connType = "none"
                    root.device = ""
                    root.ssid = ""
                    return
                }
                var p = line.split(":")
                var type = p[0] || ""
                root.device = p[1] || ""
                if (type.indexOf("wifi") !== -1) {
                    root.connType = "wifi"
                    root.ssid = p[2] || ""
                } else if (type.indexOf("ethernet") !== -1) {
                    root.connType = "ethernet"
                    root.ssid = ""
                } else {
                    root.connType = "other"
                    root.ssid = p[2] || ""
                }
            }
        }
    }

    Process {
        id: scanProc
        command: ["bash", "-c",
            "nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list --rescan auto 2>/dev/null | head -n 12"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.scanning = false
                var lines = this.text.split("\n")
                var seen = {}
                var out = []
                for (var i = 0; i < lines.length; i++) {
                    var line = (lines[i] || "").trim()
                    if (line === "") continue
                    var parts = line.split(":")
                    var inUse = parts[0] === "*"
                    var ssid = parts[1] || ""
                    var sig = parseInt(parts[2] || "0")
                    if (isNaN(sig)) sig = 0
                    var sec = parts.slice(3).join(":") || ""
                    if (ssid === "") ssid = "Hidden network"
                    var key = ssid + "|" + sig + "|" + sec
                    if (seen[key]) continue
                    seen[key] = true
                    out.push({ inUse: inUse, ssid: ssid, signal: sig, security: sec })
                }
                out.sort(function(a, b) {
                    if (a.inUse !== b.inUse) return a.inUse ? -1 : 1
                    return b.signal - a.signal
                })
                root.wifiNetworks = out
            }
        }
    }

    Process {
        id: actionProc
        command: ["bash", "-c", "true"]
        running: false
        onExited: root.refresh()
    }

    Process {
        id: wifiToggleProc
        command: ["bash", "-lc", "nmcli radio wifi on"]
        running: false
        onExited: root.refresh()
    }

    Process {
        id: speedProc
        command: ["bash", "-c",
            "dev=$(nmcli -t -f DEVICE,TYPE,STATE dev status 2>/dev/null | awk -F: '$3==\"connected\"{print $1; exit}'); " +
            "if [ -z \"$dev\" ]; then dev=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i==\"dev\"){print $(i+1); exit}}'); fi; " +
            "if [ -n \"$dev\" ] && [ -r \"/sys/class/net/$dev/statistics/rx_bytes\" ]; then " +
            "  rx=$(cat /sys/class/net/$dev/statistics/rx_bytes 2>/dev/null); " +
            "  tx=$(cat /sys/class/net/$dev/statistics/tx_bytes 2>/dev/null); " +
            "  printf '%s\\t%s\\t%s\\n' \"$dev\" \"$rx\" \"$tx\"; " +
            "fi"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var txt = (this.text || "").trim()
                if (txt === "") {
                    root.rxSpeed = 0; root.txSpeed = 0
                    root.pushSpeedSample(0, 0)
                    return
                }
                var p = txt.split("\t")
                var dev = p[0] || ""
                var rx = parseFloat(p[1] || "-1")
                var tx = parseFloat(p[2] || "-1")
                if (dev !== "") root.device = dev
                if (isNaN(rx) || isNaN(tx)) return
                if (root.rxBytes >= 0 && root.txBytes >= 0) {
                    root.rxSpeed = Math.max(0, rx - root.rxBytes)
                    root.txSpeed = Math.max(0, tx - root.txBytes)
                    root.pushSpeedSample(root.rxSpeed, root.txSpeed)
                } else {
                    root.pushSpeedSample(0, 0)
                }
                root.rxBytes = rx
                root.txBytes = tx
            }
        }
    }

    Timer {
        interval: 1500
        running: root.visible
        repeat: true
        onTriggered: speedProc.running = true
    }

    CloseHandler {
        target: root
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: 20
        color: Theme.glassPanel
        border.color: Theme.glassBorderStrong
        border.width: 1
        opacity: root.visible ? 1 : 0
        scale: root.visible ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: 150 } }
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
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
                        text: "󰖩"
                        color: Theme.accent
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
                    }

                    Text {
                        width: parent.width - 70
                        text: "Сеть"
                        color: Theme.fg
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 15
                        font.bold: true
                    }

                    Text {
                        text: root.scanning ? "󰑓" : "󰑐"
                        color: refreshArea.containsMouse ? Theme.accent : Theme.fgMuted
                        Behavior on color { ColorAnimation { duration: 150 } }
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14

                        MouseArea {
                            id: refreshArea
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.refresh()
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    radius: 14
                    color: Theme.surface
                    implicitHeight: statusCol.implicitHeight + 20

                    Column {
                        id: statusCol
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        Row {
                            width: parent.width
                            spacing: 10

                            Text {
                                text: {
                                    if (root.connType === "none") return "󰖪"
                                    if (root.connType === "ethernet") return "󰈀"
                                    return root.signalIcon(root.signal)
                                }
                                color: root.connType === "none" ? Theme.red : Theme.green
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 22
                            }

                            Column {
                                width: parent.width - 40
                                spacing: 2

                                Text {
                                    width: parent.width
                                    text: {
                                        if (root.connType === "none") return "Нет подключения"
                                        if (root.connType === "ethernet") return "Ethernet"
                                        return root.ssid !== "" ? root.ssid : "Wi-Fi"
                                    }
                                    color: Theme.fg
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: {
                                        if (root.connType === "none") return "Устройство не подключено"
                                        var parts = []
                                        if (root.device !== "") parts.push(root.device)
                                        if (root.ipAddr !== "") parts.push(root.ipAddr)
                                        if (root.connType === "wifi" && root.signal >= 0) parts.push(root.signal + "%")
                                        return parts.join("  ·  ")
                                    }
                                    color: Theme.fgMuted
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        Rectangle { width: parent.width; height: 1; color: Theme.surface1; visible: root.connType !== "none" }

                        Row {
                            width: parent.width
                            spacing: 10
                            visible: root.connType !== "none"

                            Column {
                                width: (parent.width - 10) / 2
                                spacing: 2
                                Text { text: "󰁅 Загрузка"; color: Theme.green; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10 }
                                Text { text: root.formatSpeed(root.rxSpeed); color: Theme.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.bold: true }
                            }

                            Column {
                                width: (parent.width - 10) / 2
                                spacing: 2
                                Text { text: "󰁝 Отдача"; color: Theme.orange; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10 }
                                Text { text: root.formatSpeed(root.txSpeed); color: Theme.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.bold: true }
                            }
                        }

                        Item {
                            id: speedChart
                            width: parent.width
                            height: 74
                            visible: root.connType !== "none"

                            property var rxData: root.rxHistory || []
                            property var txData: root.txHistory || []
                            property real maxVal: {
                                var m = 1024
                                for (var i = 0; i < rxData.length; i++) m = Math.max(m, Number(rxData[i] || 0))
                                for (var j = 0; j < txData.length; j++) m = Math.max(m, Number(txData[j] || 0))
                                return m
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                color: Theme.bg
                                border.color: Theme.surface1
                                border.width: 1
                            }

                            Repeater {
                                model: 3
                                delegate: Rectangle {
                                    required property int index
                                    width: speedChart.width - 10
                                    height: 1
                                    x: 5
                                    y: 6 + index * ((speedChart.height - 12) / 3)
                                    color: Theme.surface1
                                    opacity: 0.7
                                }
                            }

                            Canvas {
                                id: speedCanvas
                                anchors.fill: parent
                                anchors.margins: 5
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    function drawLine(data, color) {
                                        if (!data || data.length < 2) return
                                        var maxV = Math.max(1, speedChart.maxVal)
                                        ctx.strokeStyle = color
                                        ctx.lineWidth = 1.5
                                        ctx.lineJoin = "round"
                                        ctx.beginPath()
                                        for (var i = 0; i < data.length; i++) {
                                            var x = i * width / Math.max(1, data.length - 1)
                                            var v = Math.max(0, Number(data[i] || 0))
                                            var y = height - (v / maxV) * height
                                            if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                                        }
                                        ctx.stroke()
                                    }
                                    drawLine(speedChart.rxData, Theme.green)
                                    drawLine(speedChart.txData, Theme.orange)
                                }
                                Connections {
                                    target: root
                                    function onRxHistoryChanged() { speedCanvas.requestPaint() }
                                    function onTxHistoryChanged() { speedCanvas.requestPaint() }
                                }
                                Connections {
                                    target: Theme
                                    function onGreenChanged() { speedCanvas.requestPaint() }
                                    function onOrangeChanged() { speedCanvas.requestPaint() }
                                }
                                Component.onCompleted: requestPaint()
                            }

                            Row {
                                anchors.left: parent.left
                                anchors.bottom: parent.bottom
                                anchors.margins: 6
                                spacing: 8
                                Text { text: "↓"; color: Theme.green; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9 }
                                Text { text: "↑"; color: Theme.orange; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9 }
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: 8

                    Text {
                        text: "Wi-Fi сети"
                        color: Theme.fg
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        font.bold: true
                    }

                    Text {
                        text: root.scanning ? "(поиск...)" : ""
                        color: Theme.fgMuted
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        visible: root.scanning
                    }
                }

                Column {
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: root.wifiNetworks

                        delegate: Rectangle {
                            required property var modelData
                            width: contentCol.width
                            height: 42
                            radius: 10
                            color: modelData.inUse ? Theme.accent : (netMouse.containsMouse ? Theme.surface : Theme.surface1)
                            border.color: modelData.inUse ? Theme.accent : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 8

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.signalIcon(modelData.signal)
                                    color: modelData.inUse ? Theme.bg : Theme.green
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 90
                                    spacing: 0

                                    Text {
                                        width: parent.width
                                        text: modelData.ssid
                                        color: modelData.inUse ? Theme.bg : Theme.fg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        width: parent.width
                                        text: modelData.security && modelData.security !== "--" ? modelData.security : "Open"
                                        color: modelData.inUse ? Theme.bg : Theme.fgMuted
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                    }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.inUse ? "Подключено" : modelData.signal + "%"
                                    color: modelData.inUse ? Theme.bg : Theme.fgMuted
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 10
                                }
                            }

                            MouseArea {
                                id: netMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.inUse) {
                                        actionProc.command = ["bash", "-lc", "nmcli device disconnect " + (root.device || "wlan0")]
                                    } else {
                                        var ssid = (modelData.ssid || "").replace(/'/g, "'\\''")
                                        actionProc.command = ["bash", "-lc", "nmcli dev wifi connect '" + ssid + "' || nm-connection-editor >/dev/null 2>&1 &"]
                                    }
                                    actionProc.running = true
                                }
                            }
                        }
                    }

                    Text {
                        visible: root.wifiNetworks.length === 0
                        text: root.scanning ? "Поиск сетей..." : "Сети не найдены"
                        color: Theme.fgMuted
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 34
                    radius: 10
                    color: settingsMouse.containsMouse ? Theme.accent : Theme.surface
                    border.color: Theme.surface1
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            text: root.wifiEnabled ? "󰖩" : "󰖪"
                            color: settingsMouse.containsMouse ? Theme.bg : Theme.fg
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                        }

                        Text {
                            text: root.wifiEnabled ? "Выключить Wi-Fi" : "Включить Wi-Fi"
                            color: settingsMouse.containsMouse ? Theme.bg : Theme.fg
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                        }
                    }

                    MouseArea {
                        id: settingsMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            wifiToggleProc.command = ["bash", "-lc", "nmcli radio wifi " + (root.wifiEnabled ? "off" : "on")]
                            wifiToggleProc.running = true
                        }
                    }
                }
            }
        }
    }
}
