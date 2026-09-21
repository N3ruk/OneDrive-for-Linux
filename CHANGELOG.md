# Changelog

## v1.0.0 — Universal Linux release

First public universal release of the project.

### Added
- Distribution-aware installation for Debian/Ubuntu, Arch, Fedora, openSUSE, SteamOS and generic Linux systems.
- rclone installation/configuration helper.
- Automatic detection and selection of existing OneDrive rclone remotes.
- SteamOS / Steam Deck installation path.
- Ayatana AppIndicator with AppIndicator3 fallback.
- Tray states for online/idle, synchronizing and disconnected/RC unavailable.
- English and Spanish documentation.

### Preserved
- Original rclone mount workflow and mount parameters.
- Existing tray menu, cache management and progress window.
- Exit behavior: unmount OneDrive, stop the matching rclone mount process and close the indicator.
