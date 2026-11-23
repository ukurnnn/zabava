#!/usr/bin/env bash
set -euo pipefail

export XDG_SESSION_TYPE=wayland
export QT_QPA_PLATFORM=wayland
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
export EGL_PLATFORM=gbm
export RUST_LOG=error
export NIRI_LOG=error

# Greetd создаёт сокет вида /run/greetd-<pid>.sock (с pid-суффиксом).
# Quickshell Greetd ищет путь в $GREETD_SOCK, иначе /run/greetd.sock.
# Если стандартного нет — подставляем фактический сокет демона.
if [ -z "${GREETD_SOCK:-}" ]; then
    for s in /run/greetd.sock /run/greetd-*.sock; do
        if [ -S "$s" ]; then
            export GREETD_SOCK="$s"
            break
        fi
    done
fi

# Временный конфиг Niri, который запускает greeter и выходит после него
TEMP_CONFIG="$(mktemp --suffix=.kdl)"
cleanup() { rm -f -- "$TEMP_CONFIG"; }
trap cleanup EXIT

# Optional greeter environment overrides:
#   GREETER_KB_LAYOUT    - xkb layout (e.g. "us,ru")
#   GREETER_KB_OPTIONS   - xkb options (e.g. "grp:alt_shift_toggle")
#   GREETER_NIRI_OUTPUT  - full Niri output block body, e.g. 'mode "1920x1080@60"; scale 1'
#   GREETER_NIRI_OUTPUT_NAME - output name for GREETER_NIRI_OUTPUT (default: "DP-1" if body set)
#   GREETER_NIRI_EXTRA_CONFIG - path to file with extra Niri KDL config appended
keyboard_block=""
if [ -n "${GREETER_KB_LAYOUT:-}" ] || [ -n "${GREETER_KB_OPTIONS:-}" ]; then
    keyboard_block="    keyboard {\n        xkb {\n"
    if [ -n "${GREETER_KB_LAYOUT:-}" ]; then
        keyboard_block+="            layout \"${GREETER_KB_LAYOUT}\"\n"
    fi
    if [ -n "${GREETER_KB_OPTIONS:-}" ]; then
        keyboard_block+="            options \"${GREETER_KB_OPTIONS}\"\n"
    fi
    keyboard_block+="        }\n    }\n"
fi

output_block=""
if [ -n "${GREETER_NIRI_OUTPUT:-}" ]; then
    output_name="${GREETER_NIRI_OUTPUT_NAME:-DP-1}"
    output_block="output \"${output_name}\" {\n    ${GREETER_NIRI_OUTPUT}\n}\n"
fi

extra_config=""
if [ -n "${GREETER_NIRI_EXTRA_CONFIG:-}" ] && [ -f "${GREETER_NIRI_EXTRA_CONFIG}" ]; then
    extra_config="$(cat -- "${GREETER_NIRI_EXTRA_CONFIG}")"
fi

{
    cat <<'NIRI_EOF'
hotkey-overlay {
    skip-at-startup
}

layout {
    background-color "#000000"
}

input {
NIRI_EOF
    if [ -n "$keyboard_block" ]; then
        printf '%b' "$keyboard_block"
    fi
    cat <<'NIRI_EOF'
    mouse {
        accel-profile "flat"
    }
}

NIRI_EOF
    if [ -n "$output_block" ]; then
        printf '%b\n' "$output_block"
    fi
    if [ -n "$extra_config" ]; then
        printf '%s\n' "$extra_config"
    fi
    cat <<'NIRI_EOF'
// Лог quickshell пишем в каталог greeter — по нему видно, почему не стартует UI.
// После выхода qs гасим niri: greetd запустит сессию юзера только когда
// завершится процесс гритера (launch.sh → niri → qs), см. greetd-ipc(7).
spawn-at-startup "sh" "-c" "mkdir -p /var/lib/greeter && qs -p /etc/xdg/quickshell/greeter/shell.qml >>/var/lib/greeter/quickshell.log 2>&1; niri msg action quit --skip-confirmation"
NIRI_EOF
} >"$TEMP_CONFIG"

exec niri -c "$TEMP_CONFIG"
