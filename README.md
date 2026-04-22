# dotfiles — CachyOS / Qtile

Configuración personal para CachyOS con Qtile en MacBook Pro 2014.
Rama `cachyos` del repositorio de dotfiles.

---

## Requisitos previos

- CachyOS instalado con Qtile como entorno de escritorio
- Particionado GPT con EFI (recomendado: `/` 60GB, `/home` resto, swap 8GB)
- Conexión a internet activa

---

## Instalación

### 1. Instalar dependencias del sistema

```bash
sudo pacman -S git stow blueman nwg-look xorg-xev gvfs flameshot \
               lm_sensors dunst pavucontrol alacritty thunar rofi
```

```bash
paru -S mbpfan
```

> Si `paru` no está instalado: `sudo pacman -S paru`

### 2. Habilitar servicios

```bash
sudo systemctl enable --now bluetooth
sudo systemctl enable --now mbpfan
```

### 3. Configurar SSH y clonar el repositorio

```bash
# Generar clave SSH
ssh-keygen -t ed25519 -C "tu@email.com"

# Mostrar clave pública para agregar en GitHub → Settings → SSH keys
cat ~/.ssh/id_ed25519.pub

# Verificar conexión
ssh -T git@github.com

# Clonar el repo
git clone git@github.com:jhonayodev/dotfiles.git ~/dotfiles

# Cambiar a la rama cachyos
cd ~/dotfiles
git checkout cachyos
```

### 4. Aplicar dotfiles con Stow

Antes de aplicar Stow hay que eliminar los archivos originales que CachyOS genera por defecto, ya que Stow falla si el destino ya existe.

```bash
# Eliminar configs por defecto
rm -f ~/.config/qtile/config.py
rm -f ~/.config/qtile/scripts/autostart.sh
rm -f ~/.config/qtile/scripts/picom.conf
rm -f ~/.gtkrc-2.0

# Aplicar paquetes de Stow
cd ~/dotfiles
stow qtile
stow rofi
stow gtk
```

Verificar que los symlinks quedaron correctos:

```bash
ls -la ~/.config/qtile/config.py
ls -la ~/.config/rofi/themes
```

La salida debe mostrar algo como:
```
~/.config/qtile/config.py -> /home/tu_usuario/dotfiles/qtile/.config/qtile/config.py
```

### 5. Dar permisos de ejecución a los scripts

```bash
chmod +x ~/.config/qtile/scripts/autostart.sh
chmod +x ~/.config/qtile/scripts/start_qtile.sh
chmod +x ~/.config/qtile/scripts/kb_toggle.sh
chmod +x ~/.config/qtile/scripts/trackpad_toggle.sh
chmod +x ~/.config/rofi/scripts/control_center.sh
chmod +x ~/.config/rofi/scripts/system/*.sh
```

### 6. Configurar el entry de sesión de Qtile

Este paso es necesario para que los monitores se configuren correctamente antes de que Qtile arranque. Sin esto, la pantalla interna del Mac (eDP-1) se detecta como un tercer monitor aunque esté apagada.

```bash
sudo nano /usr/share/xsessions/qtile.desktop
```

Cambiar:
```
Exec=qtile start
```
Por:
```
Exec=/home/TU_USUARIO/.config/qtile/scripts/start_qtile.sh
```

> Reemplazar `TU_USUARIO` por el nombre de usuario real.

### 7. Configurar tema GTK oscuro

```bash
nwg-look
```

Seleccionar un tema oscuro en la pestaña de temas e íconos.

### 8. Detectar sensores de temperatura

```bash
sudo sensors-detect
```

Aceptar todo con Enter. Necesario para que el widget de temperatura en la barra funcione correctamente.

### 9. Reiniciar sesión

Cerrar sesión y volver a entrar para que todos los cambios tomen efecto.

---

## Backups con Timeshift

Timeshift permite crear snapshots del sistema para restaurarlo en caso de problemas.

### Instalación

```bash
sudo pacman -S timeshift
paru -S timeshift-autosnap
```

`timeshift-autosnap` crea un snapshot automático antes de cada actualización del sistema con `pacman`.

### Configuración

```bash
sudo timeshift-gtk
```

Configuración recomendada:
- **Tipo de snapshot:** RSYNC
- **Frecuencia:** mensual o manual
- **Cantidad a conservar:** 3-5 snapshots
- **Directorio:** partición con espacio suficiente

---

## Estructura del repositorio

```
dotfiles/                         (rama cachyos)
├── qtile/
│   └── .config/
│       └── qtile/
│           ├── config.py                 # Configuración principal de Qtile
│           └── scripts/
│               ├── autostart.sh          # Apps al iniciar sesión
│               ├── start_qtile.sh        # Wrapper de monitores + Qtile
│               ├── kb_toggle.sh          # Toggle teclado US/ES
│               ├── trackpad_toggle.sh    # Toggle trackpad (Mac)
│               └── picom.conf            # Configuración del compositor
├── rofi/
│   └── .config/
│       └── rofi/
│           ├── themes/
│           │   ├── control-center.rasi   # Tema launcher de apps
│           │   └── submenu.rasi          # Tema control center y submenús
│           └── scripts/
│               ├── control_center.sh     # Control center (bluetooth, audio, power)
│               └── system/
│                   ├── bluetooth.sh      # Gestor bluetooth
│                   ├── audio_output.sh   # Selector de salida de audio
│                   └── power.sh          # Menú de energía
└── gtk/
    ├── .config/
    │   └── gtk-3.0/
    │       └── settings.ini              # Tema GTK3 oscuro
    └── .gtkrc-2.0                        # Tema GTK2 oscuro
```

---

## Keybinds

### Navegación

| Atajo | Acción |
|-------|--------|
| `Super + h/j/k/l` | Mover foco entre ventanas |
| `Super + Space` | Siguiente ventana |
| `Super + .` | Foco al siguiente monitor |
| `Super + ,` | Foco al monitor anterior |

### Ventanas

| Atajo | Acción |
|-------|--------|
| `Super + Shift + h/j/k/l` | Mover ventana en el layout |
| `Super + Shift + →` | Agrandar master (layout Tile) |
| `Super + Shift + ←` | Achicar master (layout Tile) |
| `Super + n` | Normalizar tamaños |
| `Super + f` | Pantalla completa |
| `Super + v` | Toggle flotante |
| `Super + q` | Cerrar ventana |
| `Super + s` | Toggle sticky |

### Grupos y monitores

| Atajo | Acción |
|-------|--------|
| `Super + 1-8` | Ir al grupo N |
| `Super + Shift + 1-8` | Mover ventana al grupo N |
| `Super + Shift + .` | Mover ventana al siguiente monitor |
| `Super + Shift + ,` | Mover ventana al monitor anterior |

### Sistema

| Atajo | Acción |
|-------|--------|
| `Super + Return` | Terminal (alacritty) |
| `Super + Tab` | Cambiar layout |
| `Super + Ctrl + R` | Recargar config de Qtile |
| `Super + Ctrl + Q` | Salir de Qtile |
| `Super + Space` | Launcher de apps (rofi drun) |
| `Alt + Space` | Control center (bluetooth, audio, power) |
| `Super + e` | Gestor de archivos (thunar) |
| `Super + m` | Alternar teclado US/ES |
| `Super + p` | Screenshot región (flameshot) |
| `Super + Shift + p` | Screenshot completo → ~/Pictures/ |
| `XF86LaunchB` | Toggle trackpad (solo teclado Mac) |

### Media

| Atajo | Acción |
|-------|--------|
| Teclas de brillo | brightnessctl ±5% |
| Teclas de volumen | pactl |
| Play/Prev/Next | playerctl |

---

## Grupos (workspaces)

El sistema tiene 8 grupos distribuidos según los monitores activos:

```
1 monitor  → barra muestra P1 P2 P3 P4
2 monitores → monitor principal:  P1 P2 P3 P4  (grupos 1-4)
              monitor secundario: S1 S2 S3 S4  (grupos 5-8)
```

Cada monitor arranca en su primer grupo al iniciar sesión.

---

## Layouts disponibles

| Layout | Descripción |
|--------|-------------|
| Tile | Master izquierda + stack derecha. Comportamiento similar a dwm. |
| Columns | Tiling por columnas. |
| Max | Una ventana ocupa toda la pantalla (barra visible). |

---

## Notas

**Ruta absoluta en `lazy.spawn`**
Qtile no expande `~` en rutas dentro de `lazy.spawn`. Usar siempre ruta absoluta:
```python
# No funciona
lazy.spawn('~/.config/qtile/scripts/script.sh')

# Correcto
lazy.spawn('/home/jhonayo/.config/qtile/scripts/script.sh')
```

**Cambio de monitores en caliente**
Si se conectan o desconectan monitores con Qtile corriendo, es necesario cerrar sesión y volver a entrar para que los screens se recalculen correctamente.

**Systray**
`widget.Systray` solo puede existir una vez en toda la config. Está en la barra del monitor principal únicamente.

**Pantalla interna del Mac**
El script `start_qtile.sh` apaga `eDP-1` si hay monitores externos conectados. Sin este paso, Qtile crea un tercer screen fantasma con la pantalla interna aunque esté cerrada.
