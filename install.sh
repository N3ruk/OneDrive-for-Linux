#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="onedrive-rclone"
APP_TITLE="OneDrive"

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
BIN_HOME="${XDG_BIN_HOME:-$HOME/.local/bin}"

INSTALL_DIR="$DATA_HOME/$APP_NAME"
BIN_DIR="$BIN_HOME"
DESKTOP_DIR="$DATA_HOME/applications"

OS_ID=""
OS_LIKE=""
DETECTED_PRETTY="Linux"
if [ -r /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  OS_ID="${ID:-}"
  OS_LIKE="${ID_LIKE:-}"
  DETECTED_PRETTY="${PRETTY_NAME:-${ID:-Linux}}"
fi

os_family() {
  local id="$OS_ID" like="$OS_LIKE"
  if [ "$id" = "steamos" ] || [ "$id" = "holo" ]; then echo steamos; return; fi
  case " $id $like " in
    *" debian "*|*" ubuntu "*) echo debian ;;
    *" arch "*) echo arch ;;
    *" fedora "*|*" rhel "*) echo fedora ;;
    *" opensuse "*|*" suse "*) echo opensuse ;;
    *) echo generic ;;
  esac
}

family="$(os_family)"
installer="$PROJECT_ROOT/installers/$family.sh"
[ -x "$installer" ] || installer="$PROJECT_ROOT/installers/generic.sh"

cat <<EOF2
==============================================
 Instalador de OneDrive (rclone)
==============================================

Distribución detectada: ${DETECTED_PRETTY:-Linux}
Perfil de instalación: $family

El programa conservará el mismo funcionamiento y los mismos parámetros de
montaje. Este asistente solo prepara las dependencias necesarias y rclone.
EOF2

read -r -p "¿Instalar/verificar dependencias y rclone para esta distribución? [S/n]: " answer
case "$answer" in
  n|N|no|NO) echo "Se omite la instalación de dependencias." ;;
  *)
    if ! "$installer"; then
      echo >&2
      echo "AVISO: no se pudieron instalar todas las dependencias automáticamente." >&2
      read -r -p "¿Instalar igualmente los archivos de OneDrive? [S/n]: " continue_answer
      case "$continue_answer" in n|N|no|NO) exit 1 ;; esac
    fi
    ;;
esac

mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$DESKTOP_DIR" "$INSTALL_DIR/installers"

install -Dm755 "$PROJECT_ROOT/bin/montar_onedrive.sh" "$BIN_DIR/montar_onedrive.sh"
install -Dm755 "$PROJECT_ROOT/bin/setup_rclone.sh" "$INSTALL_DIR/setup_rclone.sh"
install -Dm755 "$PROJECT_ROOT/src/onedrive_indicator.py" "$INSTALL_DIR/onedrive_indicator.py"
install -Dm755 "$PROJECT_ROOT/uninstall.sh" "$INSTALL_DIR/uninstall.sh"
install -Dm644 "$PROJECT_ROOT/assets/onedrive.png" "$INSTALL_DIR/onedrive.png"
install -Dm644 "$PROJECT_ROOT/assets/onedrive1.png" "$INSTALL_DIR/onedrive1.png"
cp -a "$PROJECT_ROOT/installers/." "$INSTALL_DIR/installers/"
chmod 755 "$INSTALL_DIR/installers/"*.sh

cat > "$DESKTOP_DIR/montar_onedrive.desktop" <<EOF2
[Desktop Entry]
Name=$APP_TITLE
Comment=Montar OneDrive con rclone y mostrar indicador
Exec=$BIN_DIR/montar_onedrive.sh
Icon=$INSTALL_DIR/onedrive.png
Terminal=false
Type=Application
Categories=Utility;
StartupNotify=false
EOF2

chmod 755 "$BIN_DIR/montar_onedrive.sh"
chmod 755 "$INSTALL_DIR/setup_rclone.sh"
chmod 755 "$INSTALL_DIR/onedrive_indicator.py"
chmod 755 "$INSTALL_DIR/uninstall.sh"

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
fi

echo
echo "Instalado en:"
echo "  $INSTALL_DIR"
echo "  $BIN_DIR/montar_onedrive.sh"
echo "  $INSTALL_DIR/uninstall.sh"
echo "  $DESKTOP_DIR/montar_onedrive.desktop"
echo

export PATH="$BIN_DIR:$PATH"
SETUP="$INSTALL_DIR/setup_rclone.sh"
if ! command -v rclone >/dev/null 2>&1 || ! rclone listremotes 2>/dev/null | grep -q .; then
  read -r -p "rclone todavía no está configurado. ¿Abrir ahora el asistente de OneDrive? [S/n]: " setup_answer
  case "$setup_answer" in
    n|N|no|NO)
      echo "Se abrirá automáticamente la primera vez que ejecutes OneDrive." ;;
    *) "$SETUP" --interactive ;;
  esac
fi

echo
echo "Instalación terminada. El lanzador aparecerá como: OneDrive"
