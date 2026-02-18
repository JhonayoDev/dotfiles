#!/bin/bash
# ~/dotfiles/scripts/install.sh
#
# Restaura todo el entorno en una máquina nueva (Ubuntu/Debian).
# Modo interactivo: pregunta sección por sección antes de ejecutar.
#
# Uso: bash ~/dotfiles/scripts/install.sh

set -euo pipefail

# ─── Configuración ────────────────────────────────────────────────────────────
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
LOG_DIR="$DOTFILES_DIR/logs"
LOG_FILE="$LOG_DIR/install_$(date +%Y%m%d_%H%M%S).log"

NVM_VERSION="0.39.7"
JAVA_VERSION_21="21.0.8-tem"
JAVA_VERSION_17="17.0.16-tem"

# ─── Colores ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ─── Utilidades ───────────────────────────────────────────────────────────────
log()     { echo -e "$*" | tee -a "$LOG_FILE"; }
info()    { log "${BLUE}[INFO]${NC}  $*"; }
success() { log "${GREEN}[OK]${NC}    $*"; }
warn()    { log "${YELLOW}[WARN]${NC}  $*"; }
error()   { log "${RED}[ERROR]${NC} $*"; }
section() {
  log ""
  log "${BOLD}${CYAN}╔══════════════════════════════════════════╗${NC}"
  log "${BOLD}${CYAN}  $*${NC}"
  log "${BOLD}${CYAN}╚══════════════════════════════════════════╝${NC}"
}
cmd_preview() { log "  ${DIM}Comando: $*${NC}"; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

# ─── Prompt interactivo ───────────────────────────────────────────────────────
# Muestra opciones y devuelve la elección del usuario en la variable REPLY_CHOICE
# Uso: ask_choice "Pregunta" "Opción A" "Opción B" ...
ask_choice() {
  local question="$1"
  shift
  local options=("$@")

  echo ""
  echo -e "  ${BOLD}${question}${NC}"
  for i in "${!options[@]}"; do
    echo -e "    ${CYAN}[$((i+1))]${NC} ${options[$i]}"
  done
  echo -e "    ${CYAN}[S]${NC} Omitir esta sección"
  echo -e "    ${CYAN}[Q]${NC} Salir del script"
  echo ""

  while true; do
    read -r -p "  → Elige una opción: " choice
    choice="${choice^^}"  # a mayúsculas

    if [[ "$choice" == "Q" ]]; then
      log "\nInstalación cancelada por el usuario."
      exit 0
    elif [[ "$choice" == "S" ]]; then
      REPLY_CHOICE="SKIP"
      return
    fi

    if [[ "$choice" =~ ^[0-9]+$ ]] && \
       (( choice >= 1 && choice <= ${#options[@]} )); then
      REPLY_CHOICE="${options[$((choice-1))]}"
      return
    fi

    echo -e "  ${RED}Opción inválida. Intenta de nuevo.${NC}"
  done
}

# Pregunta simple S/N
ask_yn() {
  local question="$1"
  local default="${2:-S}"  # S por defecto
  while true; do
    read -r -p "  ${BOLD}${question}${NC} [S/N] (Enter = $default): " yn
    yn="${yn:-$default}"
    yn="${yn^^}"
    case "$yn" in
      S|SI|Y|YES) return 0 ;;
      N|NO)       return 1 ;;
      *) echo -e "  ${RED}Responde S o N.${NC}" ;;
    esac
  done
}

# Crea symlink dest → src con backup si dest ya existe
make_link() {
  local src="$1"
  local dest="$2"

  if [[ ! -e "$src" ]]; then
    warn "Origen no encontrado en repo: $src"
    return
  fi

  if [[ -e "$dest" && ! -L "$dest" ]]; then
    local bak="${dest}.bak_$(date +%Y%m%d_%H%M%S)"
    warn "Backup previo: $dest → $bak"
    mv "$dest" "$bak"
  fi

  mkdir -p "$(dirname "$dest")"
  ln -sfn "$src" "$dest"
  success "Linked: $dest → $src"
}

# ─── Setup ────────────────────────────────────────────────────────────────────
setup() {
  mkdir -p "$LOG_DIR"
  clear
  echo -e "${BOLD}${CYAN}"
  echo "  ╔════════════════════════════════════════════╗"
  echo "  ║     Instalación de entorno — dotfiles      ║"
  echo "  ╚════════════════════════════════════════════╝"
  echo -e "${NC}"
  echo -e "  ${DIM}Sistema:  $(uname -srm)${NC}"
  echo -e "  ${DIM}Dotfiles: $DOTFILES_DIR${NC}"
  echo -e "  ${DIM}Log:      $LOG_FILE${NC}"
  echo ""
  echo -e "  Este script es ${BOLD}interactivo${NC}: te preguntará qué instalar"
  echo -e "  en cada sección. Puedes omitir o salir en cualquier momento."
  echo ""
  log "Instalación iniciada: $(date)"
  log "Sistema: $(uname -srm)"
}

# ═══════════════════════════════════════════════════════════════════════════════
# SECCIONES DE INSTALACIÓN
# ═══════════════════════════════════════════════════════════════════════════════

# ─── 1. Paquetes apt ──────────────────────────────────────────────────────────
install_apt_packages() {
  section "1/11 · Paquetes del sistema (apt)"

  local packages=(
    git curl wget unzip xclip build-essential ca-certificates gnupg lsb-release
    zsh fontconfig
    neovim luarocks
    cmake ninja-build clang pkg-config
    libevdev-dev libudev-dev libglib2.0-dev libconfig++-dev
    fzf ripgrep fd-find bat tree
    btop htop
    python3 python3-pip python3-venv python3-pynvim
    solaar
  )

  echo -e "  Se instalarán los siguientes paquetes base:"
  echo -e "  ${DIM}${packages[*]}${NC}"
  echo ""
  cmd_preview "sudo apt-get update && sudo apt-get install -y <paquetes>"

  if ! ask_yn "¿Instalar paquetes base del sistema?"; then
    info "Omitiendo paquetes apt."; return
  fi

  sudo apt-get update -qq
  for pkg in "${packages[@]}"; do
    if dpkg -l "$pkg" &>/dev/null 2>&1; then
      success "$pkg ya instalado."
    else
      info "Instalando $pkg..."
      sudo apt-get install -y "$pkg" >> "$LOG_FILE" 2>&1
      success "$pkg instalado."
    fi
  done

  # Symlinks de nombres Debian
  if command_exists fdfind && ! command_exists fd; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
    success "Symlink: fd → fdfind"
  fi
  if command_exists batcat && ! command_exists bat; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
    success "Symlink: bat → batcat"
  fi
}

# ─── 2. Docker ────────────────────────────────────────────────────────────────
install_docker() {
  section "2/11 · Docker CE"

  if command_exists docker; then
    success "Docker ya instalado: $(docker --version)"
    return
  fi

  echo -e "  Instalará Docker CE desde el repositorio oficial."
  echo -e "  ${YELLOW}Eliminará paquetes conflictivos (docker.io, etc.) si existen.${NC}"
  echo ""
  cmd_preview "Agregar repo oficial → sudo apt-get install docker-ce docker-ce-cli ..."

  if ! ask_yn "¿Instalar Docker CE?"; then
    info "Omitiendo Docker."; return
  fi

  for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
    sudo apt-get remove -y "$pkg" >> "$LOG_FILE" 2>&1 || true
  done

  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc >> "$LOG_FILE" 2>&1
  sudo chmod a+r /etc/apt/keyrings/docker.asc

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
    https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  sudo apt-get update -qq >> "$LOG_FILE" 2>&1
  sudo apt-get install -y \
    docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin >> "$LOG_FILE" 2>&1

  sudo usermod -aG docker "$USER"
  success "Docker instalado. Cierra sesión y vuelve a entrar para usarlo sin sudo."
}

# ─── 3. WezTerm ───────────────────────────────────────────────────────────────
install_wezterm() {
  section "3/11 · WezTerm"

  if command_exists wezterm; then
    success "WezTerm ya instalado: $(wezterm --version)"
    return
  fi

  echo -e "  Instalará WezTerm desde el repositorio oficial."
  cmd_preview "curl repo | sudo apt-get install wezterm"

  if ! ask_yn "¿Instalar WezTerm?"; then
    info "Omitiendo WezTerm."; return
  fi

  curl -fsSL https://apt.fury.io/wezfurlong/gpg-fury.key \
    | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg >> "$LOG_FILE" 2>&1
  echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wezfurlong/ * *' \
    | sudo tee /etc/apt/sources.list.d/wezterm.list > /dev/null
  sudo apt-get update -qq >> "$LOG_FILE" 2>&1
  sudo apt-get install -y wezterm >> "$LOG_FILE" 2>&1
  success "WezTerm instalado."
}

# ─── 4. Zsh + OMZ + P10k ──────────────────────────────────────────────────────
install_zsh() {
  section "4/11 · Zsh + Oh My Zsh + Powerlevel10k + plugins"

  echo -e "  Instalará:"
  echo -e "  ${DIM}- Oh My Zsh${NC}"
  echo -e "  ${DIM}- Tema Powerlevel10k${NC}"
  echo -e "  ${DIM}- Plugins: zsh-autosuggestions, zsh-syntax-highlighting, zsh-completions${NC}"
  echo -e "  ${DIM}- Cambiará shell por defecto a zsh${NC}"
  echo ""

  if ! ask_yn "¿Instalar Zsh / Oh My Zsh?"; then
    info "Omitiendo zsh."; return
  fi

  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    info "Instalando Oh My Zsh..."
    cmd_preview 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh) --unattended"'
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh) --unattended" >> "$LOG_FILE" 2>&1
    success "Oh My Zsh instalado."
  else
    success "Oh My Zsh ya instalado."
  fi

  local ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

  if [[ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]]; then
    info "Instalando Powerlevel10k..."
    cmd_preview "git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
      "$ZSH_CUSTOM/themes/powerlevel10k" >> "$LOG_FILE" 2>&1
    success "Powerlevel10k instalado."
  else
    success "Powerlevel10k ya instalado."
  fi

  declare -A plugins=(
    ["zsh-autosuggestions"]="https://github.com/zsh-users/zsh-autosuggestions"
    ["zsh-syntax-highlighting"]="https://github.com/zsh-users/zsh-syntax-highlighting"
    ["zsh-completions"]="https://github.com/zsh-users/zsh-completions"
  )
  for name in "${!plugins[@]}"; do
    local dir="$ZSH_CUSTOM/plugins/$name"
    if [[ ! -d "$dir" ]]; then
      info "Instalando plugin $name..."
      git clone --depth=1 "${plugins[$name]}" "$dir" >> "$LOG_FILE" 2>&1
      success "Plugin instalado: $name"
    else
      success "Plugin ya instalado: $name"
    fi
  done

  if [[ "$SHELL" != "$(command -v zsh)" ]]; then
    info "Cambiando shell por defecto a zsh..."
    cmd_preview "chsh -s $(command -v zsh)"
    chsh -s "$(command -v zsh)"
    info "Reinicia la terminal para que tome efecto."
  fi
}

# ─── 5. Fuentes Meslo ─────────────────────────────────────────────────────────
install_fonts() {
  section "5/11 · Fuentes MesloLGS NF (requeridas por Powerlevel10k)"

  local FONTS_DIR="$HOME/.local/share/fonts"
  local already=true
  declare -A fonts=(
    ["MesloLGS_NF_Regular.ttf"]="MesloLGS%20NF%20Regular.ttf"
    ["MesloLGS_NF_Bold.ttf"]="MesloLGS%20NF%20Bold.ttf"
    ["MesloLGS_NF_Italic.ttf"]="MesloLGS%20NF%20Italic.ttf"
    ["MesloLGS_NF_Bold_Italic.ttf"]="MesloLGS%20NF%20Bold%20Italic.ttf"
  )
  for f in "${!fonts[@]}"; do
    [[ ! -f "$FONTS_DIR/$f" ]] && already=false && break
  done

  if [[ "$already" == true ]]; then
    success "Fuentes MesloLGS NF ya instaladas."
    return
  fi

  echo -e "  Descargará las 4 variantes de MesloLGS NF a ~/.local/share/fonts"
  cmd_preview "wget powerlevel10k-media/MesloLGS*.ttf → fc-cache -fv"

  if ! ask_yn "¿Instalar fuentes MesloLGS NF?"; then
    info "Omitiendo fuentes."; return
  fi

  mkdir -p "$FONTS_DIR"
  local base="https://github.com/romkatv/powerlevel10k-media/raw/master"
  for local_name in "${!fonts[@]}"; do
    if [[ ! -f "$FONTS_DIR/$local_name" ]]; then
      info "Descargando $local_name..."
      wget -q "$base/${fonts[$local_name]}" -O "$FONTS_DIR/$local_name" >> "$LOG_FILE" 2>&1
    fi
  done
  fc-cache -fv >> "$LOG_FILE" 2>&1
  success "Fuentes instaladas. Configura WezTerm con: MesloLGS Nerd Font Mono"
}

# ─── 6. Node.js ───────────────────────────────────────────────────────────────
install_node() {
  section "6/11 · Node.js (nvm)"

  if command_exists node; then
    success "Node.js ya instalado: $(node --version)"
    return
  fi

  echo -e "  Instalará nvm v${NVM_VERSION} y luego Node.js LTS."
  cmd_preview "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh | bash"
  cmd_preview "nvm install --lts && nvm alias default node"

  if ! ask_yn "¿Instalar Node.js via nvm?"; then
    info "Omitiendo Node.js."; return
  fi

  curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh" \
    | bash >> "$LOG_FILE" 2>&1

  export NVM_DIR="$HOME/.nvm"
  # shellcheck source=/dev/null
  [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"

  nvm install --lts >> "$LOG_FILE" 2>&1
  nvm alias default node >> "$LOG_FILE" 2>&1
  success "Node.js instalado: $(node --version 2>/dev/null || echo 'reinicia shell para ver versión')"
}

# ─── 7. Java (SDKMAN) ─────────────────────────────────────────────────────────
install_java() {
  section "7/11 · Java (SDKMAN)"

  # Instalar SDKMAN si no existe
  if [[ ! -d "$HOME/.sdkman" ]]; then
    echo -e "  SDKMAN no está instalado."
    cmd_preview 'curl -s "https://get.sdkman.io" | bash'

    if ! ask_yn "¿Instalar SDKMAN?"; then
      info "Omitiendo SDKMAN y Java."; return
    fi

    curl -s "https://get.sdkman.io" | bash >> "$LOG_FILE" 2>&1
    success "SDKMAN instalado."
  else
    success "SDKMAN ya instalado."
  fi

  # shellcheck source=/dev/null
  [[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

  # Preguntar qué versiones instalar
  echo ""
  echo -e "  ${BOLD}¿Qué versiones de Java instalar?${NC}"
  echo -e "    ${CYAN}[1]${NC} Java 21 (LTS actual) + Java 17 (LTS anterior) — recomendado"
  echo -e "    ${CYAN}[2]${NC} Solo Java 21 (LTS actual)"
  echo -e "    ${CYAN}[3]${NC} Solo Java 17 (LTS anterior)"
  echo -e "    ${CYAN}[4]${NC} Elegir manualmente (verás el listado de sdk list java)"
  echo -e "    ${CYAN}[S]${NC} Omitir instalación de Java"
  echo ""

  local versions_to_install=()
  while true; do
    read -r -p "  → Elige una opción: " java_choice
    java_choice="${java_choice^^}"
    case "$java_choice" in
      1) versions_to_install=("$JAVA_VERSION_21" "$JAVA_VERSION_17"); break ;;
      2) versions_to_install=("$JAVA_VERSION_21"); break ;;
      3) versions_to_install=("$JAVA_VERSION_17"); break ;;
      4)
        info "Ejecutando: sdk list java"
        sdk list java 2>/dev/null | head -60 || true
        echo ""
        read -r -p "  → Ingresa el identificador exacto (ej: 21.0.8-tem): " custom_ver
        versions_to_install=("$custom_ver")
        break
        ;;
      S) info "Omitiendo Java."; return ;;
      *) echo -e "  ${RED}Opción inválida.${NC}" ;;
    esac
  done

  for version in "${versions_to_install[@]}"; do
    info "Instalando Java $version..."
    cmd_preview "sdk install java $version"
    sdk install java "$version" < /dev/null >> "$LOG_FILE" 2>&1
    success "Java $version instalado."
  done

  # El primero de la lista es el default
  sdk default java "${versions_to_install[0]}" >> "$LOG_FILE" 2>&1
  success "Java default: ${versions_to_install[0]}"
}

# ─── 8. Lazygit + Lazydocker ──────────────────────────────────────────────────
install_lazy_tools() {
  section "8/11 · Lazygit + Lazydocker"

  local install_lg=false
  local install_ld=false

  if command_exists lazygit; then
    success "lazygit ya instalado: $(lazygit --version | grep -o 'version=[^ ,]*')"
  else
    echo -e "  ${BOLD}lazygit${NC} — TUI para Git"
    cmd_preview "Descarga binario desde GitHub releases → sudo install /usr/local/bin/lazygit"
    ask_yn "¿Instalar lazygit?" && install_lg=true || true
  fi

  if command_exists lazydocker; then
    success "lazydocker ya instalado: $(lazydocker --version)"
  else
    echo ""
    echo -e "  ${BOLD}lazydocker${NC} — TUI para Docker"
    cmd_preview "curl script oficial de jesseduffield/lazydocker | bash"
    ask_yn "¿Instalar lazydocker?" && install_ld=true || true
  fi

  if [[ "$install_lg" == true ]]; then
    info "Instalando lazygit..."
    local VERSION
    VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" \
      | grep -Po '"tag_name": "v\K[^"]*')
    curl -Lo /tmp/lazygit.tar.gz \
      "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${VERSION}_Linux_x86_64.tar.gz" \
      >> "$LOG_FILE" 2>&1
    tar -xf /tmp/lazygit.tar.gz -C /tmp lazygit >> "$LOG_FILE" 2>&1
    sudo install /tmp/lazygit /usr/local/bin/lazygit
    rm -f /tmp/lazygit /tmp/lazygit.tar.gz
    success "lazygit instalado."
  fi

  if [[ "$install_ld" == true ]]; then
    info "Instalando lazydocker..."
    curl -s https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh \
      | bash >> "$LOG_FILE" 2>&1
    success "lazydocker instalado."
  fi
}

# ─── 9. LogiOps ───────────────────────────────────────────────────────────────
install_logid() {
  section "9/11 · LogiOps — MX Master 3S"

  echo -e "  LogiOps se instala compilando desde código fuente."
  echo -e "  También configurará un ${BOLD}timer de 10s al boot${NC} para que el"
  echo -e "  mouse sea detectado correctamente al iniciar el sistema."
  echo ""

  if command_exists logid; then
    success "logid ya instalado en $(command -v logid)"
    echo ""
    if ! ask_yn "¿Reinstalar logid de todas formas?"; then
      # Saltar compilación pero aún restaurar config
      _restore_logid_config
      return
    fi
  else
    cmd_preview "git clone https://github.com/PixlOne/logiops"
    cmd_preview "cd logiops/build && cmake .. && make && sudo make install"
    if ! ask_yn "¿Compilar e instalar logid? (tarda ~3 minutos)"; then
      info "Omitiendo logid."; return
    fi
  fi

  info "Clonando logiops..."
  git clone https://github.com/PixlOne/logiops /tmp/logiops >> "$LOG_FILE" 2>&1
  mkdir -p /tmp/logiops/build
  cd /tmp/logiops/build
  info "Compilando (cmake + make)..."
  cmake .. >> "$LOG_FILE" 2>&1
  make >> "$LOG_FILE" 2>&1
  sudo make install >> "$LOG_FILE" 2>&1
  cd "$DOTFILES_DIR"
  rm -rf /tmp/logiops
  success "logid compilado e instalado en /usr/local/bin/logid"

  _restore_logid_config
}

_restore_logid_config() {
  # Restaurar logid.cfg
  local cfg_src="$DOTFILES_DIR/mouse/logid.cfg"
  if [[ -f "$cfg_src" ]]; then
    info "Restaurando /etc/logid.cfg..."
    sudo cp "$cfg_src" /etc/logid.cfg
    success "/etc/logid.cfg restaurado (botones de volumen MX Master 3S)"
  else
    warn "No encontrado: mouse/logid.cfg — ejecuta backup.sh primero."
  fi

  # Crear o restaurar timer de boot
  local timer_dest="/usr/lib/systemd/system/logid.timer"
  local timer_src="$DOTFILES_DIR/mouse/logid.timer"

  if [[ -f "$timer_src" ]]; then
    info "Restaurando logid.timer desde repo..."
    sudo cp "$timer_src" "$timer_dest"
  else
    info "Creando logid.timer (OnBootSec=10s)..."
    sudo tee "$timer_dest" > /dev/null << 'EOF'
[Unit]
Description=Run logid on boot with delay

[Timer]
OnBootSec=10

[Install]
WantedBy=timers.target
EOF
  fi

  sudo systemctl disable logid.service >> "$LOG_FILE" 2>&1 || true
  sudo systemctl enable logid.timer >> "$LOG_FILE" 2>&1
  sudo systemctl start logid.service >> "$LOG_FILE" 2>&1
  success "logid activo ahora y configurado con timer al boot."

  # Restaurar config de Solaar
  local solaar_src="$DOTFILES_DIR/mouse/solaar-config.yaml"
  if [[ -f "$solaar_src" ]]; then
    mkdir -p "$HOME/.config/solaar"
    cp "$solaar_src" "$HOME/.config/solaar/config.yaml"
    success "Solaar config restaurada."
  fi
}

# ─── 10. Flutter ──────────────────────────────────────────────────────────────
install_flutter() {
  section "10/12 · Flutter / Android SDK"

  if command_exists flutter; then
    success "Flutter ya instalado: $(flutter --version 2>/dev/null | head -n1)"
    return
  fi

  echo -e "  Flutter ${BOLD}no puede instalarse automáticamente${NC} — el SDK"
  echo -e "  pesa ~1GB y requiere elegir la ubicación manualmente."
  echo ""
  echo -e "  ${BOLD}Pasos manuales:${NC}"
  echo -e "  ${DIM}1. https://docs.flutter.dev/get-started/install/linux${NC}"
  echo -e "  ${DIM}2. Extrae en ~/development/flutter (o donde prefieras)${NC}"
  echo -e "  ${DIM}3. Android SDK: https://developer.android.com/studio#command-tools${NC}"
  echo -e "  ${DIM}4. Instálalo en ~/android-sdk${NC}"
  echo -e "  ${DIM}5. Las variables ANDROID_HOME y pub-cache ya están en tu .zshrc${NC}"
  echo ""

  if [[ -d "$HOME/android-sdk" ]]; then
    success "Android SDK encontrado en ~/android-sdk"
  else
    warn "~/android-sdk no existe — instalar manualmente."
  fi
}

# ─── 12. MPD + rmpc ──────────────────────────────────────────────────────────
install_mpd_rmpc() {
  section "12/12 · MPD + rmpc"

  echo -e "  MPD (Music Player Daemon) se instalará vía apt en modo usuario."
  echo -e "  rmpc (cliente TUI moderno) se descargará desde GitHub releases."
  echo ""

  # ── MPD ──
  if command_exists mpd; then
    success "mpd ya instalado: $(mpd --version | head -n1)"
  else
    cmd_preview "sudo apt-get install -y mpd mpc"
    if ask_yn "¿Instalar MPD?"; then
      sudo apt-get install -y mpd mpc >> "$LOG_FILE" 2>&1

      # Deshabilitar el servicio global (usaremos sesión de usuario)
      sudo systemctl disable mpd.service >> "$LOG_FILE" 2>&1 || true
      sudo systemctl stop    mpd.service >> "$LOG_FILE" 2>&1 || true
      success "MPD instalado. Servicio global deshabilitado (se usará en modo usuario)."
    else
      info "Omitiendo MPD."
    fi
  fi

  # ── Directorios de datos de MPD (no van en dotfiles, son runtime) ──
  mkdir -p "$HOME/.local/share/mpd/playlists"

  # ── Config MPD — el symlink lo crea setup_symlinks, aquí solo generamos si no existe ──
  local mpd_repo="$DOTFILES_DIR/mpd"
  local mpd_cfg="$mpd_repo/mpd.conf"

  if [[ -f "$mpd_cfg" ]]; then
    success "mpd.conf encontrado en repo — el symlink lo enlazará."
  elif command_exists mpd; then
    if ask_yn "¿Generar mpd.conf mínimo en dotfiles/mpd/?"; then
      mkdir -p "$mpd_repo"
      cat > "$mpd_cfg" << 'EOF'
# dotfiles/mpd/mpd.conf
# Enlazado desde ~/.config/mpd/mpd.conf
#
# IMPORTANTE: music_directory apunta al mount SMB.
# Ver dotfiles/smb/README.md para montar el servidor.
music_directory     "~/Music/servidor/Musica_Itunes/Music"
playlist_directory  "~/.local/share/mpd/playlists"
db_file             "~/.local/share/mpd/database"
log_file            "~/.local/share/mpd/log"
pid_file            "~/.local/share/mpd/pid"
state_file          "~/.local/share/mpd/state"
sticker_file        "~/.local/share/mpd/sticker.sql"

bind_to_address     "127.0.0.1"
port                "6600"

audio_output {
  type  "pipewire"
  name  "PipeWire Output"
}

# Fallback PulseAudio:
# audio_output {
#   type  "pulse"
#   name  "PulseAudio Output"
# }
EOF
      success "mpd.conf creado en $mpd_cfg"
    fi
  fi

  # ── Servicio MPD en modo usuario ──
  if command_exists mpd && [[ -f "$mpd_cfg" ]]; then
    if ask_yn "¿Habilitar mpd como servicio de usuario (systemd --user)?"; then
      systemctl --user enable mpd >> "$LOG_FILE" 2>&1 || true
      systemctl --user start  mpd >> "$LOG_FILE" 2>&1 || true
      success "mpd.service (usuario) habilitado e iniciado."
    fi
  fi

  echo ""

  # ── rmpc ──
  if command_exists rmpc; then
    success "rmpc ya instalado: $(rmpc --version 2>/dev/null || echo 'instalado')"
  else
    echo -e "  ${BOLD}rmpc${NC} — cliente TUI moderno para MPD (Rust)"
    echo -e "  ${DIM}Si GitHub no es accesible, instalar con: sudo snap install rmpc${NC}"
    cmd_preview "Descarga binario desde github.com/mierak/rmpc/releases"
    if ! ask_yn "¿Instalar rmpc?"; then
      info "Omitiendo rmpc."; return
    fi

    local RMPC_VERSION
    RMPC_VERSION=$(curl -s "https://api.github.com/repos/mierak/rmpc/releases/latest" \
      | grep -Po '"tag_name": "v\K[^"]*')

    if [[ -z "$RMPC_VERSION" ]]; then
      warn "No se pudo obtener versión desde GitHub. Intentando con snap..."
      sudo snap install rmpc >> "$LOG_FILE" 2>&1 && success "rmpc instalado vía snap." || \
        warn "Instalación fallida. Manual: https://github.com/mierak/rmpc/releases"
      return
    fi

    info "Descargando rmpc v${RMPC_VERSION}..."
    curl -Lo /tmp/rmpc.tar.gz \
      "https://github.com/mierak/rmpc/releases/download/v${RMPC_VERSION}/rmpc-x86_64-unknown-linux-gnu.tar.gz" \
      >> "$LOG_FILE" 2>&1
    tar -xf /tmp/rmpc.tar.gz -C /tmp >> "$LOG_FILE" 2>&1
    sudo install /tmp/rmpc /usr/local/bin/rmpc
    rm -f /tmp/rmpc /tmp/rmpc.tar.gz
    success "rmpc v${RMPC_VERSION} instalado."
  fi

  # ── Config rmpc — el symlink lo crea setup_symlinks ──
  local rmpc_repo="$DOTFILES_DIR/rmpc"
  if [[ -d "$rmpc_repo" ]]; then
    success "Config rmpc encontrada en repo — el symlink la enlazará."
  elif command_exists rmpc; then
    if ask_yn "¿Generar config rmpc por defecto en dotfiles/rmpc/?"; then
      mkdir -p "$rmpc_repo/themes"
      rmpc config show > "$rmpc_repo/config.ron" 2>/dev/null || true
      success "Config rmpc generada en $rmpc_repo/config.ron"
    fi
  fi

  echo ""

  # ── Montaje SMB ──
  section "  → Montaje SMB (música desde servidor)"
  echo -e "  ${DIM}Ver instrucciones completas en: dotfiles/smb/README.md${NC}"
  echo ""

  local smb_creds="$HOME/.smbcredentials"
  local smb_mount="$HOME/Music/servidor"
  local smb_example="$DOTFILES_DIR/smb/.smbcredentials.example"

  # Verificar credenciales
  if [[ ! -f "$smb_creds" ]]; then
    if [[ -f "$smb_example" ]]; then
      warn "~/.smbcredentials no encontrado."
      echo -e "  Copia la plantilla y rellena tus datos:"
      echo -e "  ${DIM}cp $smb_example ~/.smbcredentials${NC}"
      echo -e "  ${DIM}nano ~/.smbcredentials${NC}"
      echo -e "  ${DIM}chmod 600 ~/.smbcredentials${NC}"
    fi
    info "Omitiendo montaje SMB (sin credenciales)."
  else
    mkdir -p "$smb_mount"
    if ask_yn "¿Montar servidor SMB ahora? (//192.168.0.25/Datos_main)"; then
      sudo mount -t cifs //192.168.0.25/Datos_main "$smb_mount" \
        -o "credentials=$smb_creds,uid=$(id -u),gid=$(id -g)" >> "$LOG_FILE" 2>&1 \
        && success "Servidor montado en $smb_mount" \
        || warn "Montaje fallido — verifica red o credenciales."
    fi

    if ask_yn "¿Hacer el montaje permanente en /etc/fstab?"; then
      local fstab_entry="//192.168.0.25/Datos_main $smb_mount cifs credentials=$smb_creds,uid=$(id -u),gid=$(id -g),iocharset=utf8,_netdev 0 0"
      if grep -qF "192.168.0.25/Datos_main" /etc/fstab; then
        warn "Ya existe entrada en /etc/fstab — omitiendo."
      else
        echo "$fstab_entry" | sudo tee -a /etc/fstab > /dev/null
        success "Entrada agregada a /etc/fstab. Montará automáticamente al boot."
      fi
    fi
  fi
}

# ─── Symlinks ─────────────────────────────────────────────────────────────────
setup_symlinks() {
  section "11/12 · Symlinks al repo dotfiles"

  echo -e "  Creará los siguientes enlaces simbólicos:"
  echo -e "  ${DIM}~/.zshrc              → dotfiles/.zshrc${NC}"
  echo -e "  ${DIM}~/.p10k.zsh           → dotfiles/.p10k.zsh${NC}"
  echo -e "  ${DIM}~/.config/nvim        → dotfiles/.config/nvim${NC}"
  echo -e "  ${DIM}~/.config/wezterm     → dotfiles/.config/wezterm${NC}"
  echo -e "  ${DIM}~/.gitconfig          → dotfiles/git/.gitconfig${NC}"
  echo -e "  ${DIM}~/.config/lazygit     → dotfiles/lazygit${NC}"
  echo -e "  ${DIM}~/.config/lazydocker  → dotfiles/lazydocker${NC}"
  echo -e "  ${DIM}~/.config/btop        → dotfiles/btop${NC}"
  echo -e "  ${DIM}~/.config/htop        → dotfiles/htop${NC}"
  echo -e "  ${DIM}~/.config/mpd         → dotfiles/mpd${NC}"
  echo -e "  ${DIM}~/.config/rmpc        → dotfiles/rmpc${NC}"
  echo ""
  echo -e "  ${YELLOW}Si ya existe un archivo (no symlink), se hará backup automático.${NC}"
  echo ""

  if ! ask_yn "¿Crear symlinks?"; then
    info "Omitiendo symlinks."; return
  fi

  make_link "$DOTFILES_DIR/.zshrc"    "$HOME/.zshrc"
  make_link "$DOTFILES_DIR/.p10k.zsh" "$HOME/.p10k.zsh"
  make_link "$DOTFILES_DIR/.config/nvim"    "$HOME/.config/nvim"
  make_link "$DOTFILES_DIR/.config/wezterm" "$HOME/.config/wezterm"
  make_link "$DOTFILES_DIR/git/.gitconfig"        "$HOME/.gitconfig"
  make_link "$DOTFILES_DIR/git/.gitignore_global" "$HOME/.config/git/.gitignore_global"
  make_link "$DOTFILES_DIR/lazygit"    "$HOME/.config/lazygit"
  make_link "$DOTFILES_DIR/lazydocker" "$HOME/.config/lazydocker"
  make_link "$DOTFILES_DIR/btop"       "$HOME/.config/btop"
  make_link "$DOTFILES_DIR/htop"       "$HOME/.config/htop"
  make_link "$DOTFILES_DIR/mpd"        "$HOME/.config/mpd"
  make_link "$DOTFILES_DIR/rmpc"       "$HOME/.config/rmpc"
}

# ─── Resumen final ────────────────────────────────────────────────────────────
print_summary() {
  echo ""
  echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}${CYAN}  Instalación completa${NC}"
  echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  ${BOLD}Estado de herramientas:${NC}"

  local tools=(nvim zsh wezterm node lazygit lazydocker fzf rg bat fd docker btop htop mpd rmpc)
  for tool in "${tools[@]}"; do
    if command_exists "$tool"; then
      echo -e "  ${GREEN}✓${NC} $tool"
    else
      echo -e "  ${YELLOW}?${NC} $tool (puede requerir reiniciar shell)"
    fi
  done

  echo ""
  echo -e "  ${BOLD}Próximos pasos:${NC}"
  echo -e "  ${DIM}1. Reinicia la terminal:  source ~/.zshrc${NC}"
  echo -e "  ${DIM}2. Abre Neovim:           nvim  (Lazy.nvim instala plugins solo)${NC}"
  echo -e "  ${DIM}3. Verifica Neovim:       :checkhealth${NC}"
  echo -e "  ${DIM}4. Docker sin sudo:       cierra sesión y vuelve a entrar${NC}"
  echo -e "  ${DIM}5. Flutter:               instalación manual (ver instrucciones arriba)${NC}"
  echo -e "  ${DIM}6. MPD:                   mpd  (o: systemctl --user start mpd)${NC}"
  echo -e "  ${DIM}   Cliente:               rmpc${NC}"
  echo ""
  echo -e "  Log completo: ${DIM}$LOG_FILE${NC}"
  echo ""
  log "Instalación completada: $(date)"
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════
main() {
  setup

  install_apt_packages
  install_docker
  install_wezterm
  install_zsh
  install_fonts
  install_node
  install_java
  install_lazy_tools
  install_logid
  install_flutter
  install_mpd_rmpc
  setup_symlinks

  print_summary
}

main "$@"
