#!/usr/bin/env bash
set -euo pipefail

APP_NAME="onedrive-rclone"
BIN_HOME="${XDG_BIN_HOME:-$HOME/.local/bin}"

log() { printf '%s\n' "$*"; }
warn() { printf 'AVISO: %s\n' "$*" >&2; }

have_cmd() { command -v "$1" >/dev/null 2>&1; }

sudo_cmd() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif have_cmd sudo; then
    sudo "$@"
  else
    warn "Se necesita sudo para instalar dependencias del sistema."
    return 1
  fi
}

arch_to_rclone() {
  case "$(uname -m)" in
    x86_64|amd64) echo amd64 ;;
    aarch64|arm64) echo arm64 ;;
    armv7l|armv7*) echo arm-v7 ;;
    armv6l|armv6*) echo arm-v6 ;;
    i386|i486|i586|i686) echo 386 ;;
    *) return 1 ;;
  esac
}

install_rclone_portable() {
  mkdir -p "$BIN_HOME"
  local arch tmp url src
  arch="$(arch_to_rclone)" || {
    warn "Arquitectura no soportada por el instalador portátil: $(uname -m)"
    return 1
  }
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  url="https://downloads.rclone.org/rclone-current-linux-${arch}.zip"
  log "Instalando rclone oficial en $BIN_HOME (arquitectura: $arch)..."

  if have_cmd curl; then
    curl -fL "$url" -o "$tmp/rclone.zip"
  elif have_cmd wget; then
    wget -O "$tmp/rclone.zip" "$url"
  elif have_cmd python3; then
    python3 - "$url" "$tmp/rclone.zip" <<'PY'
import sys, urllib.request
urllib.request.urlretrieve(sys.argv[1], sys.argv[2])
PY
  else
    warn "Hace falta curl, wget o python3 para descargar rclone."
    return 1
  fi

  if have_cmd unzip; then
    unzip -q "$tmp/rclone.zip" -d "$tmp"
  elif have_cmd python3; then
    python3 - "$tmp/rclone.zip" "$tmp" <<'PY'
import sys, zipfile
with zipfile.ZipFile(sys.argv[1]) as z:
    z.extractall(sys.argv[2])
PY
  else
    warn "Hace falta unzip o python3 para extraer rclone."
    return 1
  fi

  src="$(find "$tmp" -type f -name rclone -perm -u+x | head -n1 || true)"
  if [ -z "$src" ]; then
    src="$(find "$tmp" -type f -name rclone | head -n1 || true)"
  fi
  [ -n "$src" ] || { warn "No se encontró el binario rclone descargado."; return 1; }
  install -m755 "$src" "$BIN_HOME/rclone"
  log "rclone instalado en $BIN_HOME/rclone"
}

python_indicator_check() {
  python3 - <<'PY'
import sys
try:
    import gi
    gi.require_version("Gtk", "3.0")
    ok_indicator = False
    for name in ("AyatanaAppIndicator3", "AppIndicator3"):
        try:
            gi.require_version(name, "0.1")
            ok_indicator = True
            break
        except ValueError:
            pass
    if not ok_indicator:
        raise RuntimeError("falta AyatanaAppIndicator3/AppIndicator3")
    import requests
except Exception as exc:
    print(exc, file=sys.stderr)
    raise SystemExit(1)
PY
}
