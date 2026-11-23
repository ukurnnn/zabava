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
- Defaults in repo: `*.default.json`; runtime state/config/cache are created in XDG directories on first run

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

Clone the repository to a neutral location, then install/link it into your Quickshell config directory:

```bash
git clone https://github.com/<owner>/<repo>.git ~/src/quickshell-config
cd ~/src/quickshell-config
./install.sh --all
```

> Replace the clone URL with your repository URL/fork. The installer links or copies the source directory to `${XDG_CONFIG_HOME:-~/.config}/quickshell` by default. Do not clone directly into the target config directory if you plan to use `--link`.

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
- `--link`/`--copy` refuse to operate when source and target are the same path, and create a timestamped backup before replacing an existing target.

### Manual setup

1. Install dependencies for the modules you use (see `./install.sh --print-deps`).
2. Clone this repository to a neutral directory (for example `~/src/quickshell-config`).
3. Link or copy it to `${XDG_CONFIG_HOME:-~/.config}/quickshell`:
   ```bash
   ./install.sh --link
   # or
   ./install.sh --copy
   ```
4. Ensure required services are running (examples):
   - `NetworkManager`
   - user session: `pipewire`, `pipewire-pulse`, `wireplumber`
5. (Optional) Start clipboard history watcher: `wl-paste --watch cliphist store`
6. Launch:
   ```bash
   qs -p "${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/shell.qml"
   # or, if installed as the default quickshell config directory:
   qs -c quickshell
   ```

## Usage

- Run the shell with `qs -p /path/to/quickshell/shell.qml`.
- **Control Center IPC toggle** (used by Niri keybind in this setup):
  ```bash
  qs -p "${XDG_CONFIG_HOME:-$HOME/.config}/quickshell" ipc call controlcenter toggle
  ```
  Example Niri bind:
  ```kdl
  Mod+A { spawn "qs" "-p" "~/.config/quickshell" "ipc" "call" "controlcenter" "toggle"; }
  ```
- Theming presets are managed from the Control Center (Matugen presets, wallpaper-derived theme, custom palettes). Matugen/wallpaper themes update `${XDG_CACHE_HOME:-~/.cache}/quickshell/matugen-colors.json`.
- Bar style/presets and color preset state are persisted in XDG config/state files (see Configuration files below).

## Greeter (optional, greetd)

The greeter lives in `greeter/` and is intended for a `greetd` + Niri + Quickshell setup.

### What gets installed system-wide

`./install.sh --greeter` (or `cd greeter && ./deploy.sh --install`) installs:

| Path | Purpose |
|---|---|
| `/etc/xdg/quickshell/greeter/launch.sh` | Greeter launcher run by greetd |
| `/etc/xdg/quickshell/greeter/shell.qml` | Greeter UI |
| `/etc/polkit-1/rules.d/50-greeter.rules` | Polkit rule for greeter power actions |

`deploy.sh` also restarts polkit (best effort) and prints manual `greetd` enable/rollback instructions. It does **not** automatically enable/disable display managers.

### Polkit rule (from code)

`greeter/50-greeter.rules` allows user `greeter` to perform these login1 actions without password authentication:

- `org.freedesktop.login1.reboot`
- `org.freedesktop.login1.reboot-multiple-sessions`
- `org.freedesktop.login1.power-off`
- `org.freedesktop.login1.power-off-multiple-sessions`

Review the rule before installing on multi-user or security-sensitive systems.

### Uninstall

```bash
cd greeter
./deploy.sh --uninstall
```

This removes only the known greeter files/rule managed by `deploy.sh`. If you enabled `greetd`, disable it and re-enable your display manager manually.

## Configuration files

Defaults are shipped in the repository as `*.default.json`. On first run, the shell falls back to defaults and creates runtime files in XDG directories.

| File | Purpose | Default in repo | Runtime location |
|---|---|---|---|
| `bar-config.json` | Bar style, presets, module order/visibility | `bar-config.default.json` | `${XDG_CONFIG_HOME:-~/.config}/quickshell/bar-config.json` |
| `color-presets.json` | Active color preset and wallpaper color mode | `color-presets.default.json` | `${XDG_CONFIG_HOME:-~/.config}/quickshell/color-presets.json` |
| `ui-style.json` | Glass/style UI settings | `ui-style.default.json` | `${XDG_CONFIG_HOME:-~/.config}/quickshell/ui-style.json` |
| `usage.json` | Launcher frecency/usage history | `usage.default.json` | `${XDG_STATE_HOME:-~/.local/state}/quickshell/usage.json` |
| `matugen-colors.json` | Generated Matugen palette/cache | `matugen-colors.default.json` | `${XDG_CACHE_HOME:-~/.cache}/quickshell/matugen-colors.json` |

To reset a specific area, remove the corresponding runtime file and restart/reload Quickshell; defaults will be used again.

## Notes

- **Icons:** the UI relies heavily on Nerd Font glyphs (JetBrainsMono Nerd Font). Install a Nerd Font for correct icon rendering.
- **Hardware/tool-dependent features:** headphone battery and some device details are best-effort and may be unavailable depending on devices/backends.
- **State files:** runtime files live in XDG config/state/cache directories; repository `*.default.json` files are templates/defaults.
- **Compositor:** this config is tailored for a Niri/Wayland environment (workspace/layout integration, IPC/keybind workflow).

## License

This repository is licensed under the [MIT License](./LICENSE).
