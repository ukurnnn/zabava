#!/usr/bin/env bash
# Install or uninstall the Quickshell greetd greeter.
# System-wide paths are managed explicitly; run from a terminal.
set -euo pipefail

src="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
dst="/etc/xdg/quickshell/greeter"
polkit_dst="/etc/polkit-1/rules.d/50-greeter.rules"
mode="install"

usage() {
  cat <<'EOF'
Usage: ./deploy.sh [--install|--uninstall]

  --install     Install greeter files and polkit rule (default)
  --uninstall   Remove greeter files and polkit rule installed by this script
  -h, --help    Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install) mode="install"; shift ;;
    --uninstall) mode="uninstall"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

require_file() {
  local f="$1"
  [[ -f "$f" ]] || { echo "Missing required file: $f" >&2; exit 1; }
}

if [[ "$mode" == "install" ]]; then
  require_file "$src/launch.sh"
  require_file "$src/shell.qml"
  require_file "$src/50-greeter.rules"

  sudo install -d -m 755 -o greeter -g greeter -- "$dst"
  sudo install -m 755 -o greeter -g greeter -- "$src/launch.sh" "$dst/launch.sh"
  sudo install -m 644 -o greeter -g greeter -- "$src/shell.qml" "$dst/shell.qml"
  sudo install -d -m 755 -- /etc/polkit-1/rules.d
  sudo install -m 644 -o root -g root -- "$src/50-greeter.rules" "$polkit_dst"
  sudo systemctl restart polkit 2>/dev/null || true

  echo "Installed greeter files to $dst"
  echo "Installed polkit rule to $polkit_dst"
  echo
  echo "To enable greetd instead of your current display manager:"
  echo "  sudo systemctl disable <your-display-manager>"
  echo "  sudo systemctl enable greetd"
  echo "  reboot"
  echo
  echo "If login fails after reboot, switch to a TTY (Ctrl+Alt+F3), log in, and restore your DM:"
  echo "  sudo systemctl disable greetd"
  echo "  sudo systemctl enable --now <your-display-manager>"
  echo "  Logs: /var/lib/greeter/quickshell.log and journalctl -u greetd -b"
  exit 0
fi

# Uninstall: remove only known files/dir managed by this greeter.
if [[ -L "$dst" || -L "$polkit_dst" ]]; then
  echo "Refusing to remove symlinked target: $dst or $polkit_dst" >&2
  exit 1
fi

if [[ -d "$dst" ]]; then
  for f in "$dst/launch.sh" "$dst/shell.qml"; do
    if [[ -e "$f" || -L "$f" ]]; then
      sudo rm -f -- "$f"
    fi
  done
  # Remove directory only if empty after removing managed files.
  sudo rmdir -- "$dst" 2>/dev/null || echo "Left $dst in place (not empty or not removable)."
fi

if [[ -f "$polkit_dst" ]]; then
  sudo rm -f -- "$polkit_dst"
  sudo systemctl restart polkit 2>/dev/null || true
fi

echo "Greeter uninstall step complete."
echo "If you enabled greetd, disable it manually and re-enable your display manager as needed."
