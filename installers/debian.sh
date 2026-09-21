#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"
log "Instalando dependencias para Debian/Ubuntu y derivadas..."
sudo_cmd apt-get update
sudo_cmd apt-get install -y \
  rclone python3 python3-requests python3-gi \
  gir1.2-ayatanaappindicator3-0.1 gir1.2-gtk-3.0 \
  xdg-utils libnotify-bin fuse3
