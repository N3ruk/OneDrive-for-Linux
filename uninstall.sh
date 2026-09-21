#!/usr/bin/env bash
set -euo pipefail

APP_NAME="onedrive-rclone"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
BIN_HOME="${XDG_BIN_HOME:-$HOME/.local/bin}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

INSTALL_DIR="$DATA_HOME/$APP_NAME"
DESKTOP_FILE="$DATA_HOME/applications/montar_onedrive.desktop"
BIN_FILE="$BIN_HOME/montar_onedrive.sh"
SETTINGS_FILE="$CONFIG_HOME/$APP_NAME/settings.env"

ONEDRIVE_LANG="${ONEDRIVE_LANG:-}"
if [ -z "$ONEDRIVE_LANG" ] && [ -r "$SETTINGS_FILE" ]; then
  raw="$(grep -m1 '^ONEDRIVE_LANG=' "$SETTINGS_FILE" 2>/dev/null | cut -d= -f2- || true)"
  if [ -n "$raw" ]; then eval "ONEDRIVE_LANG=$raw"; fi
fi
ONEDRIVE_LANG="${ONEDRIVE_LANG:-es}"

remove_path() {
  local path="$1"
  if [ -e "$path" ]; then
    rm -rf "$path"
  fi
}

remove_path "$INSTALL_DIR"
remove_path "$DESKTOP_FILE"
remove_path "$BIN_FILE"

if [ "$ONEDRIVE_LANG" = "en" ]; then
  echo "Uninstalled:"
else
  echo "Desinstalado:"
fi
echo "  $INSTALL_DIR"
echo "  $DESKTOP_FILE"
echo "  $BIN_FILE"
