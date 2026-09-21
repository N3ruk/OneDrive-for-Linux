#!/usr/bin/env bash
set -euo pipefail

APP_NAME="onedrive-rclone"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
BIN_HOME="${XDG_BIN_HOME:-$HOME/.local/bin}"

INSTALL_DIR="$DATA_HOME/$APP_NAME"
DESKTOP_FILE="$DATA_HOME/applications/montar_onedrive.desktop"
BIN_FILE="$BIN_HOME/montar_onedrive.sh"

remove_path() {
  local path="$1"
  if [ -e "$path" ]; then
    rm -rf "$path"
  fi
}

remove_path "$INSTALL_DIR"
remove_path "$DESKTOP_FILE"
remove_path "$BIN_FILE"

echo "Desinstalado:"
echo "  $INSTALL_DIR"
echo "  $DESKTOP_FILE"
echo "  $BIN_FILE"
