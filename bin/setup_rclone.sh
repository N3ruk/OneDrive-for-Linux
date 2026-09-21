#!/usr/bin/env bash
set -euo pipefail

APP_NAME="onedrive-rclone"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
BIN_HOME="${XDG_BIN_HOME:-$HOME/.local/bin}"
INSTALL_DIR="$DATA_HOME/$APP_NAME"
GUI="$INSTALL_DIR/setup_rclone_gui.py"

export PATH="$BIN_HOME:$PATH"

if [ ! -f "$GUI" ]; then
  echo "No se encuentra el asistente gráfico de OneDrive: $GUI" >&2
  exit 1
fi

exec python3 "$GUI" "$@"
