# OneDrive for Linux Desktop — rclone tray client for Ubuntu, SteamOS, Arch, Fedora and openSUSE

[Versión en español](README_ES.md)

A lightweight **OneDrive desktop client for Linux** built around **rclone**, with a system tray indicator, mount/unmount control, transfer progress, cache tools and first-run setup. It keeps OneDrive mounted as a normal folder while providing a desktop experience similar to a native sync client.

This project is designed for **Ubuntu, Debian, SteamOS / Steam Deck, Arch Linux, Fedora, openSUSE and other desktop Linux distributions**.

## Features

- Mounts Microsoft OneDrive with `rclone mount`.
- One-click launcher shown as **OneDrive** in the application menu.
- System tray indicator with live connection state.
- Tray icon states for online / idle, synchronizing, and disconnected / rclone RC unavailable.
- Open the local OneDrive folder from the tray.
- Open OneDrive on the web and the OneDrive recycle bin.
- Show active transfer progress as a notification or GTK progress window.
- View and clear the local rclone cache.
- Automatic cache-size warning.
- Clean exit: unmounts OneDrive, stops the matching `rclone mount` process and closes the tray indicator.
- First-run helper for installing and configuring rclone.
- Automatic Linux distribution detection.
- Distribution-specific dependency installers.
- SteamOS-friendly rclone installation.
- Automatic detection of existing rclone remotes using the `onedrive` backend.

## Supported Linux distributions

The installer includes dedicated profiles for:

- Ubuntu and Debian-based distributions (`apt`)
- Arch Linux and derivatives (`pacman`)
- Fedora / RHEL-family systems (`dnf`)
- openSUSE (`zypper`)
- SteamOS / Steam Deck
- Generic Linux fallback

The application uses GTK 3 with Ayatana AppIndicator when available, and falls back to AppIndicator3 on compatible distributions.

## How it works

The launcher runs `bin/montar_onedrive.sh`. If rclone and a OneDrive remote are already configured, the script preserves the normal workflow and mounts OneDrive using the project defaults.

The mount uses rclone VFS cache mode and enables the rclone Remote Control API so the tray indicator can display transfer state and progress.

Default mount options include:

```text
--rc
--rc-no-auth
--vfs-cache-mode full
--dir-cache-time 5m
--poll-interval 1m
--allow-non-empty
--volname OneDrive
--vfs-cache-max-size 150G
--vfs-cache-max-age 720h
```

If rclone is missing or no OneDrive remote is configured, the setup helper starts before the normal launcher continues.

## Installation

Clone or download the repository, then run:

```bash
chmod +x install.sh
./install.sh
```

The installer detects the current distribution, offers to install the required dependencies and installs the application in user-local directories.

Main installation paths:

```text
~/.local/share/onedrive-rclone
~/.local/bin/montar_onedrive.sh
~/.local/share/applications/montar_onedrive.desktop
```

After installation, launch **OneDrive** from your desktop application menu.

## First-time rclone configuration

If rclone is not installed or OneDrive has not been configured yet, the application starts its setup helper. It detects the Linux distribution, installs rclone when required, detects existing `rclone` remotes using `type = onedrive`, lets you choose the remote if more than one exists, stores the selected remote name, and returns to the regular OneDrive launcher.

Microsoft account authorization is handled by rclone through the normal browser-based OAuth flow.

## Steam Deck / SteamOS

The project includes a SteamOS-specific installer. When possible, rclone is installed in the user's local environment instead of relying on permanent changes to SteamOS's read-only system image.

Run the installer from **Desktop Mode**:

```bash
chmod +x install.sh
./install.sh
```

Once installed, **OneDrive** appears in the application launcher.

## Tray menu

- **Abrir carpeta OneDrive** — opens the mounted OneDrive folder.
- **Ver OneDrive en línea** — opens OneDrive in the browser.
- **Papelera de reciclaje** — opens the OneDrive web recycle bin.
- **Caché** — clear the rclone cache or display its current size.
- **Ver progreso** — show a transfer notification or GTK progress window with file, percentage, speed and ETA.
- **Salir** — unmounts OneDrive, stops the matching rclone mount and closes the tray application.

## Tray status icons

- **OneDrive icon**: mounted, connected and idle.
- **Synchronizing icon**: one or more transfers are active.
- **Warning icon**: the mount is unavailable or the rclone RC endpoint is not responding.

## Configuration

Environment variables can override the defaults:

```text
ONEDRIVE_REMOTE
ONEDRIVE_MOUNTPOINT
ONEDRIVE_CACHE_DIR
ONEDRIVE_LOGFILE
ONEDRIVE_INDICATOR
ONEDRIVE_RC_URL
ONEDRIVE_CACHE_THRESHOLD
ONEDRIVE_NOTIFY_INTERVAL
```

Defaults:

```text
Remote:      Onedrive:
Mount point: ~/OneDrive
Cache:       ~/.cache/rclone
RC URL:      http://localhost:5572/core/stats
```

## Uninstall

```bash
~/.local/share/onedrive-rclone/uninstall.sh
```

## Project structure

```text
ONEDRIVE-Desktop/
├── assets/
├── bin/
│   ├── montar_onedrive.sh
│   └── setup_rclone.sh
├── desktop/
├── installers/
├── src/
│   └── onedrive_indicator.py
├── install.sh
├── uninstall.sh
├── README.md
└── README_ES.md
```

## Requirements

Core runtime requirements are rclone, Python 3, GTK 3 / PyGObject, an AppIndicator implementation, `requests`, `xdg-open`, `notify-send` and FUSE utilities. The installer attempts to provide the correct packages for the detected distribution.

## License

MIT — see [LICENSE](LICENSE).

## Keywords

OneDrive Linux, OneDrive Ubuntu, OneDrive Steam Deck, OneDrive SteamOS, OneDrive Arch Linux, OneDrive Fedora, OneDrive openSUSE, rclone OneDrive, Linux system tray OneDrive, OneDrive mount Linux, Microsoft OneDrive Linux desktop client.
