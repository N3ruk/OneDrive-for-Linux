# OneDrive Rclone — v1.5

**English** | [Español](README_ES.md)

A GTK/Ayatana indicator that mounts OneDrive through **rclone**, preserving the original mount workflow while adding cross-distribution installation and a graphical first-run setup assistant.

## How it works

Opening the **OneDrive** launcher:

1. Checks that rclone is available and a valid OneDrive remote exists.
2. Opens the graphical first-run assistant if configuration is missing.
3. Starts the original mount workflow once the account is ready.
4. Opens `~/OneDrive` and starts the tray indicator.

The original mount settings are preserved: `--vfs-cache-mode full`, `--dir-cache-time 5m`, `--poll-interval 1m`, `--allow-non-empty`, `--vfs-cache-max-size 150G`, `--vfs-cache-max-age 720h` and the indicator's RC server.

## Languages

Since **v1.5**, `install.sh` offers **Español** and **English**. The choice persists in `~/.config/onedrive-rclone/settings.env` and applies to the installer, graphical rclone/OneDrive assistant, tray menu, notifications, status/progress window and helper messages. It changes display language only, not mount behavior or account settings.

## Install

Clone/download the repository, open its directory and run:

```sh
bash install.sh
```

The installer detects the distribution family and prepares dependencies:

| Distribution | Installation method |
| --- | --- |
| Debian / Ubuntu derivatives | APT |
| Arch / Manjaro derivatives | pacman |
| SteamOS | Portable rclone in `~/.local/bin`; GTK/Ayatana dependency checks |
| Fedora derivatives | dnf |
| openSUSE | zypper |
| Other distributions | Portable rclone and dependency checks |

Installation does **not** configure your OneDrive account. Account setup appears only when you open the OneDrive icon and no valid remote exists.

Main installed locations:

- `~/.local/share/onedrive-rclone`
- `~/.local/bin/montar_onedrive.sh`
- `~/.local/share/applications/montar_onedrive.desktop`

## Graphical first-run setup

The assistant uses rclone's non-interactive configuration protocol without exposing a terminal. Normal settings are hidden and predefined: new remote `onedrive` (or `onedrive-2`, etc. if occupied), backend `onedrive`, empty `client_id` / `client_secret` / `tenant`, default `global` region, no advanced configuration, local-browser authentication and **OneDrive Personal or Business** connection type.

Usually you only need to:

1. Click **Connect Microsoft account**.
2. Sign in and authorize rclone in your browser.
3. Choose a drive only if OneDrive (personal) cannot be identified unambiguously.
4. Click **Finish and open OneDrive**.

rclone manages OAuth tokens directly in its own configuration. This application does not display them or copy them into its settings. An existing single OneDrive remote is reused; multiple remotes produce a graphical selection.

## Indicator menu

- **Open OneDrive folder**: opens the mount point.
- **View OneDrive online**: opens the web interface.
- **Recycle bin**: opens OneDrive's web recycle bin.
- **Cache → Clear OneDrive cache**: deletes rclone cache contents.
- **Cache → Cache size**: reports cache usage.
- **View progress → Notification**: shows current transfers in a notification.
- **View progress → Progress bar**: opens the progress window.
- **Exit**: unmounts OneDrive, stops the corresponding `rclone mount` and closes the indicator.

## Tray status

Periodic checks show connected when mounted, rclone responds and Microsoft/OneDrive is reachable without active transfers; syncing during transfers; warning if the mount is lost, RC does not respond or the remote becomes unreachable. These checks do not change the mount workflow.

## Optional settings

| Variable | Purpose / default |
| --- | --- |
| `ONEDRIVE_REMOTE` | rclone remote |
| `ONEDRIVE_MOUNTPOINT` | Mount point; `~/OneDrive` |
| `ONEDRIVE_CACHE_DIR` | Cache directory; `~/.cache/rclone` |
| `ONEDRIVE_RC_URL` | RC URL; `http://localhost:5572/core/stats` |

## Uninstall

```sh
bash ~/.local/share/onedrive-rclone/uninstall.sh
```

## License

MIT. See [LICENSE](LICENSE) and [Changelog](CHANGELOG.md).
