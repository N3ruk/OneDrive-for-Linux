#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="onedrive-rclone"
APP_TITLE="OneDrive"
APP_VERSION="1.5"

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
BIN_HOME="${XDG_BIN_HOME:-$HOME/.local/bin}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

INSTALL_DIR="$DATA_HOME/$APP_NAME"
BIN_DIR="$BIN_HOME"
DESKTOP_DIR="$DATA_HOME/applications"
APP_CONFIG_DIR="$CONFIG_HOME/$APP_NAME"
SETTINGS_FILE="$APP_CONFIG_DIR/settings.env"

choose_language() {
  echo "=============================================="
  echo " OneDrive v$APP_VERSION"
  echo "=============================================="
  echo
  echo "Selecciona idioma / Select language:"
  echo "  1) Español"
  echo "  2) English"
  echo
  read -r -p "Opción / Option [1]: " lang_choice
  case "${lang_choice:-1}" in
    2|en|EN|english|English) ONEDRIVE_LANG="en" ;;
    *) ONEDRIVE_LANG="es" ;;
  esac
  export ONEDRIVE_LANG
}

save_language() {
  mkdir -p "$APP_CONFIG_DIR"
  local tmp
  tmp="$(mktemp)"
  if [ -r "$SETTINGS_FILE" ]; then
    grep -v '^ONEDRIVE_LANG=' "$SETTINGS_FILE" > "$tmp" || true
  fi
  printf 'ONEDRIVE_LANG=%s\n' "$ONEDRIVE_LANG" >> "$tmp"
  mv "$tmp" "$SETTINGS_FILE"
  chmod 600 "$SETTINGS_FILE"
}

say() {
  if [ "$ONEDRIVE_LANG" = "en" ]; then printf '%s\n' "$2"; else printf '%s\n' "$1"; fi
}

ask_yes_default() {
  local es="$1" en="$2" answer
  if [ "$ONEDRIVE_LANG" = "en" ]; then
    read -r -p "$en [Y/n]: " answer
    case "$answer" in n|N|no|NO) return 1 ;; *) return 0 ;; esac
  else
    read -r -p "$es [S/n]: " answer
    case "$answer" in n|N|no|NO) return 1 ;; *) return 0 ;; esac
  fi
}

choose_language
save_language

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

echo
say "Instalador de OneDrive (rclone)" "OneDrive installer (rclone)"
say "Distribución detectada: ${DETECTED_PRETTY:-Linux}" "Detected distribution: ${DETECTED_PRETTY:-Linux}"
say "Perfil de instalación: $family" "Installation profile: $family"
echo
say \
  "El programa conservará el mismo funcionamiento y los mismos parámetros de montaje. Este asistente solo prepara las dependencias necesarias y rclone." \
  "The program will keep the same behavior and mount parameters. This assistant only prepares the required dependencies and rclone."
echo

if ask_yes_default "¿Instalar/verificar dependencias y rclone para esta distribución?" "Install/verify dependencies and rclone for this distribution?"; then
  if ! "$installer"; then
    echo >&2
    say "AVISO: no se pudieron instalar todas las dependencias automáticamente." "WARNING: not all dependencies could be installed automatically." >&2
    if ! ask_yes_default "¿Instalar igualmente los archivos de OneDrive?" "Install the OneDrive files anyway?"; then
      exit 1
    fi
  fi
else
  say "Se omite la instalación de dependencias." "Dependency installation skipped."
fi

mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$DESKTOP_DIR" "$INSTALL_DIR/installers"

install -Dm755 "$PROJECT_ROOT/bin/montar_onedrive.sh" "$BIN_DIR/montar_onedrive.sh"
install -Dm755 "$PROJECT_ROOT/bin/setup_rclone.sh" "$INSTALL_DIR/setup_rclone.sh"
install -Dm755 "$PROJECT_ROOT/src/i18n.py" "$INSTALL_DIR/i18n.py"
install -Dm755 "$PROJECT_ROOT/src/onedrive_indicator.py" "$INSTALL_DIR/onedrive_indicator.py"
install -Dm755 "$PROJECT_ROOT/src/setup_rclone_gui.py" "$INSTALL_DIR/setup_rclone_gui.py"
install -Dm755 "$PROJECT_ROOT/uninstall.sh" "$INSTALL_DIR/uninstall.sh"
install -Dm644 "$PROJECT_ROOT/assets/onedrive.png" "$INSTALL_DIR/onedrive.png"
install -Dm644 "$PROJECT_ROOT/assets/onedrive1.png" "$INSTALL_DIR/onedrive1.png"
install -Dm644 "$PROJECT_ROOT/assets/onedrive-tray-online.png" "$INSTALL_DIR/onedrive-tray-online.png"
install -Dm644 "$PROJECT_ROOT/assets/onedrive-tray-syncing.png" "$INSTALL_DIR/onedrive-tray-syncing.png"
install -Dm644 "$PROJECT_ROOT/assets/onedrive-tray-warning.png" "$INSTALL_DIR/onedrive-tray-warning.png"
cp -a "$PROJECT_ROOT/installers/." "$INSTALL_DIR/installers/"
chmod 755 "$INSTALL_DIR/installers/"*.sh

if [ "$ONEDRIVE_LANG" = "en" ]; then
  DESKTOP_COMMENT="Mount OneDrive with rclone and show a tray indicator"
else
  DESKTOP_COMMENT="Montar OneDrive con rclone y mostrar indicador"
fi

cat > "$DESKTOP_DIR/montar_onedrive.desktop" <<EOF2
[Desktop Entry]
Name=$APP_TITLE
Comment=$DESKTOP_COMMENT
Exec=$BIN_DIR/montar_onedrive.sh
Icon=$INSTALL_DIR/onedrive.png
Terminal=false
Type=Application
Categories=Utility;
StartupNotify=false
EOF2

chmod 755 "$BIN_DIR/montar_onedrive.sh"
chmod 755 "$INSTALL_DIR/setup_rclone.sh"
chmod 755 "$INSTALL_DIR/i18n.py"
chmod 755 "$INSTALL_DIR/onedrive_indicator.py"
chmod 755 "$INSTALL_DIR/setup_rclone_gui.py"
chmod 755 "$INSTALL_DIR/uninstall.sh"

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
fi

# If this is an upgrade/reinstall, close only the old tray process so the next
# OneDrive launch reloads the language chosen above. This does not unmount rclone.
pkill -f "$INSTALL_DIR/onedrive_indicator.py" >/dev/null 2>&1 || true

echo
say "Instalado en:" "Installed in:"
echo "  $INSTALL_DIR"
echo "  $BIN_DIR/montar_onedrive.sh"
echo "  $INSTALL_DIR/uninstall.sh"
echo "  $DESKTOP_DIR/montar_onedrive.desktop"
echo

export PATH="$BIN_DIR:$PATH"

say \
  "La configuración de la cuenta no se realiza durante la instalación." \
  "Account configuration is not performed during installation."
say \
  "La primera vez que abras OneDrive, si no existe un remoto OneDrive válido, se abrirá automáticamente el asistente gráfico de configuración." \
  "The first time you open OneDrive, if no valid OneDrive remote exists, the graphical setup assistant will open automatically."
echo
say "Instalación terminada. El lanzador aparecerá como: OneDrive" "Installation complete. The launcher will appear as: OneDrive"
