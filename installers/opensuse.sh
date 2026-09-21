#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"
msg "Instalando dependencias para openSUSE..." "Installing dependencies for openSUSE..."
# Tumbleweed provides AppIndicator3; the program accepts Ayatana or AppIndicator3.
sudo_cmd zypper --non-interactive install \
  rclone python3 python3-requests python3-gobject \
  typelib-1_0-Gtk-3_0 libappindicator3-1 typelib-1_0-AppIndicator3-0_1 \
  xdg-utils libnotify-tools fuse3
