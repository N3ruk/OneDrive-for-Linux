#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"
log "Instalando dependencias para Fedora y derivadas..."
sudo_cmd dnf install -y \
  rclone python3 python3-requests python3-gobject gtk3 \
  libayatana-appindicator-gtk3 xdg-utils libnotify fuse3
