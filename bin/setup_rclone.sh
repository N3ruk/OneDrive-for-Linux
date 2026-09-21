#!/usr/bin/env bash
set -euo pipefail

APP_NAME="onedrive-rclone"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
BIN_HOME="${XDG_BIN_HOME:-$HOME/.local/bin}"
INSTALL_DIR="$DATA_HOME/$APP_NAME"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
APP_CONFIG_DIR="$CONFIG_HOME/$APP_NAME"
SETTINGS_FILE="$APP_CONFIG_DIR/settings.env"
MOUNT_SCRIPT="$BIN_HOME/montar_onedrive.sh"
SELF="${ONEDRIVE_SETUP_SCRIPT:-$INSTALL_DIR/setup_rclone.sh}"
INSTALLERS_DIR="$INSTALL_DIR/installers"

mkdir -p "$APP_CONFIG_DIR"
export PATH="$BIN_HOME:$PATH"

notify() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "OneDrive" "$1" || true
  fi
}

find_terminal() {
  if command -v konsole >/dev/null 2>&1; then echo konsole; return; fi
  if command -v gnome-terminal >/dev/null 2>&1; then echo gnome-terminal; return; fi
  if command -v kgx >/dev/null 2>&1; then echo kgx; return; fi
  if command -v xfce4-terminal >/dev/null 2>&1; then echo xfce4-terminal; return; fi
  if command -v x-terminal-emulator >/dev/null 2>&1; then echo x-terminal-emulator; return; fi
  if command -v xterm >/dev/null 2>&1; then echo xterm; return; fi
  return 1
}

launch_terminal_assistant() {
  local term
  term="$(find_terminal)" || {
    notify "rclone necesita configuración, pero no se encontró un emulador de terminal. Ejecuta: $SELF --interactive"
    return 1
  }
  case "$term" in
    konsole) nohup konsole -e "$SELF" --interactive --resume-mount >/dev/null 2>&1 & ;;
    gnome-terminal) nohup gnome-terminal -- "$SELF" --interactive --resume-mount >/dev/null 2>&1 & ;;
    kgx) nohup kgx -- "$SELF" --interactive --resume-mount >/dev/null 2>&1 & ;;
    xfce4-terminal) nohup xfce4-terminal --disable-server -x "$SELF" --interactive --resume-mount >/dev/null 2>&1 & ;;
    x-terminal-emulator) nohup x-terminal-emulator -e "$SELF" --interactive --resume-mount >/dev/null 2>&1 & ;;
    xterm) nohup xterm -e "$SELF" --interactive --resume-mount >/dev/null 2>&1 & ;;
  esac
  notify "Se ha abierto el asistente de configuración de rclone."
}

os_family() {
  local id="" like=""
  if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    id="${ID:-}"
    like="${ID_LIKE:-}"
  fi
  if [ "$id" = "steamos" ] || [ "$id" = "holo" ]; then echo steamos; return; fi
  case " $id $like " in
    *" debian "*|*" ubuntu "*) echo debian ;;
    *" arch "*) echo arch ;;
    *" fedora "*|*" rhel "*) echo fedora ;;
    *" opensuse "*|*" suse "*) echo opensuse ;;
    *) echo generic ;;
  esac
}

install_rclone_if_missing() {
  if command -v rclone >/dev/null 2>&1; then return 0; fi
  local family installer
  family="$(os_family)"
  installer="$INSTALLERS_DIR/$family.sh"
  echo
  echo "rclone no está instalado."
  read -r -p "¿Quieres que el asistente lo instale ahora? [S/n]: " ans
  case "$ans" in n|N|no|NO) return 1 ;; esac
  [ -x "$installer" ] || installer="$INSTALLERS_DIR/generic.sh"
  "$installer"
  hash -r
  command -v rclone >/dev/null 2>&1
}

onedrive_remotes() {
  command -v rclone >/dev/null 2>&1 || return 0
  while IFS= read -r remote; do
    [ -n "$remote" ] || continue
    local name="${remote%:}"
    if rclone config show "$name" 2>/dev/null | grep -Eq '^[[:space:]]*type[[:space:]]*=[[:space:]]*onedrive[[:space:]]*$'; then
      printf '%s\n' "$remote"
    fi
  done < <(rclone listremotes 2>/dev/null || true)
}

save_remote() {
  local remote="$1"
  mkdir -p "$APP_CONFIG_DIR"
  printf 'ONEDRIVE_REMOTE=%q\n' "$remote" > "$SETTINGS_FILE"
  chmod 600 "$SETTINGS_FILE"
  echo "Remoto guardado para OneDrive: $remote"
}

choose_remote() {
  mapfile -t remotes < <(onedrive_remotes)
  if [ "${#remotes[@]}" -eq 0 ]; then return 1; fi
  if [ "${#remotes[@]}" -eq 1 ]; then
    save_remote "${remotes[0]}"
    return 0
  fi
  echo "Se encontraron varios remotos OneDrive:"
  local i
  for i in "${!remotes[@]}"; do printf '  %d) %s\n' "$((i+1))" "${remotes[$i]}"; done
  while true; do
    read -r -p "Elige el remoto que usará la aplicación [1-${#remotes[@]}]: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#remotes[@]}" ]; then
      save_remote "${remotes[$((choice-1))]}"
      return 0
    fi
  done
}

configured_remote_exists() {
  local selected="${ONEDRIVE_REMOTE:-}"
  if [ -z "$selected" ] && [ -r "$SETTINGS_FILE" ]; then
    # shellcheck disable=SC1090
    . "$SETTINGS_FILE"
    selected="${ONEDRIVE_REMOTE:-}"
  fi
  if [ -n "$selected" ]; then
    rclone config show "${selected%:}" >/dev/null 2>&1 &&       rclone config show "${selected%:}" 2>/dev/null | grep -Eq '^[[:space:]]*type[[:space:]]*=[[:space:]]*onedrive[[:space:]]*$'
    return $?
  fi
  onedrive_remotes | grep -q .
}

interactive=0
resume=0
from_launcher=0
for arg in "$@"; do
  case "$arg" in
    --interactive) interactive=1 ;;
    --resume-mount) resume=1 ;;
    --from-launcher) from_launcher=1 ;;
  esac
done

if [ "$from_launcher" -eq 1 ] && [ ! -t 0 ]; then
  launch_terminal_assistant
  exit $?
fi

if [ "$interactive" -eq 1 ] || [ -t 0 ]; then
  echo "=============================================="
  echo " Asistente de configuración OneDrive / rclone"
  echo "=============================================="
  echo
fi

if ! install_rclone_if_missing; then
  echo "No se puede continuar sin rclone." >&2
  exit 1
fi

if configured_remote_exists; then
  choose_remote || true
else
  echo
  echo "No se ha encontrado ningún remoto de tipo OneDrive en rclone."
  echo "Se abrirá el asistente oficial de rclone."
  echo "Cuando pregunte el tipo de almacenamiento, elige Microsoft OneDrive (onedrive)."
  echo "La autorización de Microsoft se abrirá en tu navegador."
  echo
  read -r -p "Pulsa Intro para continuar..." _
  rclone config
  echo
  if ! choose_remote; then
    echo "No se encontró un remoto OneDrive después de la configuración." >&2
    echo "Puedes volver a ejecutar: $SELF --interactive" >&2
    exit 1
  fi
fi

if [ "$resume" -eq 1 ] && [ -x "$MOUNT_SCRIPT" ]; then
  echo
  echo "Configuración terminada. Iniciando OneDrive..."
  sleep 1
  ONEDRIVE_SKIP_SETUP=1 "$MOUNT_SCRIPT" >/dev/null 2>&1 &
fi

echo
echo "Configuración de rclone terminada."
