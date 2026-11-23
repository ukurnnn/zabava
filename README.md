# Quickshell Config

A Quickshell-based desktop shell configuration (bar, launcher, popups, control center, theming, and optional greeter) built around a Wayland workflow with Niri integration.

## Features

- **Bar** with multiple styles: islands, monolithic (floating), and full-width (edge-to-edge), with presets and animated transitions.
- **App launcher** with ranking/frecency (launcher-only usage history), keyboard navigation, and fast search.
- **Control Center** (sidebar, per-module pages) for network, sound/media, notifications, bar, colors, power, and general settings. Toggle via IPC (`controlcenter toggle`).
- **Audio popup/page**: output/input control, device selection (PipeWire), and best-effort headphone battery indication (no synthetic values).
- **Network popup/page**: Wi-Fi/network status, scan/connect/disconnect, radio toggle (NetworkManager/`nmcli`).
- **Notifications**: popup and history/controls (including DND/clear, where supported by services).
- **Clipboard menu**: history via `cliphist` + `wl-clipboard`.
- **Calendar & weather** modules with periodic refresh.
- **Media/MPRIS** integration (player info/controls) and Cava visualizer.
- **Theming**: Matugen-based palettes, wallpaper-derived theme (via `waypaper` config + `matugen image`), and custom presets.
- **Optional greeter** for `greetd` (Quickshell UI launched through Niri).

## Repository layout

- `shell.qml` — main shell entrypoint (bar, popups, windows wiring)
- `ControlCenter.qml`, `*Popup.qml`, `*Module.qml` — UI components/modules
- `Theme.qml`, `BarConfig.qml`, `NiriService.qml`, `NotificationService.qml` — singletons/services
- `greeter/` — greetd greeter (`shell.qml`, `launch.sh`, `deploy.sh`, polkit rule)
- `install.sh` — dependency/config/greeter installer
- State/config files: `bar-config.json`, `color-presets.json` (tracked), runtime-generated `matugen-colors.json`, `usage.json` (ignored)

## Dependencies

Dependencies vary by module. The installer can print a full grouped list:

```bash
./install.sh --print-deps
```

### Summary

| Area | Packages/tools | Used by |
|---|---|---|
| Core | `quickshell` (qs), `niri`, Qt6 QML/Wayland modules, bash/coreutils/findutils/grep/sed/gawk/procps/iproute2/curl | Shell, bar, services, utilities |
| Audio & media | `pipewire`, `wireplumber`/`pipewire-pulse`, `wpctl`/Pulse tools, `cava`, MPRIS players | Volume, audio popup/page, media, Cava, headphone battery (best-effort) |
| Network | `networkmanager` (`nmcli`), `ip` | Network module/popup/page |
| Clipboard | `wl-clipboard` (`wl-copy`), `cliphist` | Clipboard menu/history |
| Theming | `matugen`, `waypaper` (optional, for wallpaper-derived preset), `awww` (lock screen wallpaper query) | Color presets, wallpaper theme, lock screen background lookup |
| Fonts/icons | JetBrainsMono Nerd Font (+ emoji font recommended) | Icons/glyphs across UI |
| Optional | `upower`, `headsetcontrol`, `playerctl`, `nm-connection-editor`, `polkit` | Best-effort battery fallbacks, media helper, Wi-Fi fallback, greeter/system actions |
| Greeter | `greetd`, `niri`, `quickshell`, `systemd`, `polkit` | `greeter/` deployment and session/login UI |

> Some integrations are best-effort and depend on hardware/drivers/tools (e.g. headphone battery).

## Installation

### Quick (Arch Linux)

```bash
git clone <repo-url> ~/.config/quickshell
cd ~/.config/quickshell
./install.sh --all
```

`--all` installs dependencies (auto-detects `pacman`, uses `yay`/`paru` for AUR packages when available) and symlinks the repo to `~/.config/quickshell`.

### Installer options

```bash
./install.sh --help
```

Common usage:

```bash
./install.sh --print-deps                 # show dependency groups
./install.sh --deps                       # install dependencies
./install.sh --link                       # symlink repo -> ~/.config/quickshell
./install.sh --copy                       # copy repo -> ~/.config/quickshell
./install.sh --deps --link --yes          # non-interactive where safe
./install.sh --aur-helper paru --deps     # choose AUR helper
./install.sh --greeter                    # install greetd greeter (sudo, system-wide)
```

- Dependency auto-install currently targets **Arch Linux** (`pacman`, optional AUR helper). On other distributions, run `--print-deps` and install equivalents manually.
- `--link`/`--copy` back up an existing `~/.config/quickshell` before replacing it.

### Manual setup

1. Install dependencies for the modules you use (see `./install.sh --print-deps`).
2. Place this repository at `~/.config/quickshell` (or any path you prefer).
3. Ensure required services are running (examples):
   - `NetworkManager`
   - user session: `pipewire`, `pipewire-pulse`, `wireplumber`
4. (Optional) Start clipboard history watcher: `wl-paste --watch cliphist store`
5. Launch:
   ```bash
   qs -p ~/.config/quickshell/shell.qml
   # or, if installed as the default quickshell config directory:
   qs -c quickshell
   ```

## Usage

- Run the shell with `qs -p /path/to/quickshell/shell.qml`.
- **Control Center IPC toggle** (used by Niri keybind in this setup):
  ```bash
  qs -p ~/.config/quickshell ipc call controlcenter toggle
  ```
  Example Niri bind:
  ```kdl
  Mod+A { spawn "qs" "-p" "/home/<user>/.config/quickshell" "ipc" "call" "controlcenter" "toggle"; }
  ```
- Theming presets are managed from the Control Center (Matugen presets, wallpaper-derived theme, custom palettes). Matugen/wallpaper themes update `~/.config/quickshell/matugen-colors.json`.
- Bar style/presets and color preset state are persisted in local config/state files.

## Greeter (optional, greetd)

The greeter lives in `greeter/` and is installed system-wide by:

```bash
./install.sh --greeter
# or
cd greeter && ./deploy.sh
```

This installs files to `/etc/xdg/quickshell/greeter`, adds a polkit rule, and prints instructions for enabling `greetd`. Review the scripts before running on your system.

## Notes

- **Icons:** the UI relies heavily on Nerd Font glyphs (JetBrainsMono Nerd Font). Install a Nerd Font for correct icon rendering.
- **Hardware/tool-dependent features:** headphone battery and some device details are best-effort and may be unavailable depending on devices/backends.
- **State files:** `usage.json` and `matugen-colors.json` are runtime/user-local and ignored by git; `bar-config.json` and `color-presets.json` store preferences.
- **Compositor:** this config is tailored for a Niri/Wayland environment (workspace/layout integration, IPC/keybind workflow).

## License

This repository is licensed under the [MIT License](./LICENSE).
