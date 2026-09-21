#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"
msg "Distribución no reconocida: se instalará rclone de forma portátil." "Unknown distribution: rclone will be installed as a portable binary."
if ! have_cmd rclone; then
  install_rclone_portable
fi
if ! python_indicator_check; then
  if is_en; then
    cat >&2 <<'MSG'
Indicator dependencies are missing. Install the equivalents of:
  Python 3 + PyGObject, GTK 3, AyatanaAppIndicator3 or AppIndicator3,
  python requests, xdg-utils, libnotify and FUSE 3.
The program will still be installed, but the tray icon requires these libraries.
MSG
  else
    cat >&2 <<'MSG'
Faltan dependencias del indicador. Instala en tu distribución los equivalentes a:
  Python 3 + PyGObject, GTK 3, AyatanaAppIndicator3 o AppIndicator3,
  python requests, xdg-utils, libnotify y FUSE 3.
El programa se instala igualmente, pero el icono de bandeja necesita esas bibliotecas.
MSG
  fi
fi
