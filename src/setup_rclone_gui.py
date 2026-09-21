#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import shlex
import shutil
import subprocess
import threading
from pathlib import Path
from typing import Any

import gi

gi.require_version("Gtk", "3.0")
from gi.repository import GdkPixbuf, GLib, Gtk  # noqa: E402

APP_NAME = "onedrive-rclone"
DATA_HOME = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
BIN_HOME = Path(os.environ.get("XDG_BIN_HOME", Path.home() / ".local/bin"))
CONFIG_HOME = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
INSTALL_DIR = DATA_HOME / APP_NAME
APP_CONFIG_DIR = CONFIG_HOME / APP_NAME
SETTINGS_FILE = APP_CONFIG_DIR / "settings.env"
MOUNT_SCRIPT = BIN_HOME / "montar_onedrive.sh"
APP_ICON = INSTALL_DIR / "onedrive.png"

REGIONS = [
    ("global", "Microsoft Cloud Global (recomendado)"),
    ("us", "Microsoft Cloud for US Government"),
    ("de", "Microsoft Cloud Germany"),
    ("cn", "Azure / Office 365 operado por Vnet Group en China"),
]


def rclone_binary() -> str | None:
    return shutil.which("rclone")


def run_rclone(args: list[str], timeout: float | None = None) -> subprocess.CompletedProcess[str]:
    exe = rclone_binary()
    if not exe:
        raise FileNotFoundError("rclone no está instalado")
    env = os.environ.copy()
    env["PATH"] = f"{BIN_HOME}:{env.get('PATH', '')}"
    return subprocess.run(
        [exe, *args],
        capture_output=True,
        text=True,
        check=False,
        timeout=timeout,
        env=env,
    )


def parse_json_output(text: str) -> dict[str, Any]:
    """Extrae el objeto JSON devuelto por rclone sin registrar tokens ni secretos."""
    stripped = text.strip()
    if not stripped:
        return {}
    try:
        value = json.loads(stripped)
        return value if isinstance(value, dict) else {}
    except json.JSONDecodeError:
        start = stripped.find("{")
        end = stripped.rfind("}")
        if start < 0 or end <= start:
            return {}
        value = json.loads(stripped[start : end + 1])
        return value if isinstance(value, dict) else {}


def remote_type(remote_name: str) -> str | None:
    name = remote_name.rstrip(":")
    # Preferimos 'redacted' para no cargar secretos en la salida del proceso.
    for command in (("config", "redacted", name), ("config", "show", name)):
        result = run_rclone(list(command))
        if result.returncode != 0:
            continue
        for line in result.stdout.splitlines():
            if "=" not in line:
                continue
            key, value = line.split("=", 1)
            if key.strip() == "type":
                return value.strip()
    return None


def list_remote_names() -> list[str]:
    result = run_rclone(["listremotes"])
    if result.returncode != 0:
        return []
    return [line.strip().rstrip(":") for line in result.stdout.splitlines() if line.strip()]


def onedrive_remotes() -> list[str]:
    found: list[str] = []
    for name in list_remote_names():
        try:
            if remote_type(name) == "onedrive":
                found.append(f"{name}:")
        except Exception:
            continue
    return found


def save_remote(remote: str) -> None:
    APP_CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    value = remote if remote.endswith(":") else f"{remote}:"
    SETTINGS_FILE.write_text(f"ONEDRIVE_REMOTE={shlex.quote(value)}\n", encoding="utf-8")
    os.chmod(SETTINGS_FILE, 0o600)


def next_remote_name() -> str:
    used = set(list_remote_names())
    if "onedrive" not in used:
        return "onedrive"
    number = 2
    while f"onedrive-{number}" in used:
        number += 1
    return f"onedrive-{number}"


def is_valid_onedrive(remote: str) -> bool:
    try:
        return remote_type(remote.rstrip(":")) == "onedrive"
    except Exception:
        return False


class CancelledByUser(RuntimeError):
    pass


class OneDriveSetup(Gtk.Window):
    def __init__(self, resume_mount: bool) -> None:
        super().__init__(title="Configurar OneDrive")
        self.resume_mount = resume_mount
        self.created_remote: str | None = None
        self.selected_region = "global"
        self.worker_running = False
        self.choice_event: threading.Event | None = None
        self.choice_result: str | None = None

        # Tamaño pensado también para Steam Deck (1280x800) y escritorios pequeños.
        # La zona central es desplazable, por lo que los botones nunca quedan fuera
        # de la pantalla aunque GTK use fuentes o escalado grandes.
        self.set_default_size(560, 480)
        self.set_size_request(420, 320)
        self.set_resizable(True)
        self.set_border_width(16)
        self.set_position(Gtk.WindowPosition.CENTER)
        if APP_ICON.is_file():
            try:
                self.set_icon_from_file(str(APP_ICON))
            except Exception:
                pass

        self.root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
        self.add(self.root)

        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=14)
        if APP_ICON.is_file():
            # Gtk.Image.set_pixel_size() solo afecta a iconos de tema, no a PNG
            # cargados desde archivo. El icono original es 1600x1600, así que lo
            # escalamos de verdad antes de añadirlo para que no expanda la ventana.
            try:
                pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(
                    str(APP_ICON), 64, 64, True
                )
                image = Gtk.Image.new_from_pixbuf(pixbuf)
                header.pack_start(image, False, False, 0)
            except Exception:
                pass

        title_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=3)
        title = Gtk.Label()
        title.set_markup("<span size='x-large' weight='bold'>Configurar OneDrive</span>")
        title.set_xalign(0)
        subtitle = Gtk.Label(label="Conecta tu cuenta de Microsoft para que OneDrive pueda montarse con rclone.")
        subtitle.set_xalign(0)
        subtitle.set_line_wrap(True)
        subtitle.set_max_width_chars(58)
        title_box.pack_start(title, False, False, 0)
        title_box.pack_start(subtitle, False, False, 0)
        header.pack_start(title_box, True, True, 0)
        self.root.pack_start(header, False, False, 0)

        self.separator = Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL)
        self.root.pack_start(self.separator, False, False, 0)

        self.content_scroll = Gtk.ScrolledWindow()
        self.content_scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        self.content_scroll.set_shadow_type(Gtk.ShadowType.NONE)
        self.content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        self.content.set_border_width(2)
        self.content_scroll.add_with_viewport(self.content)
        self.root.pack_start(self.content_scroll, True, True, 0)

        self.status = Gtk.Label()
        self.status.set_xalign(0)
        self.status.set_line_wrap(True)
        self.status.set_selectable(False)
        self.root.pack_start(self.status, False, False, 0)

        self.spinner = Gtk.Spinner()
        self.root.pack_start(self.spinner, False, False, 0)

        self.buttons = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        self.buttons.set_halign(Gtk.Align.END)
        self.root.pack_end(self.buttons, False, False, 0)

        self.connect("delete-event", self.on_delete)
        self.show_initial_state()

    def clear_box(self, box: Gtk.Box) -> None:
        for child in box.get_children():
            box.remove(child)

    def set_status(self, text: str) -> None:
        self.status.set_text(text)

    def set_busy(self, busy: bool) -> None:
        if busy:
            self.spinner.start()
        else:
            self.spinner.stop()

    def make_button(self, label: str, callback, suggested: bool = False) -> Gtk.Button:
        button = Gtk.Button(label=label)
        button.connect("clicked", callback)
        if suggested:
            button.get_style_context().add_class("suggested-action")
        return button

    def show_initial_state(self) -> None:
        self.clear_box(self.content)
        self.clear_box(self.buttons)
        self.set_busy(False)
        self.set_status("")

        if not rclone_binary():
            message = Gtk.Label()
            message.set_xalign(0)
            message.set_line_wrap(True)
            message.set_markup(
                "<b>rclone no está instalado.</b>\n\n"
                "El instalador de OneDrive debe instalar rclone y sus dependencias antes de ejecutar este asistente. "
                "Vuelve a ejecutar <tt>install.sh</tt> y después abre OneDrive de nuevo."
            )
            self.content.pack_start(message, True, True, 0)
            self.buttons.pack_start(self.make_button("Cerrar", lambda *_: Gtk.main_quit()), False, False, 0)
            self.show_all()
            return

        existing = onedrive_remotes()
        if len(existing) == 1:
            save_remote(existing[0])
            self.finish_existing(existing[0])
            return
        if len(existing) > 1:
            self.show_existing_remote_choice(existing)
            return

        intro = Gtk.Label()
        intro.set_xalign(0)
        intro.set_line_wrap(True)
        intro.set_markup(
            "No hay ninguna cuenta de OneDrive configurada.\n\n"
            "El asistente utilizará automáticamente la configuración recomendada de rclone. "
            "Solo tendrás que iniciar sesión en Microsoft y, si tu cuenta tiene varias unidades, elegir cuál quieres usar."
        )
        self.content.pack_start(intro, False, False, 0)

        region_frame = Gtk.Frame(label="Región de Microsoft")
        region_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        region_box.set_border_width(10)
        region_help = Gtk.Label(label="Déjalo en Global salvo que tu cuenta pertenezca a una nube especial.")
        region_help.set_xalign(0)
        region_help.set_line_wrap(True)
        self.region_combo = Gtk.ComboBoxText()
        for value, label in REGIONS:
            self.region_combo.append(value, label)
        self.region_combo.set_active_id("global")
        region_box.pack_start(region_help, False, False, 0)
        region_box.pack_start(self.region_combo, False, False, 0)
        region_frame.add(region_box)
        self.content.pack_start(region_frame, False, False, 0)

        privacy = Gtk.Label()
        privacy.set_xalign(0)
        privacy.set_line_wrap(True)
        privacy.set_markup(
            "<small>Las credenciales y tokens son gestionados directamente por rclone y no se muestran ni se guardan en la configuración propia de esta aplicación.</small>"
        )
        self.content.pack_start(privacy, False, False, 0)

        connect = self.make_button("Conectar cuenta Microsoft", self.on_connect, suggested=True)
        self.buttons.pack_start(self.make_button("Cancelar", lambda *_: Gtk.main_quit()), False, False, 0)
        self.buttons.pack_start(connect, False, False, 0)
        self.show_all()

    def finish_existing(self, remote: str) -> None:
        # Si ya existe un único remoto válido, no hacemos pasar al usuario por el asistente.
        if self.resume_mount:
            GLib.idle_add(self.launch_mount_and_exit)
        else:
            self.show_success(remote)

    def show_existing_remote_choice(self, remotes: list[str]) -> None:
        self.clear_box(self.content)
        self.clear_box(self.buttons)
        text = Gtk.Label()
        text.set_xalign(0)
        text.set_line_wrap(True)
        text.set_markup("<b>Se han encontrado varias configuraciones de OneDrive.</b>\nElige cuál debe usar esta aplicación.")
        self.content.pack_start(text, False, False, 0)

        combo = Gtk.ComboBoxText()
        for remote in remotes:
            combo.append_text(remote)
        combo.set_active(0)
        self.content.pack_start(combo, False, False, 0)

        def use_selected(_button) -> None:
            selected = combo.get_active_text()
            if selected:
                save_remote(selected)
                self.show_success(selected)

        def add_new(_button) -> None:
            # Oculta temporalmente los remotos existentes y muestra el flujo de nueva cuenta.
            self.clear_box(self.content)
            self.clear_box(self.buttons)
            self.show_new_account_page()

        self.buttons.pack_start(self.make_button("Añadir otra cuenta", add_new), False, False, 0)
        self.buttons.pack_start(self.make_button("Usar esta cuenta", use_selected, suggested=True), False, False, 0)
        self.show_all()

    def show_new_account_page(self) -> None:
        # Reutiliza la pantalla inicial evitando volver a detectar los remotos existentes.
        intro = Gtk.Label()
        intro.set_xalign(0)
        intro.set_line_wrap(True)
        intro.set_markup("Conecta una nueva cuenta de Microsoft. La configuración recomendada se aplicará automáticamente.")
        self.content.pack_start(intro, False, False, 0)

        self.region_combo = Gtk.ComboBoxText()
        for value, label in REGIONS:
            self.region_combo.append(value, label)
        self.region_combo.set_active_id("global")
        self.content.pack_start(self.region_combo, False, False, 0)
        self.buttons.pack_start(self.make_button("Cancelar", lambda *_: Gtk.main_quit()), False, False, 0)
        self.buttons.pack_start(self.make_button("Conectar cuenta Microsoft", self.on_connect, suggested=True), False, False, 0)
        self.show_all()

    def on_connect(self, _button) -> None:
        if self.worker_running:
            return
        self.selected_region = self.region_combo.get_active_id() or "global"
        self.worker_running = True
        self.clear_box(self.buttons)
        self.set_status("Preparando la configuración de OneDrive…")
        self.set_busy(True)
        self.show_all()
        threading.Thread(target=self.configure_worker, daemon=True).start()

    def configure_worker(self) -> None:
        remote = next_remote_name()
        self.created_remote = remote
        try:
            response = self.run_config_step(remote, state=None, result=None)
            while True:
                state = str(response.get("State", "") or "")
                if not state:
                    if not is_valid_onedrive(remote):
                        raise RuntimeError("rclone terminó la configuración, pero el remoto OneDrive no quedó válido.")
                    save_remote(f"{remote}:")
                    GLib.idle_add(self.show_success, f"{remote}:")
                    return

                option = response.get("Option") or {}
                if not isinstance(option, dict):
                    raise RuntimeError("rclone no devolvió una pregunta de configuración válida.")
                error = str(response.get("Error", "") or "")
                if error:
                    GLib.idle_add(self.set_status, error)

                answer = self.resolve_question(option)
                response = self.run_config_step(remote, state=state, result=answer)
        except CancelledByUser:
            self.cleanup_partial_remote()
            GLib.idle_add(self.show_cancelled)
        except Exception as exc:
            self.cleanup_partial_remote()
            GLib.idle_add(self.show_error, str(exc))

    def base_config_args(self) -> list[str]:
        # Solo fijamos la región. client_id, client_secret y tenant quedan ausentes,
        # que equivale exactamente a aceptar sus valores vacíos recomendados.
        # No usamos --all, por lo que la configuración avanzada queda desactivada.
        return [f"region={self.selected_region}"]

    def run_config_step(self, remote: str, state: str | None, result: str | None) -> dict[str, Any]:
        if state is None:
            args = ["config", "create", remote, "onedrive", *self.base_config_args(), "--non-interactive"]
        else:
            args = [
                "config",
                "update",
                remote,
                *self.base_config_args(),
                "--non-interactive",
                "--continue",
                "--state",
                state,
                "--result",
                result if result is not None else "",
            ]
        completed = run_rclone(args)
        if completed.returncode != 0:
            raise RuntimeError("rclone no pudo completar este paso de la configuración.")
        data = parse_json_output(completed.stdout)
        if not data:
            # Algunas versiones pueden terminar sin imprimir JSON una vez guardado.
            if is_valid_onedrive(remote):
                return {"State": ""}
            raise RuntimeError("La versión instalada de rclone devolvió una respuesta no reconocida.")
        return data

    def resolve_question(self, option: dict[str, Any]) -> str:
        name = str(option.get("Name", "") or "")
        help_text = str(option.get("Help", "") or "")
        default = option.get("Default")
        examples = option.get("Examples") or []

        if name in {"client_id", "client_secret", "tenant"}:
            return ""
        if name == "region":
            return self.selected_region
        if name == "config_is_local":
            GLib.idle_add(
                self.set_status,
                "Se abrirá el navegador. Inicia sesión con Microsoft y autoriza el acceso de rclone a OneDrive.",
            )
            return "true"
        if name == "config_type":
            return "onedrive"
        if name == "config_driveid":
            return self.choose_drive(examples)
        if "advanced" in name.lower():
            return "false"
        if option.get("Type") == "bool":
            # En el flujo normal de OneDrive, la confirmación de la unidad encontrada
            # tiene true como valor recomendado.
            if isinstance(default, bool):
                return "true" if default else "false"
            if str(default).lower() in {"true", "false"}:
                return str(default).lower()
            if "found drive" in help_text.lower():
                return "true"

        # Si una futura versión de rclone añade una pregunta, seguimos dentro de la GUI
        # en vez de volver a exponer la terminal.
        if examples:
            return self.ask_choice(option)
        return self.ask_text(option)

    def choose_drive(self, examples: list[Any]) -> str:
        choices: list[tuple[str, str]] = []
        for item in examples:
            if not isinstance(item, dict):
                continue
            value = str(item.get("Value", "") or "")
            label = str(item.get("Help", "") or value)
            if value:
                choices.append((value, label))
        if not choices:
            raise RuntimeError("rclone no devolvió ninguna unidad de OneDrive seleccionable.")

        recommended = [
            pair for pair in choices
            if pair[1].strip().lower().startswith("onedrive (")
            and ("personal" in pair[1].lower() or "business" in pair[1].lower())
        ]
        if len(recommended) == 1:
            GLib.idle_add(self.set_status, f"OneDrive detectado: {recommended[0][1]}")
            return recommended[0][0]

        # Si no hay una coincidencia inequívoca, el usuario elige visualmente.
        return self.request_choice(
            "Selecciona tu OneDrive",
            "Microsoft ha devuelto varias unidades. Elige la que quieres montar con esta aplicación.",
            choices,
        )

    def ask_choice(self, option: dict[str, Any]) -> str:
        choices: list[tuple[str, str]] = []
        for item in option.get("Examples") or []:
            if isinstance(item, dict):
                value = str(item.get("Value", "") or "")
                label = str(item.get("Help", "") or value)
                choices.append((value, label))
        if not choices:
            return str(option.get("Default", "") or "")
        return self.request_choice(
            str(option.get("Name", "Configuración")),
            str(option.get("Help", "Elige una opción para continuar.")),
            choices,
        )

    def ask_text(self, option: dict[str, Any]) -> str:
        event = threading.Event()
        holder: dict[str, str | None] = {"value": None}

        def show_dialog() -> bool:
            dialog = Gtk.Dialog(title="Configuración de OneDrive", transient_for=self, modal=True)
            dialog.set_default_size(520, 220)
            dialog.set_resizable(True)
            dialog.add_button("Cancelar", Gtk.ResponseType.CANCEL)
            dialog.add_button("Continuar", Gtk.ResponseType.OK)
            box = dialog.get_content_area()
            box.set_spacing(10)
            help_label = Gtk.Label(label=str(option.get("Help", "")))
            help_label.set_xalign(0)
            help_label.set_line_wrap(True)
            help_label.set_max_width_chars(60)
            entry = Gtk.Entry()
            default = option.get("Default")
            if default not in (None, ""):
                entry.set_text(str(default))
            if bool(option.get("IsPassword")):
                entry.set_visibility(False)
            box.pack_start(help_label, False, False, 0)
            box.pack_start(entry, False, False, 0)
            dialog.show_all()
            response = dialog.run()
            if response == Gtk.ResponseType.OK:
                holder["value"] = entry.get_text()
            dialog.destroy()
            event.set()
            return False

        GLib.idle_add(show_dialog)
        event.wait()
        if holder["value"] is None:
            raise CancelledByUser()
        return str(holder["value"])

    def request_choice(self, title: str, message: str, choices: list[tuple[str, str]]) -> str:
        event = threading.Event()
        holder: dict[str, str | None] = {"value": None}

        def show_dialog() -> bool:
            dialog = Gtk.Dialog(title=title, transient_for=self, modal=True)
            dialog.set_default_size(520, 220)
            dialog.set_resizable(True)
            dialog.add_button("Cancelar", Gtk.ResponseType.CANCEL)
            dialog.add_button("Continuar", Gtk.ResponseType.OK)
            box = dialog.get_content_area()
            box.set_spacing(10)
            label = Gtk.Label(label=message)
            label.set_xalign(0)
            label.set_line_wrap(True)
            label.set_max_width_chars(60)
            combo = Gtk.ComboBoxText()
            combo.set_hexpand(True)
            for value, visible in choices:
                combo.append(value, visible)
            combo.set_active(0)
            box.pack_start(label, False, False, 0)
            box.pack_start(combo, False, False, 0)
            dialog.show_all()
            response = dialog.run()
            if response == Gtk.ResponseType.OK:
                holder["value"] = combo.get_active_id()
            dialog.destroy()
            event.set()
            return False

        GLib.idle_add(show_dialog)
        event.wait()
        if not holder["value"]:
            raise CancelledByUser()
        return str(holder["value"])

    def cleanup_partial_remote(self) -> None:
        if not self.created_remote:
            return
        try:
            if self.created_remote in list_remote_names():
                run_rclone(["config", "delete", self.created_remote])
        except Exception:
            pass

    def show_success(self, remote: str) -> bool:
        self.worker_running = False
        self.set_busy(False)
        self.clear_box(self.content)
        self.clear_box(self.buttons)
        self.set_status("")

        label = Gtk.Label()
        label.set_xalign(0)
        label.set_line_wrap(True)
        label.set_markup(
            "<span size='large' weight='bold'>✓ OneDrive está configurado</span>\n\n"
            "La cuenta se ha guardado en rclone y la aplicación ya puede utilizarla."
        )
        self.content.pack_start(label, True, True, 0)

        finish_label = "Finalizar y abrir OneDrive" if self.resume_mount else "Finalizar"
        self.buttons.pack_start(
            self.make_button(finish_label, lambda *_: self.launch_mount_and_exit() if self.resume_mount else Gtk.main_quit(), suggested=True),
            False,
            False,
            0,
        )
        self.show_all()
        return False

    def show_error(self, message: str) -> bool:
        self.worker_running = False
        self.set_busy(False)
        self.clear_box(self.content)
        self.clear_box(self.buttons)
        self.set_status("")
        label = Gtk.Label()
        label.set_xalign(0)
        label.set_line_wrap(True)
        label.set_markup("<b>No se pudo completar la configuración de OneDrive.</b>")
        detail = Gtk.Label(label=message)
        detail.set_xalign(0)
        detail.set_line_wrap(True)
        self.content.pack_start(label, False, False, 0)
        self.content.pack_start(detail, False, False, 0)
        self.buttons.pack_start(self.make_button("Cerrar", lambda *_: Gtk.main_quit()), False, False, 0)
        self.buttons.pack_start(self.make_button("Reintentar", lambda *_: self.show_initial_state(), suggested=True), False, False, 0)
        self.show_all()
        return False

    def show_cancelled(self) -> bool:
        self.worker_running = False
        self.set_busy(False)
        self.show_initial_state()
        self.set_status("Configuración cancelada. No se ha guardado una cuenta nueva.")
        return False

    def launch_mount_and_exit(self) -> bool:
        if MOUNT_SCRIPT.is_file() and os.access(MOUNT_SCRIPT, os.X_OK):
            env = os.environ.copy()
            env["ONEDRIVE_SKIP_SETUP"] = "1"
            subprocess.Popen([str(MOUNT_SCRIPT)], env=env, start_new_session=True)
        Gtk.main_quit()
        return False

    def on_delete(self, *_args):
        # Cerrar la ventana no desmonta ni modifica nada del funcionamiento normal.
        return False


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--from-launcher", action="store_true")
    parser.add_argument("--resume-mount", action="store_true")
    parser.add_argument("--interactive", action="store_true")
    return parser.parse_known_args()[0]


def main() -> int:
    args = parse_args()
    resume = bool(args.from_launcher or args.resume_mount)
    window = OneDriveSetup(resume_mount=resume)
    window.show_all()
    Gtk.main()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
