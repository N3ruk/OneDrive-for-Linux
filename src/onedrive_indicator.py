#!/usr/bin/env python3
from __future__ import annotations

import os
import shlex
import shutil
import subprocess
import threading
import time
from pathlib import Path

import gi
import requests

# Ayatana es la opción preferida (Ubuntu/Debian/Fedora/Arch).
# AppIndicator3 se mantiene como fallback para distribuciones donde Ayatana
# no esté empaquetado pero sí la implementación clásica (por ejemplo openSUSE).
try:
    gi.require_version("AyatanaAppIndicator3", "0.1")
    gi.require_version("Gtk", "3.0")
    from gi.repository import AyatanaAppIndicator3 as AppIndicator3, Gtk, GLib
except (ValueError, ImportError):
    gi.require_version("AppIndicator3", "0.1")
    gi.require_version("Gtk", "3.0")
    from gi.repository import AppIndicator3, Gtk, GLib

APP_NAME = "onedrive-rclone"
BASE_DIR = Path(os.environ.get("ONEDRIVE_ASSET_DIR", Path(__file__).resolve().parent))
CONFIG_HOME = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
SETTINGS_FILE = CONFIG_HOME / APP_NAME / "settings.env"
MOUNTPOINT = Path(os.environ.get("ONEDRIVE_MOUNTPOINT", Path.home() / "OneDrive"))

# Iconos de estado diseñados para esta aplicación. Solo cambia el icono; el
# funcionamiento, el menú y las acciones del indicador original se mantienen.
ICON_ONLINE = str(BASE_DIR / "onedrive-tray-online.png")
ICON_SYNCING = str(BASE_DIR / "onedrive-tray-syncing.png")
ICON_WARNING = str(BASE_DIR / "onedrive-tray-warning.png")
ICON_FALLBACK = str(BASE_DIR / "onedrive1.png")

CACHE_DIR = Path(os.environ.get("ONEDRIVE_CACHE_DIR", Path.home() / ".cache/rclone"))
CACHE_THRESHOLD = int(os.environ.get("ONEDRIVE_CACHE_THRESHOLD", str(125 * 1024 * 1024 * 1024)))
NOTIFY_INTERVAL = int(os.environ.get("ONEDRIVE_NOTIFY_INTERVAL", str(12 * 60 * 60)))
RC_URL = os.environ.get("ONEDRIVE_RC_URL", "http://localhost:5572/core/stats")
RC_BASE = os.environ.get("ONEDRIVE_RC_BASE", RC_URL.rsplit("/core/stats", 1)[0]).rstrip("/")
STATUS_INTERVAL = int(os.environ.get("ONEDRIVE_STATUS_INTERVAL", "10"))
last_notify_time = 0.0
_status_worker_running = False


def run_output(args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, capture_output=True, text=True, check=False)


def notify(summary: str, body: str) -> None:
    subprocess.Popen(["notify-send", summary, body])


def fusermount_command() -> str:
    for candidate in ("fusermount3", "fusermount"):
        if shutil.which(candidate):
            return candidate
    return "fusermount"


class ProgressWindow(Gtk.Window):
    def __init__(self) -> None:
        super().__init__(title="Progreso OneDrive")
        self.set_default_size(500, 200)
        self.set_border_width(10)
        
        # En Gtk 3 usamos un contenedor scrolleable por si hay muchas transferencias
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        self.add(scrolled)

        self.box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        scrolled.add(self.box)

        self.timeout_id = GLib.timeout_add_seconds(2, self.update_progress)
        self.connect("destroy", self.on_destroy)

    def update_progress(self) -> bool:
        try:
            response = requests.post(RC_URL, timeout=2)
            if response.status_code == 200 and response.text.strip():
                stats = response.json()
                transfers = stats.get("transferring", [])
                
                # Limpiar hijos actuales de forma segura en Gtk3
                for child in self.box.get_children():
                    self.box.remove(child)

                if not transfers:
                    label = Gtk.Label(label="No hay transferencias activas en este momento.")
                    self.box.pack_start(label, True, True, 0)
                else:
                    for transfer in transfers:
                        name = transfer.get("name", "archivo")
                        pct = transfer.get("percentage", 0) / 100.0
                        speed_mb = round(transfer.get("speed", 0) / (1024**2), 2)
                        eta = transfer.get("eta", 0)
                        label = Gtk.Label(label=f"{name}\nVel: {speed_mb} MB/s | ETA: {eta}s")
                        bar = Gtk.ProgressBar()
                        bar.set_fraction(pct)
                        bar.set_text(f"{int(pct * 100)}%")
                        bar.set_show_text(True)
                        self.box.pack_start(label, False, False, 0)
                        self.box.pack_start(bar, False, False, 0)
                self.show_all()
        except requests.exceptions.ConnectionError:
            for child in self.box.get_children():
                self.box.remove(child)
            label = Gtk.Label(label="⚠️ rclone RC no está activo (falta parámetro --rc al montar)")
            self.box.pack_start(label, True, True, 0)
            self.show_all()
        except Exception as exc:
            print("Error consultando progreso:", exc)
        return True

    def on_destroy(self, *_args) -> None:
        if self.timeout_id:
            GLib.source_remove(self.timeout_id)
            self.timeout_id = None


def show_progress_window(_item) -> None:
    win = ProgressWindow()
    win.show_all()


def check_mount() -> bool:
    result = run_output(["findmnt", "-rn", "-M", str(MOUNTPOINT)])
    return result.returncode == 0


def configured_remote() -> str:
    """Obtiene el remoto usado por el lanzador sin ejecutar el fichero de configuración."""
    remote = os.environ.get("ONEDRIVE_REMOTE", "").strip()
    if not remote and SETTINGS_FILE.is_file():
        try:
            for line in SETTINGS_FILE.read_text(encoding="utf-8").splitlines():
                if not line.startswith("ONEDRIVE_REMOTE="):
                    continue
                raw = line.split("=", 1)[1].strip()
                parts = shlex.split(raw)
                if parts:
                    remote = parts[0]
                break
        except Exception:
            pass
    if not remote:
        remote = "Onedrive:"
    return remote if remote.endswith(":") else f"{remote}:"


def _existing_icon(path: str, fallback: str = "dialog-warning") -> str:
    return path if Path(path).is_file() else fallback


def _apply_status_icon(state: str) -> bool:
    if state == "syncing":
        icon = _existing_icon(ICON_SYNCING, ICON_FALLBACK)
        description = "OneDrive sincronizando"
    elif state == "online":
        icon = _existing_icon(ICON_ONLINE, ICON_FALLBACK)
        description = "OneDrive conectado"
    else:
        icon = _existing_icon(ICON_WARNING, "dialog-warning")
        description = "OneDrive sin conexión"
    indicator.set_icon_full(icon, description)
    return False


def _detect_status() -> str:
    # 1) Sin montaje no hay una sesión funcional de OneDrive.
    if not check_mount():
        return "warning"

    # 2) core/stats confirma que el rclone que montó OneDrive sigue vivo y nos
    #    permite detectar transferencias activas sin alterar el montaje.
    try:
        response = requests.post(RC_URL, timeout=2)
        if response.status_code != 200 or not response.text.strip():
            return "warning"
        transfers = response.json().get("transferring", [])
        if transfers:
            return "syncing"
    except Exception:
        return "warning"

    # 3) Estar montado y tener RC activo no garantiza que Internet/Microsoft
    #    sigan accesibles. operations/about hace una comprobación real contra
    #    el remoto de OneDrive sin transferir archivos.
    try:
        response = requests.post(
            f"{RC_BASE}/operations/about",
            json={"fs": configured_remote()},
            timeout=4,
        )
        if response.status_code == 200:
            return "online"
    except Exception:
        pass
    return "warning"


def _status_worker() -> None:
    global _status_worker_running
    try:
        state = _detect_status()
        GLib.idle_add(_apply_status_icon, state)
    finally:
        _status_worker_running = False


def update_icon() -> bool:
    """Actualiza el icono en segundo plano para no bloquear el menú del tray."""
    global _status_worker_running
    if not _status_worker_running:
        _status_worker_running = True
        threading.Thread(target=_status_worker, daemon=True).start()
    return True


def open_folder(_item) -> None:
    subprocess.Popen(["xdg-open", str(MOUNTPOINT)])


def stop_rclone_mount() -> None:
    """Detiene únicamente el rclone que monta nuestro punto de montaje."""
    result = run_output(["ps", "-eo", "pid=,args="])
    own_pid = str(os.getpid())
    for line in result.stdout.splitlines():
        parts = line.strip().split(None, 1)
        if len(parts) != 2:
            continue
        pid, command = parts
        if pid == own_pid or "rclone mount" not in command:
            continue
        if str(MOUNTPOINT) not in command:
            continue
        try:
            subprocess.run(["kill", "-TERM", pid], check=False)
        except OSError:
            continue


def unmount_mountpoint() -> bool:
    """Desmonta con reintentos y usa lazy unmount si hay procesos ocupándolo."""
    if not check_mount():
        return True

    command = fusermount_command()
    for _attempt in range(3):
        result = subprocess.run(
            [command, "-u", str(MOUNTPOINT)],
            capture_output=True,
            text=True,
            check=False,
        )
        if not check_mount():
            return True
        time.sleep(1)

    # Permite liberar el punto de montaje aunque Nautilus conserve un descriptor.
    subprocess.run([command, "-uz", str(MOUNTPOINT)], check=False)
    for _attempt in range(5):
        if not check_mount():
            return True
        time.sleep(1)
    return False


def unmount(_item) -> None:
    if not unmount_mountpoint():
        notify(
            "OneDrive",
            "No se pudo desmontar la unidad; puede estar siendo usada por Nautilus u otra aplicación.",
        )
        return

    stop_rclone_mount()
    Gtk.main_quit()


def clean_cache(_item) -> None:
    if not CACHE_DIR.is_dir():
        notify("OneDrive", "No existe la carpeta de caché")
        return

    for entry in CACHE_DIR.iterdir():
        try:
            if entry.is_dir() and not entry.is_symlink():
                shutil.rmtree(entry)
            else:
                entry.unlink()
        except Exception as exc:
            subprocess.Popen(["notify-send", "OneDrive", f"Error limpiando: {entry.name} ({exc})"])
    notify("OneDrive", "Caché de rclone limpiada")


def cache_size(_item) -> None:
    if CACHE_DIR.is_dir():
        result = run_output(["du", "-sh", str(CACHE_DIR)])
        size = result.stdout.split()[0] if result.stdout else "0"
        notify("OneDrive", f"Tamaño de la caché: {size}")
    else:
        notify("OneDrive", "No existe la carpeta de caché")


def check_cache_threshold() -> bool:
    global last_notify_time
    result = run_output(["du", "-sb", str(CACHE_DIR)])
    try:
        used_bytes = int(result.stdout.split()[0])
        if used_bytes > CACHE_THRESHOLD:
            now = time.time()
            if now - last_notify_time >= NOTIFY_INTERVAL:
                gb_used = round(used_bytes / (1024**3), 2)
                notify("OneDrive", f"⚠️ Caché supera {gb_used} GB (límite 125 GB)")
                last_notify_time = now
    except Exception:
        pass
    return True


def check_progress_notification(_item) -> bool:
    try:
        response = requests.post(RC_URL, timeout=2)
        if response.status_code == 200 and response.text.strip():
            stats = response.json()
            transfers = stats.get("transferring", [])
            if transfers:
                msgs = []
                for transfer in transfers:
                    name = transfer.get("name", "archivo")
                    pct = transfer.get("percentage", 0)
                    done_mb = round(transfer.get("bytes", 0) / (1024**2), 2)
                    size_mb = round(transfer.get("size", 0) / (1024**2), 2)
                    speed_mb = round(transfer.get("speed", 0) / (1024**2), 2)
                    eta = transfer.get("eta", 0)
                    msgs.append(
                        f"{name}\n{pct}% ({done_mb}/{size_mb} MB) Vel: {speed_mb} MB/s ETA: {eta}s"
                    )
                notify("OneDrive", "\n\n".join(msgs))
            else:
                notify("OneDrive", "Sin transferencias activas")
        else:
            notify("OneDrive", "Sin transferencias activas")
    except requests.exceptions.ConnectionError:
        notify("OneDrive", "⚠️ rclone RC no está activo (falta parámetro --rc al montar)")
    except Exception as exc:
        notify("OneDrive", f"Error consultando progreso: {exc}")
    return True


def open_onedrive_online(_item) -> None:
    subprocess.Popen(["xdg-open", "https://onedrive.live.com/"])


def open_onedrive_recycle_bin(_item) -> None:
    subprocess.Popen(["xdg-open", "https://onedrive.live.com/?view=5"])


indicator = AppIndicator3.Indicator.new(
    "onedrive-status",
    _existing_icon(ICON_ONLINE, ICON_FALLBACK),
    AppIndicator3.IndicatorCategory.APPLICATION_STATUS,
)
indicator.set_status(AppIndicator3.IndicatorStatus.ACTIVE)

menu = Gtk.Menu()

open_item = Gtk.MenuItem(label="Abrir carpeta OneDrive")
open_item.connect("activate", open_folder)
menu.append(open_item)

online_item = Gtk.MenuItem(label="Ver OneDrive en línea")
online_item.connect("activate", open_onedrive_online)
menu.append(online_item)

recycle_item = Gtk.MenuItem(label="Papelera de reciclaje")
recycle_item.connect("activate", open_onedrive_recycle_bin)
menu.append(recycle_item)

cache_menu = Gtk.Menu()
clean_item = Gtk.MenuItem(label="Limpiar caché OneDrive")
clean_item.connect("activate", clean_cache)
cache_menu.append(clean_item)

size_item = Gtk.MenuItem(label="Tamaño de la caché")
size_item.connect("activate", cache_size)
cache_menu.append(size_item)
cache_menu.show_all()

cache_root = Gtk.MenuItem(label="Caché")
cache_root.set_submenu(cache_menu)
menu.append(cache_root)

progress_menu = Gtk.Menu()
notif_item = Gtk.MenuItem(label="Notificación")
notif_item.connect("activate", check_progress_notification)
progress_menu.append(notif_item)

bar_item = Gtk.MenuItem(label="Barra de Progreso")
bar_item.connect("activate", show_progress_window)
progress_menu.append(bar_item)
progress_menu.show_all()

progress_root = Gtk.MenuItem(label="Ver progreso")
progress_root.set_submenu(progress_menu)
menu.append(progress_root)

unmount_item = Gtk.MenuItem(label="Salir")
unmount_item.connect("activate", unmount)
menu.append(unmount_item)

menu.show_all()
indicator.set_menu(menu)

update_icon()
GLib.timeout_add_seconds(STATUS_INTERVAL, update_icon)
GLib.timeout_add_seconds(3600, check_cache_threshold)

Gtk.main()
