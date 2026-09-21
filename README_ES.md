# OneDrive para Linux — cliente de escritorio con rclone para Ubuntu, SteamOS, Arch, Fedora y openSUSE

[English version](README.md)

Cliente ligero de **OneDrive para Linux** basado en **rclone**, con icono en la bandeja del sistema, montaje y desmontaje, progreso de transferencias, herramientas de caché y asistente de primera configuración.

Está pensado para **Ubuntu, Debian, SteamOS / Steam Deck, Arch Linux, Fedora, openSUSE y otras distribuciones Linux de escritorio**.

## Funciones principales

- Montaje de Microsoft OneDrive mediante `rclone mount`.
- Lanzador mostrado simplemente como **OneDrive**.
- Icono en el tray con estados: conectado, sincronizando y desconectado.
- Apertura de la carpeta local de OneDrive desde el tray.
- Acceso a OneDrive web y a la papelera.
- Progreso de transferencias mediante notificación o ventana GTK.
- Consulta y limpieza de la caché de rclone.
- Aviso automático por tamaño de caché.
- **Salir** desmonta OneDrive, detiene el `rclone mount` correspondiente y cierra el indicador.
- Asistente de instalación y primera configuración de rclone.
- Detección automática de distribución Linux.
- Instaladores específicos para Ubuntu/Debian, Arch, Fedora, openSUSE y SteamOS.
- Detección automática de remotos rclone con backend `onedrive`.

## Distribuciones compatibles

- Ubuntu / Debian y derivadas (`apt`)
- Arch Linux y derivadas (`pacman`)
- Fedora / familia RHEL (`dnf`)
- openSUSE (`zypper`)
- SteamOS / Steam Deck
- Linux genérico como alternativa

La aplicación usa GTK 3 y prefiere Ayatana AppIndicator, con AppIndicator3 como alternativa compatible.

## Instalación

```bash
chmod +x install.sh
./install.sh
```

El instalador detecta la distribución, ofrece instalar las dependencias necesarias e instala la aplicación en rutas de usuario:

```text
~/.local/share/onedrive-rclone
~/.local/bin/montar_onedrive.sh
~/.local/share/applications/montar_onedrive.desktop
```

Después aparecerá **OneDrive** en el lanzador de aplicaciones.

## Primera configuración de rclone

Si rclone no está instalado o todavía no existe una configuración válida de OneDrive, el asistente se ejecuta automáticamente. Detecta la distribución, instala rclone si hace falta, busca remotos con `type = onedrive`, permite elegir entre varios si existen y guarda el remoto seleccionado.

La autorización de Microsoft se realiza mediante el flujo OAuth normal de rclone en el navegador.

## Steam Deck / SteamOS

El proyecto incluye un instalador específico para SteamOS. Siempre que es posible, rclone se instala en el entorno local del usuario para evitar depender de cambios permanentes en la imagen de sistema.

Ejecuta el instalador desde **Desktop Mode**:

```bash
chmod +x install.sh
./install.sh
```

## Opciones del tray

- **Abrir carpeta OneDrive**
- **Ver OneDrive en línea**
- **Papelera de reciclaje**
- **Caché** → limpiar caché / mostrar tamaño
- **Ver progreso** → notificación / barra de progreso GTK
- **Salir** → desmonta OneDrive, detiene rclone mount y cierra el indicador

## Estados del icono

- **OneDrive**: montado, conectado y sin transferencias activas.
- **Sincronizando**: existen transferencias activas.
- **Advertencia**: OneDrive no está montado o el RC de rclone no responde.

## Parámetros de montaje

```text
--rc
--rc-no-auth
--vfs-cache-mode full
--dir-cache-time 5m
--poll-interval 1m
--allow-non-empty
--volname OneDrive
--vfs-cache-max-size 150G
--vfs-cache-max-age 720h
```

## Configuración avanzada

```text
ONEDRIVE_REMOTE
ONEDRIVE_MOUNTPOINT
ONEDRIVE_CACHE_DIR
ONEDRIVE_LOGFILE
ONEDRIVE_INDICATOR
ONEDRIVE_RC_URL
ONEDRIVE_CACHE_THRESHOLD
ONEDRIVE_NOTIFY_INTERVAL
```

Valores predeterminados:

```text
Remoto:         Onedrive:
Punto montaje:  ~/OneDrive
Caché:          ~/.cache/rclone
RC URL:         http://localhost:5572/core/stats
```

## Desinstalación

```bash
~/.local/share/onedrive-rclone/uninstall.sh
```

## Licencia

MIT — consulta [LICENSE](LICENSE).

## Palabras clave

OneDrive Linux, OneDrive Ubuntu, OneDrive Steam Deck, OneDrive SteamOS, OneDrive Arch Linux, OneDrive Fedora, OneDrive openSUSE, rclone OneDrive, icono OneDrive Linux, montar OneDrive Linux, cliente Microsoft OneDrive Linux.
