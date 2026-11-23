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
| Theming / wallpaper | `matugen`, `waypaper` (optional, for wallpaper-derived preset) | Color presets, wallpaper theme |
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
- Theming presets are managed from the Control Center (Matugen presets, wallpaper-derived theme, custom palettes). Matugen/wallpaper themes update `${XDG_CACHE_HOME:-~/.cache}/quickshell/matugen-colors.json`.
- Bar style/presets and color preset state are persisted in XDG config/state files (see Configuration files below).

## Configuration

### `bar-config.json`

Stored at `${XDG_CONFIG_HOME:-~/.config}/quickshell/bar-config.json` (defaults: `bar-config.default.json`).

| Field | Type | Description |
|---|---|---|
| `configVersion` | number | Config schema version (current: `2`). |
| `style` | string | Bar style: `islands`, `monolithic`, or `full`. |
| `activePreset` | string | Active preset id (`my_islands`, `monolithic`, `full`, or user preset). |
| `userPresets` | object | User-saved presets. |
| `moduleOrder` | object | Module ids per section: `left`, `center`, `right`. |
| `hiddenModules` | array | Module ids hidden from the bar. |

Known module ids from `BarConfig.qml`: `workspaces`, `mpris`, `clock`, `volume`, `sysmon`, `layout`, `network`, `tray`, `power`.

### Color presets

Color preset selection is stored in `${XDG_CONFIG_HOME:-~/.config}/quickshell/color-presets.json` (defaults: `color-presets.default.json`):

- `active`: preset id selected in Control Center.
- `wallpaperMode`: `dark` or `light` for wallpaper-derived Matugen mode.

Built-in presets are defined in `ControlCenter.qml` (Matugen seed presets, custom palettes like Stone Trio, and wallpaper-derived preset).

### Adding a module

1. Create a module component (usually `*Module.qml`) and expose a compact bar API (`implicitWidth/implicitHeight`, popup hooks/properties as needed).
2. Register it in `shell.qml` as a bar island/item with a `moduleId` and layout anchoring compatible with `BarConfig.visibleOrder(...)`.
3. Add module metadata/id to `BarConfig.qml` (`defaultModuleOrder`, `moduleMeta`, and any layout expectations).
4. If it needs Control Center controls, add a page/section in `ControlCenter.qml` and wire service/singleton state.
5. Run `qmllint` for touched QML files and verify in a running `qs` session.

## IPC

Quickshell IPC targets exposed by `IpcHandler`:

| Target | Function | Example |
|---|---|---|
| `controlcenter` | `toggle()` | `qs -p "$XDG_CONFIG_HOME/quickshell" ipc call controlcenter toggle` |
| `launcher` | `toggle()` | `qs -p "$XDG_CONFIG_HOME/quickshell" ipc call launcher toggle` |
| `clipboard` | `toggle()` | `qs -p "$XDG_CONFIG_HOME/quickshell" ipc call clipboard toggle` |
| `powermenu` | `toggle()` | `qs -p "$XDG_CONFIG_HOME/quickshell" ipc call powermenu toggle` |
| `networkpopup` | `toggle()` | `qs -p "$XDG_CONFIG_HOME/quickshell" ipc call networkpopup toggle` |
| `audiopopup` | `toggle()` | `qs -p "$XDG_CONFIG_HOME/quickshell" ipc call audiopopup toggle` |
| `playerpopup` | `toggle()` | `qs -p "$XDG_CONFIG_HOME/quickshell" ipc call playerpopup toggle` |
| `calendar` | `toggle()` | `qs -p "$XDG_CONFIG_HOME/quickshell" ipc call calendar toggle` |
| `weather` | `toggle()` | `qs -p "$XDG_CONFIG_HOME/quickshell" ipc call weather toggle` |
| `thememenu` | `toggle()` | `qs -p "$XDG_CONFIG_HOME/quickshell" ipc call thememenu toggle` |

### Niri keybinds (example)

```kdl
binds {
    Mod+A { spawn "qs" "-p" "~/.config/quickshell" "ipc" "call" "controlcenter" "toggle"; }
    Mod+Space { spawn "qs" "-p" "~/.config/quickshell" "ipc" "call" "launcher" "toggle"; }
    Mod+V { spawn "qs" "-p" "~/.config/quickshell" "ipc" "call" "clipboard" "toggle"; }
}
```

Adjust paths/binds to your local setup.

## Weather

Weather implementation is code-backed in `WeatherModule.qml` / `WeatherPopup.qml`:

- **Provider/request**: `curl -s --max-time 10 'https://wttr.in/<city-or-empty>?M&format=%C|%t|%f|%h|%w|%l&lang=ru'` (`M` forces metric units; `lang=ru` requests Russian condition text)
- **API key**: none used by current code.
- **City**: optional `city` property in `WeatherModule.qml`; empty value uses wttr.in default/location behavior as returned by wttr.in.
- **Refresh**: every 15 minutes (`Timer interval: 15 * 60 * 1000`) and on popup open when stale/missing.
- **Data sent externally**: HTTPS request to `wttr.in`; when `city` is set, it is included in the URL path. No additional API key is sent by this code. Exact geolocation/IP behavior is determined by wttr.in and is not asserted here.
- **TODO**: Confirm/document preferred default city or privacy wording if you want stricter wording than the code-level description above.

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

## Troubleshooting

- **Missing icons/glyphs/squares**: install a Nerd Font (JetBrainsMono Nerd Font recommended) and an emoji font; restart Quickshell after font changes.
- **No audio controls/devices**: verify PipeWire/WirePlumber user services are running. Current code uses `wpctl set-mute @DEFAULT_SOURCE@ toggle` for microphone mute toggles and `pactl get-default-sink`/`pactl info`/`pactl list sinks` for sink enumeration/default detection in audio UI (see `VolumeModule.qml`, `ControlCenter.qml`, `AudioPopup.qml`).
- **No network info**: verify `NetworkManager` is running and `nmcli` is available.
- **Clipboard history empty**: start a watcher such as `wl-paste --watch cliphist store`.
- **Wallpaper theme not applied**: check `waypaper` config (`~/.config/waypaper/config.ini`) and `matugen` availability.

## Uninstall

```bash
# Remove symlinked/copied config target
rm -rf "${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"

# Optional: remove runtime state/cache
rm -rf "${XDG_STATE_HOME:-$HOME/.local/state}/quickshell"
rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/quickshell"

# If greeter was installed:
cd /path/to/repo/greeter && ./deploy.sh --uninstall
```

If you used `--copy`, remove the copied target; if you used `--link`, removing the symlink does not delete the source repo.

## Verified versions

- Quickshell: TODO (not determinable from repository code; please provide tested version).
- Niri: TODO (not determinable from repository code; please provide tested version).

## Credits

- [Quickshell](https://quickshell.outfoxxed.me/) for the shell framework.
- [Niri](https://github.com/YaLTeR/niri) for compositor integration/workflow assumptions.
- [Matugen](https://github.com/InioX/matugen) for palette generation.
- Catppuccin/Mocha-inspired defaults and other preset names referenced in code/UI.

## Screenshots

<!-- TODO: Capture screenshot: full desktop bar in islands style -->
![Bar - islands style](docs/screenshots/bar-islands.png)

<!-- TODO: Capture screenshot: Control Center open on Sound/Colors page -->
![Control Center](docs/screenshots/control-center.png)

<!-- TODO: Capture screenshot: App launcher with search/result badges -->
![Launcher](docs/screenshots/launcher.png)

## Notes

- **Icons:** the UI relies heavily on Nerd Font glyphs (JetBrainsMono Nerd Font). Install a Nerd Font for correct icon rendering.
- **Hardware/tool-dependent features:** headphone battery and some device details are best-effort and may be unavailable depending on devices/backends.
- **State files:** runtime files live in XDG config/state/cache directories; repository `*.default.json` files are templates/defaults.
- **Compositor:** this config is tailored for a Niri/Wayland environment (workspace/layout integration, IPC/keybind workflow).

## License

This repository is licensed under the [MIT License](./LICENSE).
