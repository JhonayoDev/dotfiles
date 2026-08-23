# Proceso de clean install

## Instalar

```bash
sudo apt install git
sudo apt install tree
sudo apt install curl
sudo apt install mbpfan
sudo apt install stow
sudo apt install jq
```

```bash
sudo systemctl enable --now mbpfan
```

## Configuracion

### git

#### configuracion local user

```bash

git config --global user.name jhonayo
git config --global user.email j.iramirezpavez@gmail.com

```

#### configuracion de clave ssh

```bash
ssh-keygen -t ed25519 -C "j.iramirezpavez@gmail.com"
```

```bash
cat ~/.ssh/id_ed25519.pub
```

- Agregarla a GitHub

1- Ve a github.com → Settings → SSH and GPG keys
2- Click en New SSH key
3- Ponle un nombre (ej: ubuntu-macbook)
4- Pega la clave
5- Click Add SSH key

- Verificar conexion

```bash
ssh -T git@github.com
```

### dotfiles

#### creacion de directorio dotfiles

```bash
mkdir ~/dotfiles
```

#### clonar repositorio de dotfiles

```bash
git clone git@github.com:JhonayoDev/dotfiles.git dotfiles/
```

cambiar de rama a ubuntu

```bash
git branch -a
git checkout -t origin/rama

o

git switch --track origin/rama
```

#### wezterm

- instalacion con links oficiales

```bash
curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | sudo tee /etc/apt/sources.list.d/wezterm.list
sudo chmod 644 /usr/share/keyrings/wezterm-fury.gpg
```

Update your dependencies:

```bash
sudo apt update
```

Now you can install wezterm:

```bash
sudo apt install wezterm
```

pasar configuracion

```bash
cd ~/dotfiles
stow wezterm
```

#### nvim

- sacado desde pagina oficial de nvim

```bash
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
sudo rm -rf /opt/nvim-linux-x86_64
sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz

```

- importar variabla a archivo de configuracion segun info oficial en :
  add this to your shell config (~/.bashrc, ~/.zshrc, …):

```bash
export PATH="$PATH:/opt/nvim-linux-x86_64/bin"

```

- cambiar de terminal para reiniciar

- hacer el link de la configuracion de nvim

```bash
cd ~/dotfiles
stow nvim
```

##### Revision de nvim

para poder copiar fuera de la terminal

```bash
sudo apt install -y xclip
```

- para funcionamiento de nvim y plugins

```bash
# Instalar ripgrep, fd-find, fzf primero
sudo apt install -y ripgrep fd-find fzf

# Symlink para fd
ln -s $(which fdfind) ~/.local/bin/fd

git clone https://github.com/zsh-users/zsh-autosuggestions \
  ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions

# zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-syntax-highlighting \
  ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting

# zsh-completions
git clone https://github.com/zsh-users/zsh-completions \
  ~/.oh-my-zsh/custom/plugins/zsh-completions

```

instalacion de Lazy git

```bash
LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
curl -Lo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
tar xf /tmp/lazygit.tar.gz -C /tmp lazygit
sudo install /tmp/lazygit /usr/local/bin
```

instalación de node para plugins:

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs
node --version
```

Recargar

```bash
source ~/.zshrc
```

#### descargar fuentes para terminal

- descargar fuentes Nerd Font

```bash
https://www.nerdfonts.com/font-downloads

```

> Fuente descargada JetBrainsMono Nerd Font

1. Instalar solo la versión “Mono” (recomendada)

   Vamos a usar la carpeta del sistema de usuario

   ```bash
   mkdir -p ~/.local/share/fonts
   ```

   Ahora copia SOLO las fuentes Mono (las más útiles para terminal, nvim y qtile)

   ```bash
   cp *Mono*.ttf ~/.local/share/fonts/
   ```

1. actualizar caché de fuentes

   ```bash
   fc-cache -fv
   ```

1. verificar instalación

   ```bash
   fc-list | grep -i "JetBrainsMono"
   ```

   Deberías ver algo como:

   > ```bash
   > JetBrainsMono Nerd Font Mono
   > ```

1. usarla en tus apps

   > > [!IMPORTANT]
   > > Terminal (Alacritty / Kitty / etc.)
   > > font:
   > > normal:
   > > family: JetBrainsMono Nerd Font Mono
   > > Neovim

   Solo asegúrate de usar:

   JetBrainsMono Nerd Font Mono

   Qtile
   font = "JetBrainsMono Nerd Font"

#### zshrc

- instalar zsh

```bash
sudo apt install zshrc
```

- cambiar la shell por directorio

```bash
chsh -s $(which zsh)
```

- verificar:

```bash
echo $SHELL
```

> **debe mostrar:**
> /usr/bin/zsh

##### copiar la configuracion de zshrc

```bash
cd ~/dotfiles
stow zsh
```

##### instalar los plugins necesarios sin sobre escribir

1. Oh My zsh

   ```bash
   KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

   ```

1. Powerlevel10k

   ```bash
   git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
     ~/.oh-my-zsh/custom/themes/powerlevel10k
   ```

1. Instalar los plugins custom que tienes en tu config

   ```bash
   # zsh-autosuggestions
   git clone https://github.com/zsh-users/zsh-autosuggestions \
     ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions

   # zsh-syntax-highlighting
   git clone https://github.com/zsh-users/zsh-syntax-highlighting \
     ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting

   # zsh-completions
   git clone https://github.com/zsh-users/zsh-completions \
     ~/.oh-my-zsh/custom/plugins/zsh-completions

   ```

1. Recargar

   ```bash
   source ~/.zshrc
   ```

#### Instalar Qtile

instalación

```bash
# Dependencias del sistema
sudo apt install -y \
  python3-pip \
  python3-xcffib \
  python3-cairocffi \
  python3-dbus \
  libpangocairo-1.0-0 \
  python3-dev \
  libxcb-render0-dev \
  libffi-dev \
  libxcb1-dev

# Instalar Qtile
pip install qtile --break-system-packages

```

Registrar Qtile como sesión en GDM
Después de instalarlo hay que decirle a GDM que existe. **Este paso es manual y obligatorio en cada clean install** — `stow` no puede hacerlo porque `/usr/share/xsessions` está fuera de `$HOME` (no es parte de `install.sh` que usas para devcontainer):

```bash
sudo nano /usr/share/xsessions/qtile.desktop
```

pegar **exactamente** esto (actualizado 2026-08-23 — ver “Decisión monitores” abajo para el POR QUÉ):

```bash
[Desktop Entry]
Name=Qtile
Comment=Qtile Window Manager
Exec=/home/jhonayo/.config/qtile/scripts/start_qtile.sh
Type=Application
Keywords=wm;tiling
```

> [!IMPORTANT]
> **POR QUÉ `Exec` debe ser `start_qtile.sh` y NO `/home/jhonayo/.local/bin/qtile start`:**
> * `start_qtile.sh` ejecuta `~/.config/qtile/scripts/monitors.sh` **ANTES** de que Qtile arranque. Así `config.py:111 get_num_monitors()` ya ve los 2 HDMI y `screens:653` nace correcto (1 solo evento RandR).
> * Si apuntas directo a `qtile start`, el `xrandr` se haría **después** vía `autostart.sh` (hook `startup_once:713`). Eso provocaba el bug histórico: barra “mal” al iniciar y luego se corregía con un refresco tardío + obligaba a cerrar sesión para hotplug. Fue lo que se arregló el 2026-08-23.
> * Antes existía también `--scale 1.12` en `monitors.sh` que causaba un **doble refresh** (mode + scale = 2 eventos RandR). Se eliminó a propósito — se prioriza velocidad sobre uniformidad de tamaño entre monitores (ver sección “Decisión monitores”).
> * Si en el futuro migras de PC y olvidas este paso, el síntoma volverá: arranque lento + barra que parpadea. Verifica con `cat /usr/share/xsessions/qtile.desktop` que `Exec` apunte al wrapper.

Comando idempotente para replicar sin editor (útil para pegar directo):

```bash
sudo install -Dm644 /dev/stdin /usr/share/xsessions/qtile.desktop <<'EOF'
[Desktop Entry]
Name=Qtile
Comment=Qtile Window Manager
Exec=/home/jhonayo/.config/qtile/scripts/start_qtile.sh
Type=Application
Keywords=wm;tiling
EOF
cat /usr/share/xsessions/qtile.desktop
```

> Nota: también se deja una copia en `~/.local/share/xsessions/qtile.desktop` para referencia, pero **GDM en Ubuntu solo lee `/usr/share/xsessions`** — esa copia no sustituye el paso con `sudo`.

incorporar en el PATH

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

```

Verifica:

```bash

qtile --version
```

copiar configuracion de qtile

```bash

cd ~/dotfiles/
stow qtile

```

verificar sysmlinks

```bash
 ls -la ~/.config/qtile

```

> [!IMPORTANT]
> verificar la integridad de el config.py de qtile
>
> ```bash
> python3 -c "import ast; ast.parse(open('/home/jhonayo/dotfiles/qtile/.config/qtile/config.py').read()); print('✓ Sintaxis OK')"
> ```

##### Decisión monitores 2026-08-23 — fix arranque lento y hotplug (MacBook Pro 2014, 2x HDMI vía Mini-DP)

**Problema:** Al iniciar con 2 monitores había un refresco tardío — la barra aparecía mal y luego se corregía. Conectar/desconectar un HDMI después de encendido no funcionaba sin cerrar sesión.

**Causa raíz auditada:**
* `config.py:111` calcula `NUM_MONITORS` una sola vez al importar; luego `autostart.sh` hacía `xrandr --auto` **después** de Qtile → `reconfigure_screens=True` disparaba una segunda reconfiguración (flicker).
* Había 3 scripts duplicados: `qtile/scripts/autostart.sh` (activo), `qtile/scripts/start_qtile.sh` (no usado), `scripts/monitors.sh` (huérfano y con `--scale 1.12`).
* El `--scale 1.12` provocaba **doble refresh** (mode + scale = 2 eventos RandR), por eso se había removido previamente y se toleraba la diferencia de tamaño entre monitores.

**Decisión tomada:**
* **Sin escala** (`--scale` omitido): 1 solo evento RandR → arranque rápido, sin doble reconfig. Se prioriza velocidad sobre uniformidad perfecta (diferencia leve de tamaño entre HDMI-1 SAM y HDMI-2 LEN se tolera).
* Fuente única: `qtile/.config/qtile/scripts/monitors.sh` (también espejado en `scripts/monitors.sh`) — sin `--scale`, con `--mode 1920x1080 --pos 0x0` explícito. `start_qtile.sh` lo ejecuta **antes** de `qtile start` (ver `Exec` arriba).
* `autostart.sh` ya no contiene `xrandr`; solo daemons (`picom`, `polkit`, `nm-applet`, etc.).
* Hotplug automático: nuevo hook `@hook.subscribe.screen_change` en `config.py:721` con debounce 0.4s que relanza `monitors.sh` y `qtile.reconfigure_screens()` — ya no hace falta cerrar sesión.
* `monitors.xml` de GNOME se mantiene pero no manda en Qtile; no se usan `autorandr`/`arandr`/`xfce4-display-settings` (no instalados). Si se requieren apps XFCE/GNOME, usarlas solo como editor visual y copiar el comando a `monitors.sh`.

**Para revertir a escala:** ver comentario al final de `monitors.sh` (`--scale 1.12x1.12`) — reactivarlo reintroduce el doble refresh.

##### configuracion adicionar qtile

Instalar:

```bash
sudo apt install -y \
  flameshot \
  brightnessctl \
  playerctl \
  picom \
  btop \
  pulseaudio-utils \
  dunst \
  blueman
```

verificar:

```bash
for app in flameshot brightnessctl playerctl picom btop pactl dunst blueman-applet; do
    which $app 2>/dev/null && echo "✓ $app" || echo "✗ $app"
done
```

instalar faltante:

```bash
sudo apt install -y policykit-1-gnome
```

verificar ruta y comparar con autrostar:

```bash
find /usr -name "polkit-gnome-authentication-agent-1" 2>/dev/null
```

- instalacion de lm sensores para la informacion de sensores del sistema para la Agregarla

```bash
sudo apt install -y lm-sensors
sudo sensors-detect --auto
sensors
```

revisar instalacion para acceso de lectura de los sensores y permisos

```bash
pip install psutil pulsectl pulsectl-asyncio --break-system-packages
```

- Dar permisos de ejecucion a los scripts

```bash
chmod +x ~/dotfiles/qtile/.config/qtile/scripts/*.sh
```

- Dar permisos para botones para el ajuste del brillo en el mac

  > [!IMPORTANT]
  > Recordar dar permisos para que qtile pueda ajustar el brillo del monitor del mac

```bash
sudo usermod -aG video $USER
```

- Uniformar teclas `F1-F12` como en macOS (brillo/teclado/volumen sin `Fn`)

  > [!IMPORTANT]
  > **Paso manual requerido en cada clean install** — por defecto `hid_apple` viene con `fnmode=1` (PC: `F1` es `F1`, necesitas `Fn+F1` para brillo). Para modo macOS (todo símbolo sin `Fn`, `Fn+F1` da `F1` puro para `nvim`):
  >
  > ```bash
  > echo "options hid_apple fnmode=2" | sudo tee /etc/modprobe.d/hid_apple.conf
  > sudo update-initramfs -u
  > # efecto inmediato sin reboot (hasta próximo reinicio):
  > echo 2 | sudo tee /sys/module/hid_apple/parameters/fnmode
  > cat /sys/module/hid_apple/parameters/fnmode  # debe mostrar 2
  > ```
  >
  > **Por qué se hace:** Antes el brillo de pantalla requería `Fn+F1/F2` pero volumen y backlight teclado funcionaban sin `Fn` (eran `XF86*` dedicadas). Para uniformar como en macOS se fijó `fnmode=2` y se bindearon en `keys.py:133` tanto `F1/F2` como `XF86MonBrightnessDown/Up` al mismo `brightness.sh`, así `F1` solo baja brillo y `Fn+F1` da `F1` para apps. Si en el futuro ves que `F1` solo no baja brillo y necesitas `Fn+F1`, verifica `cat /sys/module/hid_apple/parameters/fnmode`.
  >
  > `keys.py:133` ya tiene ambas variantes para cubrir transición y teclados externos.
  >
  > También se añadió backlight teclado `F5/F6` (`XF86KbdBrightness*` → `kbd-backlight.sh`) sin `Fn`, sin auto (ver `qtile/.config/qtile/scripts/kbd-backlight.sh`).

#### Sistema de bloqueo y control de energía (i3lock-color + xss-lock + timeouts configurables)

> Sistema completo: bloqueo con **barra horizontal + blur + hora grande** (`HH:MM` fila 1 grande, `usuario@host` fila 2 pequeño) desde `Control Center → Power → Bloquear`, fondo del tema y tiempos ajustables para procesos largos. Todo versionado en `dotfiles`.

**Instalación (ya la hiciste, para reproducir en clean install):**
```bash
sudo apt install -y xss-lock mpv  # xss-lock puente logind → locker para `loginctl lock-session` y suspensiones
# i3lock-color no está en apt → compilar:
sudo apt install -y autoconf gcc make pkg-config libpam0g-dev libcairo2-dev libfontconfig1-dev libxcb-composite0-dev libev-dev libx11-xcb-dev libxcb-xkb-dev libxcb-xinerama0-dev libxcb-randr0-dev libxcb-image0-dev libxcb-util-dev libxcb-xrm-dev libxkbcommon-dev libxkbcommon-x11-dev libjpeg-dev libgif-dev
git clone https://github.com/Raymo111/i3lock-color /tmp/i3lock-color
cd /tmp/i3lock-color && ./install-i3lock-color.sh  # → /usr/bin/i3lock con bar-indicator + blur
# lock.sh detecta /usr/bin/i3lock con bar-indicator y usa: --bar-indicator --blur 7 --time-size 78 --greeter-text "$USER@$HOST"
```

**Migración desde xsecurelock/mpv (si vienes de la etapa anterior):**
```bash
sudo apt remove --autoremove xsecurelock mpv  # lock.sh ahora usa i3lock-color; xsecurelock queda como fallback si lo dejas
# Mantén xss-lock aunque uses i3lock-color, porque xss-lock hace que `loginctl lock-session` y `suspend` disparen lock.sh
```

**Bloqueo manual (solo cuando lo ejecutes tú, sin auto por ahora):**
* `Control Center → Power → Bloquear` hace `loginctl lock-session` (`rofi/scripts/system/power.sh:23`).
* `xss-lock` lo captura y lanza `qtile/.config/qtile/scripts/lock.sh` (añadido en `autostart.sh:20`):
  ```bash
  xss-lock --transfer-sleep-lock -- ~/.config/qtile/scripts/lock.sh &
  ```
* `lock.sh` usa el mismo wallpaper que `theme.py:6 wallpapers["primary"]` (`~/.config/qtile/Wallpaper/the-milky-way.jpeg`) con `--image --tiling` y colores `bg1/accent` de `colors.rasi` (generado por `apply-theme.py`). Para personalizar después, cambia `wallpapers["primary"]` en `theme.py:6` o edita `WALLPAPER` en `lock.sh:8`.

**Verificación:**
```bash
loginctl lock-session  # o Control Center → Bloquear
# debe aparecer i3lock con fondo y reloj %H:%M
ps aux | grep xss-lock
```

**Tiempos configurables (pantalla / bloqueo / suspensión):**
* Hoy: `idle-delay 300s` (5 min), `DPMS 600s`, `sleep-inactive-ac-type 'nothing' 3600s` (no suspende, ideal para no cortar procesos).
* Script `qtile/.config/qtile/scripts/power-timeouts.sh` (nuevo, versionado):
  ```bash
  ~/.config/qtile/scripts/power-timeouts.sh show    # estado actual
  ~/.config/qtile/scripts/power-timeouts.sh short   # 5 min pantalla, sin suspensión
  ~/.config/qtile/scripts/power-timeouts.sh long    # 30 min pantalla, sin suspensión (para procesos largos)
  ~/.config/qtile/scripts/power-timeouts.sh off     # desactiva suspensión
  ~/.config/qtile/scripts/power-timeouts.sh custom 1800  # 30 min custom
  ```
  Afecta `gsettings idle-delay`, `xset dpms` y `gsettings power sleep-inactive-*`. Usa `off` cuando dejes procesos largos y regreses sin que se suspenda.

**Para activar auto-bloqueo por tiempo en el futuro (configurable, no activo aún):**
```bash
# Ejemplo 10 min: xss-lock ya corre, solo añade xautolock
sudo apt install xautolock
xautolock -time 10 -locker ~/.config/qtile/scripts/lock.sh &
# o vía systemd: logind IdleAction=lock (ver power-timeouts.sh suspend-on)
```

**Próximo paso — fondo login GDM (pantalla al encender):**
* GDM no usa `i3lock`; se configura aparte con `sudo nano /etc/gdm3/greeter.dconf-defaults` y el mismo `Wallpaper/` para consistencia. Se documentará cuando lo personalicemos (también `sudo` como `/usr/share/xsessions/qtile.desktop`).

##### intalacion de deamon para modo oscuro

- instalcion de xsettingsd

```bash
sudo apt install -y xsettingsd
```

- dar vinculo con stow

```bash
cd ~/dotfiles
stow xsettingsd

```

- hacer el link de las configuraciones de gtk

```bash
cd ~/dotfiles
stow gtk
```

#### dunst

- copiar la configuracion de dunst

```bash
cd ~/dotfiles/
stow dunst
```

#### Rofi

```bash
sudo apt install rofi
```

verificar instalación

```bash
rofi -version
```

aplica dotfiles de stow:

```bash
cd ~/dotfiles/
stow rofi

```

verificar los sysmlinks:

```bash
ls -la ~/.config/rofi
```

probar la instalación

```bash
rofi -show drun -theme ~/.config/rofi/themes/control-center.rasi
```

#### control logitech MX Master 3S por Bluetooth (botones extra estables)

> [!IMPORTANT]
> **Reproducible en cada clean install / cambio de PC** — el mouse va por Bluetooth y antes moría tras `DPMS 600s` (pantalla apagada 10 min) y requería logout. Ahora es un servicio `systemd --user` que sobrevive a `DPMS Off`, `suspend` y cambios de `id` `bcm5974/Logitech`.

**Pair Bluetooth (una vez):**
```bash
bluetoothctl
scan on
pair <MAC>  # MAC de Logitech MX Master 3S
trust <MAC>
connect <MAC>
exit
# Opcional para que no se desconecte tras DPMS (mantiene conexión, poco impacto batería):
# sudo nano /etc/bluetooth/main.conf -> IdleTimeout=0
```

**Dependencias y permisos (reproducible):**
```bash
ls /dev/input/by-id/
python3 -m evdev 2>/dev/null || sudo apt install python3-evdev -y
sudo usermod -aG input $USER  # relogin necesario
# ya tienes: sudo usermod -aG input $USER (para evdev /dev/input/event*)
```

**Instalación reproducible del servicio (versionado en dotfiles):**
```bash
chmod +x ~/dotfiles/scripts/mouse-buttons.py
chmod +x ~/dotfiles/services/mouse-buttons.service  # si existe

mkdir -p ~/.config/systemd/user
cp ~/dotfiles/services/mouse-buttons.service ~/.config/systemd/user/mouse-buttons.service
systemctl --user daemon-reload
systemctl --user enable --now mouse-buttons.service

# Verificación
systemctl --user status mouse-buttons.service
journalctl --user -u mouse-buttons.service -f  # logs con [OK]/[WARN]
xinput list --id-only "Logitech MX Master 3S"  # debe dar id (ej 10)
python3 ~/dotfiles/scripts/mouse-buttons.py  # test directo sin servicio
```

**Qué hace el servicio:**
* `services/mouse-buttons.service:1` `Restart=always RestartSec=2` — nunca queda muerto tras `DPMS Off 600`/`suspend`/Bluetooth powersave. Antes `scripts/mouse-buttons.py:24` tenía `MAX_RETRIES 20` y `sys.exit(1)`; ahora es infinito con `RETRY_DELAY 2` y reaplica `xinput set-button-map` tras reconexión (X resetea el mapa tras `DPMS Off`).
* `qtile/.config/qtile/scripts/autostart.sh:20` ahora hace `systemctl --user try-restart mouse-buttons.service` si existe, con fallback a `python3 ... &` si es fresh install sin `enable`. No más `pkill` huérfano.
* Si en futuro no quieres systemd, `autostart.sh` aún lanza directo y el script ya es estable (bucle infinito, no muere).

**Debug sin logout:**
```bash
systemctl --user restart mouse-buttons.service
xinput list-props "Logitech MX Master 3S" | grep "Device Enabled"
journalctl --user -u mouse-buttons.service --since "5 min ago"
```

#### aplicar thema al sistema

- dar permisos al script

```bash
chmod +x ~/dotfiles/scripts/apply-theme.py
```

> [!IMPORTANT]
> aplicar los cambios del theme

```bash
python3 ~/dotfiles/scripts/apply-theme.py
notify-send "Theme" "Colores del tema aplicados"
```

> [!NOTE]
>
> - opcion no aplicada pero posible
>
> ```bash
>    Key([mod, "control"], "t",
>    lazy.spawn("python3 /home/jhonayo/dotfiles/scripts/apply-theme.py"),
>    lazy.reload_config(),
>    desc="Aplicar tema"),
> ```

### Apps adiciones

#### Instalar Docker

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
```

#### Lazydocker

- instalar con comando oficial

```bash
curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
```

- añadir alias

```bas
echo "alias lzd='lazydocker'" >> ~/.zshrc
```

- refrescar terminal

```bash
source ~/.zshrc
```

#### instalacion OnlyOffice y soporte para documentos .Docx

- primer paso hacer update e instalar las fuentes Microsoft en Ubuntu/Debian

```bash
sudo apt update
sudo apt install ttf-mscorefonts-installer -y
sudo fc-cache -f -v
```

- instalar fuentes adiciones
  > !> [!IMPORTANT]
  > . Cambria(queda instalada con el nombre de caladea)
  > . Calibri ( queda instalada con el nombre de Carlito)

```bash
sudo apt install fonts-crosextra-caladea fonts-crosextra-carlito -y
```

- instalar onlyoffice (esta tiene mejor integracion que Libre office)
- descargar:

<https://www.onlyoffice.com/es/download-desktop>

```bash
sudo apt install ./onlyoffice-desktopeditors_amd64.deb -y
```

> !> [!IMPORTANT]
> Para el manejo de referencias recomiendan Zotero, que aun no he instalado

#### instalacion de Tailscale para manejo remoto del servidor

- instalacion via script oficial

```bash
curl -fsSL https://tailscale.com/install.sh | sh
```

- iniciar cliente tailscale

```bash
sudo tailscale up

```

> entrar al link y autenticarse

#### instalacion de devpod

- descarga con link de pagina oficial

```bash
curl -L -o devpod "https://github.com/loft-sh/devpod/releases/latest/download/devpod-linux-amd64" && sudo install -c -m 0755 devpod /usr/local/bin && rm -f devpod
```

##### configuracion

- proveedor es docker

```bash
# Agregar el proveedor docker
devpod provider add docker
```

```bash
# Activarlo como default
devpod provider use docker
```

- verificar

```bash
devpod provider list
```

#### instalacion pnpm

```bash
curl -fsSL https://get.pnpm.io/install.sh | sh -
```

refrescar

```bash
source /home/jhonayo/.zshrc

```

verificar

```bash
pnpm --version
```

para el uso de dadbod ui en nvim despues de instalar pnpm intalar:

```bash
pnpm install -g @mermaid-js/mermaid-cli
```
