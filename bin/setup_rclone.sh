#!/usr/bin/env bash
set -euo pipefail

APP_NAME="onedrive-rclone"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
BIN_HOME="${XDG_BIN_HOME:-$HOME/.local/bin}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
INSTALL_DIR="$DATA_HOME/$APP_NAME"
SETTINGS_FILE="$CONFIG_HOME/$APP_NAME/settings.env"
GUI="$INSTALL_DIR/setup_rclone_gui.py"

export PATH="$BIN_HOME:$PATH"

if [ -z "${ONEDRIVE_LANG+x}" ] && [ -r "$SETTINGS_FILE" ]; then
  raw="$(grep -m1 '^ONEDRIVE_LANG=' "$SETTINGS_FILE" 2>/dev/null | cut -d= -f2- || true)"
  if [ -n "$raw" ]; then eval "ONEDRIVE_LANG=$raw"; fi
fi
ONEDRIVE_LANG="${ONEDRIVE_LANG:-es}"
export ONEDRIVE_LANG

if [ ! -f "$GUI" ]; then
  if [ "$ONEDRIVE_LANG" = "en" ]; then
    echo "OneDrive graphical setup assistant not found: $GUI" >&2
  else
    echo "No se encuentra el asistente gráfico de OneDrive: $GUI" >&2
  fi
  exit 1
fi

exec python3 "$GUI" "$@"
