#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_NAME="quickshell"
DEFAULT_TARGET="${XDG_CONFIG_HOME:-$HOME/.config}/$CONFIG_NAME"
TARGET_DIR="$DEFAULT_TARGET"

# Options
DO_DEPS=0
DO_LINK=0
DO_COPY=0
DO_GREETER=0
ASSUME_YES=0
DRY_RUN=0
NO_AUR=0
AUR_HELPER=""
PRINT_DEPS=0

# Colors
if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; BLUE=$'\033[34m'; RESET=$'\033[0m'
else
  BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; RESET=""
fi

info()  { printf '%s[info]%s %s\n' "$BLUE" "$RESET" "$*"; }
ok()    { printf '%s[ ok ]%s %s\n' "$GREEN" "$RESET" "$*"; }
warn()  { printf '%s[warn]%s %s\n' "$YELLOW" "$RESET" "$*"; }
error() { printf '%s[err ]%s %s\n' "$RED" "$RESET" "$*" >&2; }
die()   { error "$*"; exit 1; }

usage() {
  cat <<'EOF'
Quickshell config installer

Usage:
  ./install.sh [options]

Options:
  -h, --help            Show this help
  -d, --deps            Install dependencies
  -l, --link            Symlink this repo to ~/.config/quickshell
  -c, --copy            Copy this repo to ~/.config/quickshell
  -g, --greeter         Install the greetd greeter (requires sudo)
  -a, --all             Install deps and link config (recommended)
  -y, --yes             Assume "yes" for prompts where safe
  -n, --dry-run         Show actions without making changes
      --no-aur          Do not use an AUR helper (Arch)
      --aur-helper CMD  Use a specific AUR helper (yay/paru)
      --target DIR      Install/link target (default: ~/.config/quickshell)
      --print-deps      Print dependency groups and exit

Examples:
  ./install.sh --all
  ./install.sh --deps --link
  ./install.sh --deps --yes --aur-helper yay
  ./install.sh --greeter

Notes:
  - Dependency auto-install currently supports Arch Linux (pacman, optional AUR helper).
    On other distros, use --print-deps and install equivalents manually.
  - --greeter modifies system configuration under /etc and /var/lib/greeter.
EOF
}

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '%s[dry]%s %q' "$DIM" "$RESET" "$1"
    shift || true
    for arg in "$@"; do printf ' %q' "$arg"; done
    printf '\n'
    return 0
  fi
  "$@"
}

confirm() {
  local prompt="$1"
  if [[ "$ASSUME_YES" -eq 1 ]]; then
    info "$prompt [auto-yes]"
    return 0
  fi
  local reply
  read -r -p "$prompt [y/N] " reply || true
  [[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]]
}

# Dependency groups (Arch package names; alternatives separated by '|')
# Core runtime / shell / utilities
DEPS_CORE=(
  quickshell|quickshell-git
  niri
  qt6-base qt6-declarative qt6-wayland qt6-svg qt6-5compat
  bash coreutils grep gawk sed findutils procps-ng iproute2 util-linux
  curl git
)
# Audio / media
DEPS_AUDIO=(
  pipewire pipewire-pulse wireplumber
  libpulse
  cava
)
# Network
DEPS_NETWORK=(
  networkmanager
)
# Clipboard
DEPS_CLIPBOARD=(
  wl-clipboard
  cliphist
)
# Theming / wallpaper integration
DEPS_THEMING=(
  matugen|matugen-bin
  waypaper
  awww|awww-git|swww
)
# Lock screen / auth helpers
DEPS_LOCK=(
  greetd
)
# Fonts / icons
DEPS_FONTS=(
  ttf-jetbrains-mono-nerd|nerd-fonts-jetbrains-mono
  noto-fonts-emoji
)
# Optional tools used by best-effort features
DEPS_OPTIONAL=(
  upower
  headsetcontrol
  playerctl
  nm-connection-editor
  polkit
)

print_deps() {
  cat <<'EOF'
Dependency groups (module coverage)

[Core / required]
  - quickshell (qs), niri, Qt6 QML modules (base/declarative/wayland/svg/5compat)
  - shell/utils: bash, coreutils, grep/gawk/sed, findutils, procps-ng, iproute2, curl, git
  Modules: shell/bar, launcher, workspaces/layout (NiriService), system monitor, clock/date, caffeine, weather, notifications base

[Audio & media]
  - pipewire, pipewire-pulse/wireplumber, pactl(wpctl/libpulse tools), cava
  - (runtime) MPRIS-capable players for media controls
  Modules: volume, audio popup, sound/media page, headphone battery (PipeWire/PulseAudio), MPRIS, Cava visualizer

[Network]
  - networkmanager (nmcli), iproute2 (ip)
  Modules: network module/popup/page, Wi-Fi scan/connect/toggle, IP/status

[Clipboard]
  - wl-clipboard (wl-copy), cliphist
  Modules: clipboard menu/history
  Note: cliphist needs a watcher, e.g. `wl-paste --watch cliphist store`

[Theming & wallpaper]
  - matugen (color generation)
  - waypaper (config source for wallpaper-derived theme, optional but used by "Из обоев")
  - awww (queried by lock screen wallpaper integration)
  Modules: Theme/matugen colors, Control Center color presets (matugen, wallpaper, custom)

[Fonts / icons]
  - JetBrainsMono Nerd Font (UI icons/glyphs throughout the config)
  - emoji font (recommended)
  Modules: all UI text/icons

[Optional / best-effort]
  - upower, headsetcontrol (headphone battery fallbacks)
  - playerctl (optional MPRIS helper)
  - nm-connection-editor (Wi-Fi connect fallback)
  - polkit (greeter power actions / system integration)

[Greeter] (separate: --greeter)
  - greetd, quickshell, niri, bash, systemd, polkit
  Files/actions: installs to /etc/xdg/quickshell/greeter, polkit rule, uses /var/lib/greeter

Arch Linux package hints:
  pacman: niri pipewire pipewire-pulse wireplumber libpulse networkmanager wl-clipboard cliphist cava curl git qt6-base qt6-declarative qt6-wayland qt6-svg qt6-5compat ttf-jetbrains-mono-nerd noto-fonts-emoji upower playerctl network-manager-applet/polkit greetd waypaper swww
  AUR (examples): quickshell or quickshell-git, matugen or matugen-bin, awww or awww-git, headsetcontrol
EOF
}

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -d|--deps) DO_DEPS=1; shift ;;
    -l|--link) DO_LINK=1; shift ;;
    -c|--copy) DO_COPY=1; shift ;;
    -g|--greeter) DO_GREETER=1; shift ;;
    -a|--all) DO_DEPS=1; DO_LINK=1; shift ;;
    -y|--yes) ASSUME_YES=1; shift ;;
    -n|--dry-run) DRY_RUN=1; shift ;;
    --no-aur) NO_AUR=1; shift ;;
    --aur-helper) AUR_HELPER="${2:-}"; shift 2 ;;
    --target) TARGET_DIR="${2:-}"; shift 2 ;;
    --print-deps) PRINT_DEPS=1; shift ;;
    *) die "Unknown option: $1 (use --help)" ;;
  esac
done

if [[ "$PRINT_DEPS" -eq 1 ]]; then
  print_deps
  exit 0
fi

if [[ "$DO_LINK" -eq 1 && "$DO_COPY" -eq 1 ]]; then
  die "Choose either --link or --copy, not both"
fi

if [[ "$DO_DEPS" -eq 0 && "$DO_LINK" -eq 0 && "$DO_COPY" -eq 0 && "$DO_GREETER" -eq 0 ]]; then
  info "No action selected. Starting interactive setup (use --help for options)."
  echo
  echo "Source: $SCRIPT_DIR"
  echo "Target: $TARGET_DIR"
  echo
  if confirm "Install dependencies?"; then DO_DEPS=1; fi
  if [[ ! -e "$TARGET_DIR" || "$TARGET_DIR" != "$SCRIPT_DIR" ]]; then
    if confirm "Symlink config to $TARGET_DIR?"; then DO_LINK=1; fi
  fi
  if confirm "Install greetd greeter (system-wide, sudo)?"; then DO_GREETER=1; fi
fi

detect_aur_helper() {
  if [[ -n "$AUR_HELPER" ]]; then
    command -v "$AUR_HELPER" >/dev/null 2>&1 && { echo "$AUR_HELPER"; return 0; }
    warn "Requested AUR helper '$AUR_HELPER' not found"
    return 1
  fi
  for h in yay paru; do
    if command -v "$h" >/dev/null 2>&1; then echo "$h"; return 0; fi
  done
  return 1
}

pacman_install() {
  local pkgs=("$@")
  [[ ${#pkgs[@]} -eq 0 ]] && return 0
  local cmd=(sudo pacman -S --needed)
  [[ "$ASSUME_YES" -eq 1 ]] && cmd+=(--noconfirm)
  cmd+=("${pkgs[@]}")
  run "${cmd[@]}"
}

aur_install() {
  local helper="$1"; shift
  local pkgs=("$@")
  [[ ${#pkgs[@]} -eq 0 ]] && return 0
  local cmd=("$helper" -S --needed)
  [[ "$ASSUME_YES" -eq 1 ]] && cmd+=(--noconfirm)
  cmd+=("${pkgs[@]}")
  run "${cmd[@]}"
}

resolve_group_arch() {
  # Echo packages to install: prefer ones available in repos; for alternatives pick first available.
  local out=()
  local item
  for item in "$@"; do
    if [[ "$item" == *"|"* ]]; then
      IFS='|' read -r -a alts <<<"$item"
      local chosen=""
      local a
      for a in "${alts[@]}"; do
        if pacman -Si "$a" >/dev/null 2>&1; then chosen="$a"; break; fi
      done
      if [[ -z "$chosen" ]]; then
        # try installed? else keep first as AUR candidate
        for a in "${alts[@]}"; do
          if pacman -Qi "$a" >/dev/null 2>&1; then chosen="$a"; break; fi
        done
      fi
      [[ -z "$chosen" ]] && chosen="${alts[0]}"
      out+=("$chosen")
    else
      out+=("$item")
    fi
  done
  printf '%s\n' "${out[@]}" | awk '!seen[$0]++'
}

split_repo_aur_arch() {
  local -n _repo="$1"; local -n _aur="$2"; shift 2
  _repo=(); _aur=()
  local p
  for p in "$@"; do
    if pacman -Si "$p" >/dev/null 2>&1 || pacman -Qi "$p" >/dev/null 2>&1; then
      _repo+=("$p")
    else
      _aur+=("$p")
    fi
  done
}

install_deps_arch() {
  info "Detected Arch Linux (pacman)."
  if [[ "$DRY_RUN" -eq 0 ]]; then
    run sudo pacman -Sy
  else
    info "[dry] would refresh package databases (sudo pacman -Sy)"
  fi

  local helper=""
  if [[ "$NO_AUR" -eq 0 ]]; then
    helper="$(detect_aur_helper || true)"
  fi
  [[ -n "$helper" ]] && info "AUR helper: $helper" || warn "No AUR helper found (yay/paru). AUR-only packages may need manual install."

  local groups=(DEPS_CORE DEPS_AUDIO DEPS_NETWORK DEPS_CLIPBOARD DEPS_THEMING DEPS_FONTS DEPS_OPTIONAL)
  local all_pkgs=()
  local g
  for g in "${groups[@]}"; do
    local -n arr="$g"
    # For groups that list alternatives per entry, handle specially
    local resolved=()
    if [[ "$g" == "DEPS_CORE" || "$g" == "DEPS_THEMING" || "$g" == "DEPS_FONTS" ]]; then
      # entries may be alternatives in-line (space separated list where some tokens contain '|')
      local item
      for item in "${arr[@]}"; do
        if [[ "$item" == *"|"* ]]; then
          IFS='|' read -r -a alts <<<"$item"
          local chosen="${alts[0]}"
          local a
          for a in "${alts[@]}"; do
            if pacman -Si "$a" >/dev/null 2>&1; then chosen="$a"; break; fi
          done
          resolved+=("$chosen")
        else
          resolved+=("$item")
        fi
      done
    else
      resolved=("${arr[@]}")
    fi
    all_pkgs+=("${resolved[@]}")
  done

  # de-dup
  mapfile -t all_pkgs < <(printf '%s\n' "${all_pkgs[@]}" | awk 'NF && !seen[$0]++')

  local repo_pkgs=() aur_pkgs=()
  split_repo_aur_arch repo_pkgs aur_pkgs "${all_pkgs[@]}"

  if [[ ${#repo_pkgs[@]} -gt 0 ]]; then
    info "Installing repo packages (${#repo_pkgs[@]}): ${repo_pkgs[*]}"
    pacman_install "${repo_pkgs[@]}" || warn "Some repo packages failed to install."
  fi

  if [[ ${#aur_pkgs[@]} -gt 0 ]]; then
    if [[ -n "$helper" && "$NO_AUR" -eq 0 ]]; then
      info "Installing AUR packages (${#aur_pkgs[@]}): ${aur_pkgs[*]}"
      aur_install "$helper" "${aur_pkgs[@]}" || warn "Some AUR packages failed to install."
    else
      warn "AUR packages not installed automatically: ${aur_pkgs[*]}"
      warn "Install them manually with an AUR helper, e.g.: yay -S ${aur_pkgs[*]}"
    fi
  fi

  ok "Dependency installation step finished (Arch)."
}

install_deps_generic() {
  warn "Automatic dependency installation is not implemented for this system."
  warn "Install dependencies manually. Summary:"
  echo
  print_deps
  echo
  warn "Common requirements: quickshell, niri, Qt6 (QML/Wayland), pipewire+wireplumber, networkmanager(nmcli), wl-clipboard, cliphist, matugen, cava, curl, upower, awww/swww, waypaper, JetBrainsMono Nerd Font, greetd (optional)."
}

install_deps() {
  if command -v pacman >/dev/null 2>&1; then
    install_deps_arch
  elif command -v apt-get >/dev/null 2>&1 || command -v dnf >/dev/null 2>&1 || command -v zypper >/dev/null 2>&1; then
    install_deps_generic
  else
    install_deps_generic
  fi
}

backup_path() {
  local p="$1"
  local ts
  ts="$(date +%Y%m%d-%H%M%S)"
  echo "${p}.bak.${ts}"
}

ensure_parent_dir() {
  local dir
  dir="$(dirname -- "$1")"
  [[ -d "$dir" ]] || run mkdir -p "$dir"
}

link_config() {
  local src="$SCRIPT_DIR"
  local dst="$TARGET_DIR"

  if [[ "$src" -ef "$dst" ]]; then
    ok "Config already at target: $dst"
    return 0
  fi

  ensure_parent_dir "$dst"

  if [[ -e "$dst" || -L "$dst" ]]; then
    local bak
    bak="$(backup_path "$dst")"
    warn "Target exists: $dst"
    if confirm "Backup to $bak and replace with symlink?"; then
      run mv "$dst" "$bak"
      ok "Backed up to $bak"
    else
      warn "Skipping link step."
      return 0
    fi
  fi

  run ln -s "$src" "$dst"
  ok "Linked $dst -> $src"
}

copy_config() {
  local src="$SCRIPT_DIR"
  local dst="$TARGET_DIR"

  if [[ "$src" -ef "$dst" ]]; then
    ok "Source and target are the same path: $dst"
    return 0
  fi

  ensure_parent_dir "$dst"

  if [[ -e "$dst" || -L "$dst" ]]; then
    local bak
    bak="$(backup_path "$dst")"
    warn "Target exists: $dst"
    if confirm "Backup to $bak and copy config?"; then
      run mv "$dst" "$bak"
      ok "Backed up to $bak"
    else
      warn "Skipping copy step."
      return 0
    fi
  fi

  run mkdir -p "$dst"
  if command -v rsync >/dev/null 2>&1; then
    run rsync -a --exclude '.git' "$src/" "$dst/"
  else
    run cp -a "$src/." "$dst/"
    run rm -rf "$dst/.git" 2>/dev/null || true
  fi
  ok "Copied config to $dst"
}

install_greeter() {
  local deploy="$SCRIPT_DIR/greeter/deploy.sh"
  [[ -f "$deploy" ]] || die "Greeter deploy script not found: $deploy"

  warn "This will install files into /etc/xdg/quickshell/greeter and /etc/polkit-1/rules.d (sudo)."
  if ! confirm "Proceed with greeter installation?"; then
    warn "Skipping greeter installation."
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    info "[dry] would run: (cd '$SCRIPT_DIR/greeter' && ./deploy.sh)"
    return 0
  fi

  (cd "$SCRIPT_DIR/greeter" && bash ./deploy.sh)
  ok "Greeter installed."
  echo "  To enable greetd instead of your current display manager, follow the instructions printed above."
}

post_install_notes() {
  echo
  printf '%sNext steps%s\n' "$BOLD" "$RESET"
  cat <<EOF
  1. Start/verify services (as needed):
       - NetworkManager: sudo systemctl enable --now NetworkManager
       - PipeWire (user): systemctl --user enable --now pipewire pipewire-pulse wireplumber
  2. Clipboard history (optional): run a watcher in your session, e.g.
       wl-paste --watch cliphist store
  3. Run the shell:
       qs -p "$TARGET_DIR/shell.qml"
     or, if linked/installed as your Quickshell config:
       qs -c quickshell
  4. Niri keybind for Control Center (example):
       Mod+A { spawn "qs" "-p" "$TARGET_DIR" "ipc" "call" "controlcenter" "toggle"; }
  5. Theming: install a Nerd Font and ensure "JetBrainsMono Nerd Font" is available for icons.
  6. Wallpaper theme preset reads waypaper config (~/.config/waypaper/config.ini) and uses matugen.
EOF
}

main() {
  echo "${BOLD}Quickshell config installer${RESET}"
  echo "Source: $SCRIPT_DIR"
  echo "Target: $TARGET_DIR"
  echo

  if [[ "$DO_DEPS" -eq 1 ]]; then
    install_deps
    echo
  fi

  if [[ "$DO_LINK" -eq 1 ]]; then
    link_config
    echo
  fi

  if [[ "$DO_COPY" -eq 1 ]]; then
    copy_config
    echo
  fi

  if [[ "$DO_GREETER" -eq 1 ]]; then
    install_greeter
    echo
  fi

  if [[ "$DO_DEPS" -eq 1 || "$DO_LINK" -eq 1 || "$DO_COPY" -eq 1 || "$DO_GREETER" -eq 1 ]]; then
    post_install_notes
  else
    warn "Nothing to do. Use --all, --deps, --link, --copy, or --greeter (see --help)."
  fi
}

main "$@"
