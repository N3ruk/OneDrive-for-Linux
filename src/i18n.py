from __future__ import annotations

import os
import shlex
from pathlib import Path

APP_NAME = "onedrive-rclone"
CONFIG_HOME = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
SETTINGS_FILE = CONFIG_HOME / APP_NAME / "settings.env"


def read_settings() -> dict[str, str]:
    values: dict[str, str] = {}
    if not SETTINGS_FILE.is_file():
        return values
    try:
        for line in SETTINGS_FILE.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, raw = line.split("=", 1)
            key = key.strip()
            try:
                parts = shlex.split(raw.strip())
                value = parts[0] if parts else ""
            except ValueError:
                value = raw.strip().strip("'\"")
            values[key] = value
    except OSError:
        pass
    return values


def language() -> str:
    value = os.environ.get("ONEDRIVE_LANG", "").strip().lower()
    if not value:
        value = read_settings().get("ONEDRIVE_LANG", "es").strip().lower()
    return "en" if value.startswith("en") else "es"


def tr(es: str, en: str) -> str:
    return en if language() == "en" else es


def write_setting(key: str, value: str) -> None:
    values = read_settings()
    values[key] = value
    SETTINGS_FILE.parent.mkdir(parents=True, exist_ok=True)
    preferred_order = ["ONEDRIVE_LANG", "ONEDRIVE_REMOTE"]
    keys = [k for k in preferred_order if k in values]
    keys.extend(sorted(k for k in values if k not in preferred_order))
    text = "".join(f"{k}={shlex.quote(values[k])}\n" for k in keys)
    SETTINGS_FILE.write_text(text, encoding="utf-8")
    os.chmod(SETTINGS_FILE, 0o600)
