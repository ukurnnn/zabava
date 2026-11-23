// self-contained Quickshell Greeter for greetd
// Run via: qs -p /path/to/quickshell/greeter/shell.qml
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Greetd

ShellRoot {
    id: root

    // =============== LOCAL THEME (matugen + Mocha fallback) ===============
    property var mat: ({})
    readonly property var fb: ({
        bg: "#1e1e2e", surface: "#313244", surface1: "#45475a",
        overlay: "#6c7086", fg: "#cdd6f4", fgMuted: "#a6adc8",
        accent: "#89b4fa", accent2: "#b4befe", green: "#a6e3a1",
        red: "#f38ba8", mauve: "#cba6f7", yellow: "#f9e2af"
    })
    property string cBg: mat["bg"] || fb.bg
    property string cSurface1: mat["surface1"] || fb.surface1
    property string cSurface: mat["surface"] || fb.surface
    property string cFg: mat["fg"] || fb.fg
    property string cFgMuted: mat["fgMuted"] || fb.fgMuted
    property string cAccent: mat["accent"] || fb.accent
    property string cRed: mat["red"] || fb.red
    property string cMauve: mat["mauve"] || fb.mauve

    Process {
        id: themeProc
        // HOME у greeter может быть /var/lib/greeter; поддерживаем XDG cache/config и дефолт.
        command: ["bash", "-c", "cache=\"${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/matugen-colors.json\"; cfg=\"${XDG_CONFIG_HOME:-$HOME/.config}/quickshell\"; for f in /var/lib/greeter/matugen-colors.json \"$cache\" \"$cfg/matugen-colors.json\" \"$cfg/matugen-colors.default.json\"; do [ -f \"$f\" ] && { cat \"$f\"; exit 0; }; done; exit 0"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var t = this.text.trim()
                if (t === "") return
                try { root.mat = JSON.parse(t) } catch (e) {}
            }
        }
    }
    Timer { interval: 1000; running: true; repeat: true; onTriggered: themeProc.running = true }

    // ========================= ЧАСЫ =========================
    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            var d = new Date()
            root.clockTime = Qt.formatDateTime(d, "HH:mm")
            root.clockDate = d.toLocaleDateString(Qt.locale("ru_RU"), "ddd, d MMM")
        }
    }

    // ============ ОБОИ (положить в /var/lib/greeter/wallpaper.*) ============
    Process {
        id: wallProc
        running: true
        command: ["bash", "-c", "ls /var/lib/greeter/wallpaper.* 2>/dev/null | head -n 1"]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = this.text.trim()
                if (p !== "") root.wallpaperPath = "file://" + p
            }
        }
    }

    // ===================== КНОПКИ ПИТАНИЯ =====================
    Process { id: rebootProc; command: ["systemctl", "reboot"] }
    Process { id: poweroffProc; command: ["systemctl", "poweroff"] }
    property int holdDuration: 900

    // ===================== ЗАПОМИНАНИЕ СЕССИИ =====================
    FileView {
        id: lastSessionFile
        // ВАЖНО: HOME у юзера greeter = "/" (см. /etc/passwd), поэтому путь явный
        path: "/var/lib/greeter/.last-session"
        atomicWrites: true
        preload: true
        onLoaded: {
            root.savedSession = this.text().trim()
            // гонка с sessProc: если он уже отработал до загрузки файла,
            // savedSession никем не применён — добиваем вручную
            if (root.savedSession !== "") {
                for (var i = 0; i < root.sessions.length; i++)
                    if (root.sessions[i].name === root.savedSession) {
                        root.sessionExec = root.sessions[i].exec
                        root.sessionName = root.sessions[i].name
                        break
                    }
            }
        }
    }
    function rememberSession() {
        if (root.sessionName === "") return
        lastSessionFile.setText(root.sessionName) // setText сам пишет файл
    }

    // ================= LAST USER (как LastUser в SDDM) =================
    FileView {
        id: lastUserFile
        // ВАЖНО: HOME у greeter = "/" (домашний каталог из /etc/passwd),
        // поэтому явный путь в каталог, который принадлежит greeter
        path: "/var/lib/greeter/.last-user"
        atomicWrites: true
        preload: true
        onLoaded: {
            var u = this.text().trim()
            if (u !== "") {
                root.username = u
                userField.text = u
                root.statusText = "Логин и пароль"
                passField.forceActiveFocus()
            }
        }
    }
    function rememberUser() {
        if (root.username === "") return
        lastUserFile.setText(root.username) // setText сам пишет файл
    }

    // Debug log
    Process { id: dbgA; command: ["true"] }
    Process { id: dbgB; command: ["true"] }
    property bool dbgFlip: false
    function dbg(msg) {
        root.dbgFlip = !root.dbgFlip
        var safe = ("" + msg).replace(/["'\\$`]/g, " ")
        var p = root.dbgFlip ? dbgA : dbgB
        p.command = ["bash", "-c", "echo \"$(date +%T.%3N) " + safe + "\" >> /var/lib/greeter/debug.log"]
        p.running = true
    }

    // ============================ GREETD ============================
    property string username: ""
    property bool editingUser: false // показать поле логина для смены юзера
    property string password: ""
    property string sessionUser: ""     // для какого юзера создана текущая greetd-сессия
    property bool pendingRespond: false // ждём промпт, на который надо ответить паролем
    property bool promptPending: false  // greetd прямо сейчас ждёт ответ на промпт
    property bool launching: false      // launch() уже вызван — защита от двойного запуска
    property string statusText: Greetd.available ? "" : "greetd недоступен (запусти через greetd)"
    property string sessionExec: ""
    property string sessionName: ""
    property string xkbLayout: "us"
    property var sessions: []
    // только русский и английский (us = EN, ru = RU) — как в niri-конфиге
    property var layouts: ["us", "ru"]
    property string clockTime: ""
    property string clockDate: ""
    property string wallpaperPath: ""
    property string savedSession: ""
    property bool authError: false
    property bool showPass: false
    property real shakeX: 0

    Connections {
        target: Greetd
        function onStateChanged() {
            root.dbg("STATE=" + Greetd.state)
            // сессия вернулась в исходное состояние (ошибка/cancel) — сбрасываем защёлки
            if (Greetd.state === GreetdState.Inactive) {
                root.promptPending = false
                root.pendingRespond = false
                root.launching = false
            }
        }
        function onAuthMessage(message, error, responseRequired) {
            root.dbg("MSG msg='" + message + "' err=" + error + " req=" + responseRequired + " pend=" + root.pendingRespond + " passlen=" + root.password.length)
            if (message !== "") root.statusText = message
            root.promptPending = responseRequired
            // greetd ждёт ответ на промпт — отдаём пароль ровно один раз
            if (responseRequired && root.pendingRespond) {
                root.pendingRespond = false
                root.promptPending = false
                root.dbg("RESPOND len=" + root.password.length)
                Greetd.respond(root.password)
            }
        }
        function onAuthFailure(message) {
            root.dbg("FAIL '" + message + "'")
            root.statusText = message || "Неверный пароль"
            root.authError = true
            authShake.restart() // id, не свойство root
            root.password = ""
            passField.text = "" // привязка text: root.password разорвана вводом — чистим вручную
            root.pendingRespond = false
            root.promptPending = false
            root.launching = false
            root.sessionUser = "" // после провала сессию нужно создать заново
            passField.forceActiveFocus() // сразу можно вводить заново, Enter снова работает
        }
        function onReadyToLaunch() {
            root.dbg("READY user=" + root.sessionUser)
            root.pendingRespond = false
            root.promptPending = false
            root.rememberUser() // сохранить юзера для автоподстановки
            root.rememberSession() // сохранить выбранную сессию
            launchTimer.restart() // пауза, чтобы FileView успел сбросить запись на диск до выхода
        }
        function onError(msg) { root.dbg("ERR '" + msg + "'"); root.statusText = "Ошибка greetd: " + msg }
    }

    Timer {
        id: launchTimer
        interval: 120
        onTriggered: root.doLaunch()
    }

    property real lastSubmit: 0 // анти-дабл: onAccepted поля + оконный Shortcut срабатывают на один Enter
    function submit() {
        var now = Date.now()
        if (now - root.lastSubmit < 400) { root.dbg("SUBMIT SKIP double") ; return }
        root.lastSubmit = now
        root.dbg("SUBMIT user=" + root.username + " passlen=" + root.password.length + " sessUser=" + root.sessionUser + " state=" + Greetd.state)
        if (!Greetd.available) { root.statusText = "greetd недоступен"; return }
        if (root.username === "") { root.statusText = "Введите логин"; return }
        if (root.password === "") return
        // GreetdState: 0=Inactive 1=Authenticating 2=ReadyToLaunch 3=Launching 4=Launched.
        // Уже аутентифицированы — запускаем немедленно (страховка, если таймер не сработал).
        if (Greetd.state === GreetdState.ReadyToLaunch) { root.doLaunch(); return }
        if (Greetd.state === GreetdState.Launching || Greetd.state === GreetdState.Launched) return
        root.statusText = "Проверка…"
        root.authError = false
        // greetd уже ждёт ответ на промпт — отвечаем напрямую,
        // без повторного create_session (иначе «session already being configured»)
        if (root.promptPending) {
            root.promptPending = false
            root.sessionUser = root.username
            root.dbg("RESPOND len=" + root.password.length)
            Greetd.respond(root.password)
            return
        }
        // создаём greetd-сессию для ВВЕДЁННОГО юзера, пароль отдаст onAuthMessage.
        // cancelSession() здесь НЕ вызываем: Quickshell сам пересоздаёт сессию
        // при ошибке "a session is already being configured", а ручной cancel
        // гонкой (cancel+create подряд) ломал повторный вход.
        root.sessionUser = root.username
        root.pendingRespond = true
        Greetd.createSession(root.username)
    }

    // ФУНКЦИЯ ДОЛЖНА ЖИТЬ НА ROOT, а не внутри Connections:
    // внутри Connections она недоступна как root.doLaunch() → TypeError
    // → Greetd.launch() не вызывался → после логина вечный чёрный экран.
    function doLaunch() {
        if (root.launching) return
        if (Greetd.state !== GreetdState.ReadyToLaunch) {
            root.dbg("LAUNCH SKIP state=" + Greetd.state)
            return
        }
        root.launching = true
        var desktop = root.sessionName !== "" ? root.sessionName.toLowerCase() : "niri"
        var env = [
            "XDG_SESSION_TYPE=wayland",
            "XKB_DEFAULT_LAYOUT=" + root.xkbLayout,
            "DESKTOP_SESSION=" + root.sessionName,
            "XDG_SESSION_DESKTOP=" + desktop,
            "XDG_CURRENT_DESKTOP=" + desktop
        ]
        var cmd = []
        if (root.sessionExec !== "") {
            cmd = root.sessionExec.split(" ")
            for (var i = cmd.length - 1; i >= 0; i--)
                if (cmd[i].length && cmd[i].charAt(0) === "%") cmd.splice(i, 1)
        }
        if (cmd.length === 0) cmd = ["/usr/bin/niri-session"]
        root.dbg("LAUNCH cmd=" + cmd.join(" "))
        Greetd.launch(cmd, env, true) // quit=true: greeter завершается после запуска сессии
    }

    Component.onCompleted: {
        root.dbg("INIT avail=" + Greetd.available + " sock=" + Quickshell.env("GREETD_SOCK"))
        if (Greetd.available) root.statusText = "Логин и пароль"
    }

    // ========================= SESSIONS =========================
    Process {
        id: sessProc
        running: true
        command: ["bash", "-c",
            "for f in /usr/share/wayland-sessions/*.desktop; do " +
            "if [ -f \"$f\" ]; then n=$(grep -m1 '^Name=' \"$f\" | cut -d= -f2-); " +
            "e=$(grep -m1 '^Exec=' \"$f\" | cut -d= -f2-); " +
            "echo \"$n\"; echo \"$e\"; fi; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n")
                var list = [], i = 0
                while (i + 1 < lines.length) {
                    var name = lines[i].trim(), exe = lines[i+1].trim()
                    if (name !== "" && exe !== "") list.push({ name: name, exec: exe })
                    i += 2
                }
                if (list.length === 0) list = [{ name: "Niri", exec: "/usr/bin/niri" }]
                root.sessions = list
                var pick = list[0]
                if (root.savedSession !== "") {
                    for (var j = 0; j < list.length; j++)
                        if (list[j].name === root.savedSession) { pick = list[j]; break }
                }
                root.sessionExec = pick.exec
                root.sessionName = pick.name
            }
        }
    }

    // ========================= LAYOUTS =========================

    // Раскладки захардкожены (us/ru) — localectl-процесс убран,
    // экономит спавн процесса при старте гретера

    // ========================= WINDOW =========================
    PanelWindow {
        anchors { top: true; bottom: true; left: true; right: true }
        color: "#000000"
        visible: true
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-greeter"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        // обои (если положены в /var/lib/greeter/wallpaper.*) с блюром
        Image {
            anchors.fill: parent
            visible: root.wallpaperPath !== ""
            source: root.wallpaperPath
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 1920
            sourceSize.height: 1080
            MultiEffect {
                source: parent
                anchors.fill: parent
                blurEnabled: true
                blur: 1.0
                blurMax: 64
            }
        }
        // затемнение (с градиентным фолбэком, если обоев нет)
        Rectangle {
            anchors.fill: parent
            color: "#cc0d0d12"
            gradient: Gradient {
                GradientStop { position: 0; color: root.wallpaperPath === "" ? "#14141f" : "transparent" }
                GradientStop { position: 1; color: "#000000" }
            }
        }
        BackgroundEffect.blurRegion: Region { item: authCard }

        // большие часы сверху
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 56
            spacing: 2
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.clockTime
                color: root.cFg
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 68
                font.bold: true
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.clockDate
                color: root.cFgMuted
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 16
            }
        }

        // кнопки питания (низ слева) — polkit: см. /etc/polkit-1/rules.d/50-greeter.rules
        Row {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: 24
            spacing: 10
            Repeater {
                model: [
                    { icon: "\uf021", tip: "Перезагрузка", proc: rebootProc },
                    { icon: "\uf011", tip: "Выключение", proc: poweroffProc }
                ]
                delegate: Rectangle {
                    id: pwBtn
                    required property var modelData
                    width: 48; height: 48; radius: 14
                    color: ma.containsMouse ? root.cSurface1 : root.cSurface
                    border.color: ma.pressed ? root.cOrange : root.cSurface1
                    clip: true
                    Rectangle {
                        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                        width: parent.width * ma.holdProgress
                        radius: 14
                        color: Qt.rgba(root.cOrange.r, root.cOrange.g, root.cOrange.b, 0.32)
                    }
                    Text {
                        anchors.centerIn: parent
                        text: pwBtn.modelData.icon
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 20
                        color: ma.pressed ? root.cYellow : (ma.containsMouse ? root.cFg : root.cFgMuted)
                    }
                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        property real holdProgress: 0
                        property bool fired: false
                        onPressed: { fired = false; holdProgress = 0; holdTimer.restart() }
                        onReleased: { holdTimer.stop(); holdProgress = 0 }
                        onCanceled: { holdTimer.stop(); holdProgress = 0; fired = false }
                        Timer {
                            id: holdTimer; interval: 16; repeat: true
                            onTriggered: {
                                if (!ma.pressed) { stop(); ma.holdProgress = 0; return }
                                ma.holdProgress = Math.min(1, ma.holdProgress + (16 / root.holdDuration))
                                if (ma.holdProgress >= 1 && !ma.fired) { ma.fired = true; stop(); pwBtn.modelData.proc.running = true; ma.holdProgress = 0 }
                            }
                        }
                    }
                }
            }
        }


        // Enter в любом месте окна = «Войти» (если пароль пуст — просто переводим фокус)
        Shortcut {
            sequences: ["Return", "Enter"]
            context: Qt.WindowShortcut
            onActivated: {
                if (root.password !== "") {
                    root.submit()
                } else if (root.username === "") {
                    userField.forceActiveFocus()
                } else {
                    passField.forceActiveFocus()
                }
            }
        }

        Item {
            id: centerBox
            anchors.centerIn: parent
            width: 440
            height: 560
            transform: Translate { x: root.shakeX }
            opacity: 0
            Component.onCompleted: fadeIn.restart()

            NumberAnimation {
                id: fadeIn
                target: centerBox
                property: "opacity"
                from: 0; to: 1
                duration: 350
                easing.type: Easing.OutCubic
            }

            Rectangle {
                id: authCard
                anchors.fill: parent
                radius: 22
                color: root.cSurface
                border.color: root.authError ? root.cRed : root.cSurface1
                border.width: 1
            }

            SequentialAnimation {
                id: authShake
                NumberAnimation { target: root; property: "shakeX"; to: 14; duration: 60; easing.type: Easing.OutCubic }
                NumberAnimation { target: root; property: "shakeX"; to: -10; duration: 60; easing.type: Easing.OutCubic }
                NumberAnimation { target: root; property: "shakeX"; to: 6; duration: 50; easing.type: Easing.OutCubic }
                NumberAnimation { target: root; property: "shakeX"; to: 0; duration: 50; easing.type: Easing.OutCubic }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 36
                spacing: 18

                // header
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Вход"
                    color: root.cFg
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 26
                    font.bold: true
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.username || "пользователь"
                    color: root.cFgMuted
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                }

                // last user: авто-подстановка как в SDDM, «сменить» раскрывает поле
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 10
                    visible: !root.editingUser && root.username !== ""
                    Text {
                        text: root.username
                        color: root.cFg
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 15
                        font.bold: true
                    }
                    Rectangle {
                        Layout.preferredWidth: 74; Layout.preferredHeight: 26
                        radius: 8
                        color: root.cSurface1
                        Text {
                            anchors.centerIn: parent
                            text: "сменить"
                            color: root.cFgMuted
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { root.editingUser = true; userField.forceActiveFocus() }
                        }
                    }
                }

                // username field (раскрывается по «сменить» или если юзера ещё нет)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    radius: 12
                    visible: root.editingUser || root.username === ""
                    color: root.cBg
                    border.color: root.cSurface1
                    border.width: 1
                    TextInput {
                        id: userField
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 15
                        color: root.cFg
                        onAccepted: passField.forceActiveFocus()
                        onTextChanged: root.username = text
                    }
                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        verticalAlignment: Text.AlignVCenter
                        visible: root.username === ""
                        text: "логин"
                        color: root.cFgMuted
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 15
                    }
                }

                // password field
                Item { Layout.preferredHeight: 10 }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    radius: 12
                    color: root.cBg
                    border.color: root.cSurface1
                    border.width: 1
                    TextInput {
                        id: passField
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 40
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 15
                        color: root.cFg
                        echoMode: root.showPass ? TextInput.Normal : TextInput.Password
                        focus: true
                        onAccepted: root.submit()
                        Component.onCompleted: forceActiveFocus()
                        text: root.password
                        onTextChanged: root.password = text
                    }
                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 26; height: 26; radius: 8
                        color: eyeMa.containsMouse ? root.cSurface1 : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: root.showPass ? "\uf070" : "\uf06e"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            color: root.showPass ? root.cAccent : root.cFgMuted
                        }
                        MouseArea {
                            id: eyeMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { root.showPass = !root.showPass; passField.forceActiveFocus() }
                        }
                    }
                }

                // status
                Text {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 20
                    horizontalAlignment: Qt.AlignHCenter
                    text: root.statusText
                    color: root.authError ? root.cRed : root.cFgMuted
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                }

                // session buttons
                Row {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 8
                    Repeater {
                        model: root.sessions
                        delegate: Rectangle {
                            required property var modelData
                            height: 34
                            radius: 10
                            color: modelData.exec === root.sessionExec ? root.cAccent : root.cSurface1
                            width: btnTxt.implicitWidth + 24
                            Text {
                                id: btnTxt
                                anchors.centerIn: parent
                                text: modelData.name
                                color: modelData.exec === root.sessionExec ? root.cBg : root.cFg
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { root.sessionExec = modelData.exec; root.sessionName = modelData.name }
                            }
                        }
                    }
                }

                // layout dropdown
                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 4
                    Rectangle {
                        id: layBtn
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 160; Layout.preferredHeight: 38
                        radius: 11
                        color: root.cSurface1
                        Item {
                            anchors.fill: parent
                            anchors.leftMargin: 14; anchors.rightMargin: 6
                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Раскладка · " + root.xkbLayout.toUpperCase()
                                color: root.cFg
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                            }
                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: layList.visible ? "▲" : "▼"
                                color: root.cFgMuted
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: layList.visible = !layList.visible
                        }
                    }
                    Rectangle {
                        id: layList
                        visible: false
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 160
                        Layout.preferredHeight: 34 * root.layouts.length + 8
                        radius: 11
                        color: root.cBg
                        border.color: root.cSurface1
                        border.width: 1
                        Column {
                            anchors.fill: parent
                            anchors.margins: 4
                            Repeater {
                                model: root.layouts
                                delegate: Rectangle {
                                    required property string modelData
                                    height: 30; width: 152; radius: 8
                                    color: modelData === root.xkbLayout ? root.cAccent : "transparent"
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.toUpperCase()
                                        color: modelData === root.xkbLayout ? root.cBg : root.cFg
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 12
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { root.xkbLayout = modelData; layList.visible = false }
                                    }
                                }
                            }
                        }
                    }
                }

                // submit button
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 200; Layout.preferredHeight: 46
                    radius: 13
                    color: root.cAccent
                    Text {
                        anchors.centerIn: parent
                        text: "Войти"
                        color: root.cBg
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 15
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.submit()
                    }
                }
            }
        }
    }
}
