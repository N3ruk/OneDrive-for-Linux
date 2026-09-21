#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

msg "SteamOS detectado." "SteamOS detected."
msg "rclone se instalará de forma portátil en ~/.local/bin para no depender de la partición raíz de SteamOS." "rclone will be installed as a portable binary in ~/.local/bin so it does not depend on the SteamOS root partition."
if ! have_cmd rclone; then
  install_rclone_portable
else
  msg "rclone ya está disponible: $(command -v rclone)" "rclone is already available: $(command -v rclone)"
fi

if python_indicator_check >/dev/null 2>&1; then
  msg "Las dependencias GTK/AppIndicator ya están disponibles." "GTK/AppIndicator dependencies are already available."
  exit 0
fi

if is_en; then
  cat <<'MSG'
GTK/Ayatana indicator dependencies are missing.
On SteamOS these libraries belong to the base system. The assistant can install
them with pacman, but a major SteamOS update may remove them and this installer
would need to be run again.
MSG
  read -r -p "Install them now? [y/N]: " answer
else
  cat <<'MSG'
Faltan dependencias del indicador GTK/Ayatana.
En SteamOS estas bibliotecas pertenecen al sistema base. El asistente puede
instalarlas con pacman, pero una actualización grande de SteamOS podría
eliminarlas y habría que volver a ejecutar este instalador.
MSG
  read -r -p "¿Instalarlas ahora? [s/N]: " answer
fi
case "$answer" in
  s|S|si|SI|sí|Sí|y|Y|yes|YES)
    was_readonly="unknown"
    restore_readonly=0
    if command -v steamos-readonly >/dev/null 2>&1; then
      was_readonly="$(steamos-readonly status 2>/dev/null || true)"
      if printf '%s' "$was_readonly" | grep -qi enabled; then
        sudo_cmd steamos-readonly disable
        restore_readonly=1
        trap 'if [ "$restore_readonly" -eq 1 ]; then sudo_cmd steamos-readonly enable || true; fi' EXIT
      fi
    fi
    sudo_cmd pacman -S --needed --noconfirm \
      python python-requests python-gobject gtk3 \
      libayatana-appindicator xdg-utils libnotify fuse3
    if [ "$restore_readonly" -eq 1 ]; then
      sudo_cmd steamos-readonly enable || true
      restore_readonly=0
      trap - EXIT
    fi
    ;;
  *)
    warn "Se omite la instalación de dependencias GTK. El indicador no arrancará hasta instalarlas." "GTK dependency installation skipped. The indicator will not start until they are installed."
    ;;
esac
