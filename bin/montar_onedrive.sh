#!/usr/bin/env bash
set -euo pipefail

APP_NAME="onedrive-rclone"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
SETTINGS_FILE="$CONFIG_HOME/$APP_NAME/settings.env"
BIN_HOME="${XDG_BIN_HOME:-$HOME/.local/bin}"
SETUP_SCRIPT="${ONEDRIVE_SETUP_SCRIPT:-$HOME/.local/share/$APP_NAME/setup_rclone.sh}"

if [ -z "${ONEDRIVE_REMOTE+x}" ] && [ -r "$SETTINGS_FILE" ]; then
  # shellcheck disable=SC1090
  . "$SETTINGS_FILE"
fi

export PATH="$BIN_HOME:$PATH"

REMOTE_NAME="${ONEDRIVE_REMOTE:-Onedrive:}"
MOUNTPOINT="${ONEDRIVE_MOUNTPOINT:-$HOME/OneDrive}"
CACHE_DIR="${ONEDRIVE_CACHE_DIR:-$HOME/.cache/rclone}"
LOGFILE="${ONEDRIVE_LOGFILE:-$HOME/.local/state/$APP_NAME/rclone.log}"
INDICATOR="${ONEDRIVE_INDICATOR:-$HOME/.local/share/$APP_NAME/onedrive_indicator.py}"

remote_is_configured() {
  command -v rclone >/dev/null 2>&1 || return 1
  rclone config show "${REMOTE_NAME%:}" >/dev/null 2>&1 || return 1
  rclone config show "${REMOTE_NAME%:}" 2>/dev/null |     grep -Eq '^[[:space:]]*type[[:space:]]*=[[:space:]]*onedrive[[:space:]]*$'
}

if [ "${ONEDRIVE_SKIP_SETUP:-0}" != "1" ]; then
  if ! command -v rclone >/dev/null 2>&1 || ! remote_is_configured; then
    if [ -x "$SETUP_SCRIPT" ]; then
      "$SETUP_SCRIPT" --from-launcher
      exit $?
    fi
    echo "rclone no está instalado/configurado y no se encuentra el asistente: $SETUP_SCRIPT" >&2
    exit 1
  fi
fi

mkdir -p "$MOUNTPOINT" "$(dirname "$LOGFILE")" "$CACHE_DIR"

if mountpoint -q "$MOUNTPOINT"; then
  echo "OneDrive ya está montado en $MOUNTPOINT"
else
  nohup rclone mount "$REMOTE_NAME" "$MOUNTPOINT"     --rc     --rc-no-auth     --vfs-cache-mode full     --dir-cache-time 5m     --poll-interval 1m     --allow-non-empty     --volname "OneDrive"     --vfs-cache-max-size 150G     --vfs-cache-max-age 720h     >"$LOGFILE" 2>&1 &

  sleep 2

  if mountpoint -q "$MOUNTPOINT"; then
    echo "OneDrive montado en $MOUNTPOINT"
  else
    echo "No se pudo montar OneDrive. Revisa $LOGFILE"
    exit 1
  fi
fi

xdg-open "$MOUNTPOINT" >/dev/null 2>&1 &

if [ -x "$INDICATOR" ] && ! pgrep -f "$INDICATOR" >/dev/null 2>&1; then
  nohup "$INDICATOR" >/dev/null 2>&1 &
fi
