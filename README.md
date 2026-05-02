# Proceso de clean install

## Instalar

```bash
sudo apt install git
sudo apt install tree
sudo apt install curl
sudo apt install mbpfan
sudo apt install stow
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
Después de instalarlo hay que decirle a GDM que existe:

```bash

sudo nano /usr/share/xsessions/qtile.desktop
```

pegar:

```bash
[Desktop Entry]
Name=Qtile
Comment=Qtile Window Manager
Exec=/home/jhonayo/.local/bin/qtile start
Type=Application
Keywords=wm;tiling
```

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

#### control volumen logi

```bash
ls /dev/input/by-id/
python3 -m evdev 2>/dev/null || sudo apt install python3-evdev -y
sudo usermod -aG input $USER

```

- permisos de ejecucion al script de control de mouse

```bash
chmod +x ~/dotfiles/scripts/mouse-buttons.py
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
