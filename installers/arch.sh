#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"
msg "Instalando dependencias para Arch Linux y derivadas..." "Installing dependencies for Arch Linux and derivatives..."
sudo_cmd pacman -S --needed --noconfirm \
  rclone python python-requests python-gobject gtk3 \
  libayatana-appindicator xdg-utils libnotify fuse3
