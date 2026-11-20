import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    implicitWidth: canvas.width
    implicitHeight: canvas.height

    property int barCount: 12
    property int barWidth: 3
    property int barGap: 2
    property var bars: Array(barCount).fill(0)
    property var peaks: Array(barCount).fill(0)
    property var smoothed: Array(barCount).fill(0)

    // Cava живёт только когда реально нужен (остров виден и плеер играет)
    property bool active: true
    visible: active

    onActiveChanged: {
        if (active) {
            writeCfg.running = true   // перезапишет конфиг и запустит cava по выходу
        } else {
            cavaProc.running = false
        }
    }

    // ==== СГЛАЖИВАНИЕ + ПИКИ ====
    Timer {
        interval: 16   // ~60 fps
        running: root.active && cavaProc.running
        repeat: true

        onTriggered: {
            var changed = false
            for (var i = 0; i < root.barCount; i++) {
                var target = root.bars[i] / 255
                // быстрый подъём, плавное падение
                var s = root.smoothed[i]
                root.smoothed[i] = target > s ? s + (target - s) * 0.55 : s + (target - s) * 0.22
                // пик-шапка падает медленно
                root.peaks[i] = Math.max(root.smoothed[i], root.peaks[i] - 0.02)
                if (Math.abs(root.smoothed[i] - s) > 0.01 || root.peaks[i] > 0.01) changed = true
            }
            if (changed) canvas.requestPaint()
        }
    }

    Timer {
        interval: 100
        running: root.active && cavaProc.running
        repeat: true
        onTriggered: canvas.requestPaint()   // шум, чтобы кадры не замирали при тишине
    }

    Process {
        id: writeCfg
        command: ["bash", "-c",
            "mkdir -p /tmp/qs-cava && cat > /tmp/qs-cava/cava.ini <<'CFG'\n" +
            "[general]\n" +
            "framerate = 60\n" +
            "bars = " + root.barCount + "\n" +
            "autosens = 1\n" +
            "sleep_timer = 0\n" +
            "\n" +
            "[input]\n" +
            "method = pipewire\n" +
            "source = auto\n" +
            "\n" +
            "[output]\n" +
            "method = raw\n" +
            "raw_target = /dev/stdout\n" +
            "data_format = ascii\n" +
            "ascii_max_range = 255\n" +
            "bar_delimiter = 59\n" +
            "channels = mono\n" +
            "CFG"
        ]
        running: true
        onExited: if (root.active) cavaProc.running = true
    }

    Process {
        id: cavaProc
        command: ["cava", "-p", "/tmp/qs-cava/cava.ini"]
        running: false

        stdout: SplitParser {
            onRead: line => {
                var parts = line.replace(/\n$/, "").split(";")
                if (parts.length >= root.barCount) {
                    var newBars = []
                    for (var i = 0; i < root.barCount; i++) {
                        newBars.push(Math.min(parseInt(parts[i]) || 0, 255))
                    }
                    root.bars = newBars
                }
            }
        }
    }

    Canvas {
        id: canvas
        width: root.barCount * (root.barWidth + root.barGap) - root.barGap
        height: 26
        antialiasing: true
        renderStrategy: Canvas.Cooperative
        contextType: "2d"

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            var grad = ctx.createLinearGradient(0, height, 0, 0)
            grad.addColorStop(0, Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35))
            grad.addColorStop(0.4, Theme.accent.toString())
            grad.addColorStop(0.75, Theme.mauve.toString())
            grad.addColorStop(1, Theme.red.toString())

            var total = root.barCount * root.barWidth + (root.barCount - 1) * root.barGap
            var x0 = (width - total) / 2

            for (var i = 0; i < root.barCount; i++) {
                var v = Math.max(root.smoothed[i], 0.06)   // минимальная «дышащая» высота
                var h = Math.max(2, v * (height - 3))
                var x = x0 + i * (root.barWidth + root.barGap)
                var y = height - h

                ctx.fillStyle = grad
                // ствол со скруглённым верхом
                ctx.beginPath()
                if (ctx.roundRect) { ctx.roundRect(x, y, root.barWidth, h, root.barWidth / 2) }
                else { ctx.rect(x, y, root.barWidth, h) }
                ctx.fill()

                // падающая шапка-пик
                var ph = root.peaks[i] * (height - 3)
                if (ph > 2) {
                    ctx.fillStyle = Theme.fg.toString()
                    ctx.globalAlpha = 0.9
                    ctx.beginPath()
                    if (ctx.roundRect) { ctx.roundRect(x, height - ph - 2, root.barWidth, 2, 1) }
                    else { ctx.rect(x, height - ph - 2, root.barWidth, 2) }
                    ctx.fill()
                    ctx.globalAlpha = 1
                }
            }
        }
    }
}

