#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="onedrive-rclone"
APP_TITLE="OneDrive"
APP_VERSION="1.5.2"

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
BIN_HOME="${XDG_BIN_HOME:-$HOME/.local/bin}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

INSTALL_DIR="$DATA_HOME/$APP_NAME"
BIN_DIR="$BIN_HOME"
DESKTOP_DIR="$DATA_HOME/applications"
APP_CONFIG_DIR="$CONFIG_HOME/$APP_NAME"
SETTINGS_FILE="$APP_CONFIG_DIR/settings.env"

# SteamOS state tracking. We only re-enable read-only mode if this installer
# actually disabled it, so we do not change a user's pre-existing state.
STEAMOS_READONLY_WAS_ENABLED=0
DEPENDENCIES_OK=1
DEPENDENCIES_SKIPPED=0

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

restore_steamos_readonly() {
  if [ "$STEAMOS_READONLY_WAS_ENABLED" -eq 1 ]; then
    echo
    say \
      "Restaurando la protección de solo lectura de SteamOS..." \
      "Restoring SteamOS read-only protection..."
    if sudo steamos-readonly enable >/dev/null 2>&1; then
      STEAMOS_READONLY_WAS_ENABLED=0
      say \
        "Protección de solo lectura restaurada." \
        "Read-only protection restored."
    else
      say \
        "AVISO: no se pudo restaurar automáticamente el modo de solo lectura. Ejecuta: sudo steamos-readonly enable" \
        "WARNING: read-only mode could not be restored automatically. Run: sudo steamos-readonly enable" >&2
    fi
  fi
}

cleanup() {
  restore_steamos_readonly
}

# Always restore SteamOS protection if the script exits unexpectedly.
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

prepare_steamos_pacman() {
  local readonly_status=""

  command -v sudo >/dev/null 2>&1 || {
    say "ERROR: sudo no está disponible." "ERROR: sudo is not available." >&2
    return 1
  }
  command -v steamos-readonly >/dev/null 2>&1 || {
    say \
      "ERROR: no se encontró steamos-readonly; no se modificará la raíz del sistema." \
      "ERROR: steamos-readonly was not found; the system root will not be modified." >&2
    return 1
  }
  command -v pacman >/dev/null 2>&1 || {
    say "ERROR: pacman no está disponible." "ERROR: pacman is not available." >&2
    return 1
  }
  command -v pacman-key >/dev/null 2>&1 || {
    say "ERROR: pacman-key no está disponible." "ERROR: pacman-key is not available." >&2
    return 1
  }

  say \
    "SteamOS: preparando temporalmente el sistema para instalar dependencias nativas..." \
    "SteamOS: temporarily preparing the system to install native dependencies..."

  # Validate sudo once up front, before touching the filesystem state.
  sudo -v || return 1

  readonly_status="$(sudo steamos-readonly status 2>/dev/null || true)"
  if [ "$readonly_status" = "enabled" ]; then
    say \
      "Desactivando temporalmente la protección de solo lectura..." \
      "Temporarily disabling read-only protection..."
    sudo steamos-readonly disable || return 1
    STEAMOS_READONLY_WAS_ENABLED=1
  elif [ "$readonly_status" = "disabled" ]; then
    say \
      "La protección de solo lectura ya estaba desactivada; se conservará ese estado al terminar." \
      "Read-only protection was already disabled; that state will be preserved when finished."
  else
    say \
      "AVISO: no se pudo determinar el estado de steamos-readonly; se intentará preparar pacman sin cambiarlo." \
      "WARNING: steamos-readonly state could not be determined; pacman preparation will be attempted without changing it." >&2
  fi

  # Initialize the keyring only if it is not usable yet.
  if ! sudo pacman-key --list-keys >/dev/null 2>&1; then
    say \
      "Inicializando el depósito de claves de pacman..." \
      "Initializing the pacman keyring..."
    sudo pacman-key --init || return 1
  fi

  say \
    "Cargando claves de Arch Linux y SteamOS (holo)..." \
    "Populating Arch Linux and SteamOS (holo) keys..."
  sudo pacman-key --populate archlinux holo || return 1

  say \
    "Actualizando la base de datos de paquetes de SteamOS..." \
    "Refreshing the SteamOS package database..."
  # Deliberately use -Sy, not -Syu. SteamOS owns the OS update process.
  sudo pacman -Sy || return 1
}

verify_indicator_runtime() {
  command -v python3 >/dev/null 2>&1 || return 1

  python3 - <<'PY'
import gi

gi.require_version("Gtk", "3.0")
from gi.repository import Gtk  # noqa: F401

try:
    gi.require_version("AyatanaAppIndicator3", "0.1")
    from gi.repository import AyatanaAppIndicator3  # noqa: F401
except (ValueError, ImportError):
    gi.require_version("AppIndicator3", "0.1")
    from gi.repository import AppIndicator3  # noqa: F401
PY
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
  installer_ok=1

  if [ "$family" = "steamos" ]; then
    if ! prepare_steamos_pacman; then
      installer_ok=0
    fi
  fi

  if [ "$installer_ok" -eq 1 ]; then
    if ! "$installer"; then
      installer_ok=0
    fi
  fi

  # Close the temporary SteamOS write window as soon as pacman work finishes.
  if [ "$family" = "steamos" ]; then
    restore_steamos_readonly
  fi

  # On SteamOS, do not trust pacman's exit status alone: verify that the exact
  # GTK/AppIndicator runtime used by the application is importable by Python.
  if [ "$installer_ok" -eq 1 ] && [ "$family" = "steamos" ]; then
    say \
      "Verificando GTK y Ayatana/AppIndicator desde Python..." \
      "Verifying GTK and Ayatana/AppIndicator from Python..."
    if ! verify_indicator_runtime; then
      installer_ok=0
      say \
        "ERROR: las dependencias se instalaron, pero Python no puede cargar GTK/Ayatana AppIndicator." \
        "ERROR: dependencies were installed, but Python cannot load GTK/Ayatana AppIndicator." >&2
    fi
  fi

  if [ "$installer_ok" -ne 1 ]; then
    DEPENDENCIES_OK=0
    echo >&2
    say \
      "AVISO: no se pudieron preparar o verificar todas las dependencias automáticamente." \
      "WARNING: not all dependencies could be prepared or verified automatically." >&2
    say \
      "Puedes instalar los archivos de OneDrive, pero el indicador puede no funcionar hasta resolver las dependencias." \
      "You can install the OneDrive files, but the tray indicator may not work until the dependencies are fixed." >&2
    if ! ask_yes_default "¿Instalar igualmente los archivos de OneDrive?" "Install the OneDrive files anyway?"; then
      exit 1
    fi
  fi
else
  DEPENDENCIES_SKIPPED=1
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

if [ "$DEPENDENCIES_OK" -eq 1 ] && [ "$DEPENDENCIES_SKIPPED" -eq 0 ]; then
  say \
    "Instalación terminada y dependencias verificadas. El lanzador aparecerá como: OneDrive" \
    "Installation complete and dependencies verified. The launcher will appear as: OneDrive"
elif [ "$DEPENDENCIES_SKIPPED" -eq 1 ]; then
  say \
    "Archivos instalados. Las dependencias se omitieron y no se han verificado. El lanzador aparecerá como: OneDrive" \
    "Files installed. Dependencies were skipped and were not verified. The launcher will appear as: OneDrive"
else
  say \
    "Archivos instalados, pero las dependencias no quedaron verificadas. OneDrive puede no funcionar hasta corregirlas." \
    "Files installed, but dependencies were not verified. OneDrive may not work until they are fixed."
fi
