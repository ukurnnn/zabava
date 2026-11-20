#!/bin/bash
set -e

export XDG_SESSION_TYPE=wayland
export QT_QPA_PLATFORM=wayland
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
export EGL_PLATFORM=gbm
export RUST_LOG=error
export NIRI_LOG=error

# Greetd создаёт сокет вида /run/greetd-<pid>.sock (с pid-суффиксом).
# Quickshell Greetd ищет путь в $GREETD_SOCK, иначе /run/greetd.sock.
# Если стандартного нет — подставляем фактический сокет демона.
if [ -z "$GREETD_SOCK" ]; then
    for s in /run/greetd.sock /run/greetd-*.sock; do
        if [ -S "$s" ]; then
            export GREETD_SOCK="$s"
            break
        fi
    done
fi

# Временный конфиг Niri, который запускает greeter и выходит после него
TEMP_CONFIG=$(mktemp)
cat >"$TEMP_CONFIG" <<'NIRI_EOF'
hotkey-overlay {
    skip-at-startup
}

layout {
    background-color "#000000"
}

// Отключение акселерации мыши (как в основном конфиге юзера)
input {
    keyboard {
        xkb {
            layout "us,ru"
            options "grp:alt_shift_toggle"
        }
    }
    mouse {
        accel-profile "flat"
    }
}

// Максимальная герцовка монитора (как в основном конфиге юзера)
output "DP-3" {
    mode "1920x1080@164.998"
    scale 1
}

// Лог quickshell пишем в каталог greeter — по нему видно, почему не стартует UI.
// После выхода qs гасим niri: greetd запустит сессию юзера только когда
// завершится процесс гритера (launch.sh → niri → qs), см. greetd-ipc(7).
spawn-at-startup "sh" "-c" "qs -p /etc/xdg/quickshell/greeter/shell.qml >>/var/lib/greeter/quickshell.log 2>&1; niri msg action quit --skip-confirmation"
NIRI_EOF

exec niri -c "$TEMP_CONFIG"
