# OneDrive Rclone — v1.5

Indicador GTK/Ayatana para montar OneDrive mediante `rclone`, conservando el funcionamiento original del proyecto y añadiendo portabilidad entre distribuciones Linux y un asistente gráfico de primera configuración.

## Funcionamiento

Al abrir el lanzador **OneDrive**:

1. Se comprueba si `rclone` está disponible y si existe un remoto OneDrive válido.
2. Si falta la configuración, se abre el asistente gráfico de primera ejecución.
3. Cuando la cuenta está configurada, se ejecuta el mismo montaje usado por el programa original.
4. Se abre `~/OneDrive` y se inicia el indicador del tray.

El montaje conserva los parámetros del proyecto original, incluidos `--vfs-cache-mode full`, `--dir-cache-time 5m`, `--poll-interval 1m`, `--allow-non-empty`, `--vfs-cache-max-size 150G`, `--vfs-cache-max-age 720h` y el servidor RC utilizado por el indicador.

## Idiomas

Desde la versión **1.5**, al iniciar `install.sh` puedes elegir **Español** o **English**. La elección se guarda en `~/.config/onedrive-rclone/settings.env` y se aplica de forma persistente a:

- el asistente de instalación;
- el asistente gráfico de configuración de rclone/OneDrive;
- el menú del tray;
- las notificaciones, estados y ventana de progreso;
- los mensajes auxiliares del programa.

La integración de idioma no cambia los parámetros de montaje ni la lógica de funcionamiento de OneDrive/rclone.

## Instalación

Ejecuta:

```bash
bash install.sh
```

El instalador detecta la familia de distribución y prepara las dependencias:

- Debian, Ubuntu y derivadas: `apt`
- Arch, Manjaro y derivadas: `pacman`
- SteamOS: `rclone` portátil en `~/.local/bin` y comprobación de dependencias GTK/Ayatana
- Fedora y derivadas: `dnf`
- openSUSE: `zypper`
- Otras distribuciones: instalación portátil de `rclone` y comprobación de dependencias

La instalación **no configura la cuenta de OneDrive**. Esa configuración solo aparece cuando el usuario abre el icono **OneDrive** por primera vez y no existe un remoto válido.

Archivos instalados principalmente en:

- `~/.local/share/onedrive-rclone`
- `~/.local/bin/montar_onedrive.sh`
- `~/.local/share/applications/montar_onedrive.desktop`

## Asistente gráfico de primera configuración

El asistente usa el protocolo no interactivo de configuración de rclone para evitar exponer la terminal. Mantiene ocultas y predefinidas las opciones normales:

- remoto nuevo con nombre `onedrive` (o `onedrive-2`, etc. si el nombre ya existe)
- backend `onedrive`
- `client_id` vacío
- `client_secret` vacío
- región `global` por defecto
- `tenant` vacío
- configuración avanzada desactivada
- autenticación mediante navegador local
- tipo de conexión `OneDrive Personal or Business`

El usuario normalmente solo tiene que:

1. Pulsar **Conectar cuenta Microsoft**.
2. Iniciar sesión y autorizar rclone en el navegador.
3. Elegir una unidad únicamente si no se puede identificar de forma inequívoca `OneDrive (personal)`.
4. Pulsar **Finalizar y abrir OneDrive**.

Los tokens OAuth los gestiona y almacena directamente rclone en su propia configuración. La aplicación no los muestra ni los copia a sus archivos de configuración.

Si ya existe un único remoto de tipo OneDrive, se utiliza directamente. Si existen varios, el asistente muestra una selección gráfica.

## Menú del indicador

El menú conserva las opciones del programa original:

- **Abrir carpeta OneDrive**: abre el punto de montaje.
- **Ver OneDrive en línea**: abre OneDrive web.
- **Papelera de reciclaje**: abre la papelera web de OneDrive.
- **Caché > Limpiar caché OneDrive**: borra el contenido de la caché de rclone.
- **Caché > Tamaño de la caché**: muestra cuánto ocupa la caché.
- **Ver progreso > Notificación**: muestra las transferencias actuales mediante notificación.
- **Ver progreso > Barra de Progreso**: abre la ventana gráfica de progreso.
- **Salir**: desmonta OneDrive, detiene el `rclone mount` correspondiente y cierra el indicador.

## Estados del icono del tray

El indicador comprueba periódicamente el estado sin cambiar el resto del funcionamiento:

- icono conectado: OneDrive montado, rclone responde y Microsoft/OneDrive está accesible, sin transferencias activas;
- icono de sincronización: existen transferencias activas;
- icono de advertencia: el montaje se ha perdido, el RC de rclone no responde o el remoto de OneDrive ya no es accesible.

## Configuración opcional

Variables compatibles:

- `ONEDRIVE_REMOTE`: remoto de rclone.
- `ONEDRIVE_MOUNTPOINT`: punto de montaje, por defecto `~/OneDrive`.
- `ONEDRIVE_CACHE_DIR`: caché de rclone, por defecto `~/.cache/rclone`.
- `ONEDRIVE_RC_URL`: URL del servidor RC, por defecto `http://localhost:5572/core/stats`.

## Desinstalación

```bash
bash ~/.local/share/onedrive-rclone/uninstall.sh
```

## Licencia

MIT. Ver [LICENSE](LICENSE).
