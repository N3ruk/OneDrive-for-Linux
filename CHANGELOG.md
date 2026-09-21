# Changelog

All notable changes to **OneDrive for Linux** are documented here.

## [1.5] - 2026-09-22

### Added
- Spanish / English language selection at the start of `install.sh`.
- Persistent language preference through `ONEDRIVE_LANG`.
- Full English interface for the graphical OneDrive / rclone setup assistant.
- Full English support for the tray menu, notifications, transfer progress window and status messages.
- The generated desktop launcher now uses the description that matches the language selected during installation.
- Localized installer output for Debian/Ubuntu, Arch, Fedora, openSUSE, SteamOS and generic Linux installations.
- `VERSION` file identifying this release as **1.5**.

### Preserved
- Original rclone mount workflow and mount parameters.
- Automatic OneDrive remote detection and graphical first-run configuration.
- Microsoft OAuth authentication through rclone.
- Cache management and transfer progress monitoring.
- Tray status icons for connected, synchronizing and disconnected states.
- **Exit** behavior: unmount OneDrive, stop the matching `rclone mount` process and close the tray indicator.
- SteamOS / Steam Deck installation behavior.

### Notes
- Selecting English changes only the displayed language. It does not change rclone configuration, mount behavior, cache settings or OneDrive functionality.
- The selected language is stored in `~/.config/onedrive-rclone/settings.env` together with the selected OneDrive remote.
