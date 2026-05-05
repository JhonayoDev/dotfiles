#!/usr/bin/env bash
# ~/dotfiles/install.sh
#
# Aplica dotfiles mediante GNU Stow según el perfil elegido.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE="${1:-desktop}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }
info() { echo -e "${CYAN}[INFO]${NC}  $*"; }
section() { echo -e "\n${BOLD}── $* ──${NC}"; }

# ─── Backup de archivos reales que conflictúan con stow ───────
# Busca archivos reales (no symlinks) que stow va a intentar crear
# y los mueve a .bak antes de aplicar.
backup_conflicts() {
  local module="$1"
  local module_path="$DOTFILES_DIR/$module"

  # Recorrer los archivos del módulo y verificar conflictos en $HOME
  while IFS= read -r -d '' src_file; do
    # Ruta relativa al módulo (ej: .config/nvim/init.lua)
    local rel="${src_file#$module_path/}"
    local dest="$HOME/$rel"

    # Si existe como archivo real (no symlink), hacer backup
    if [[ -e "$dest" && ! -L "$dest" ]]; then
      local bak="${dest}.bak_$(date +%Y%m%d_%H%M%S)"
      warn "Backup: $dest → $bak"
      mv "$dest" "$bak"
    fi
  done < <(find "$module_path" -type f -print0)
}

stow_module() {
  local module="$1"
  local module_path="$DOTFILES_DIR/$module"

  if [[ ! -d "$module_path" ]]; then
    warn "Módulo no encontrado: $module (omitiendo)"
    return
  fi

  backup_conflicts "$module"

  stow --dir="$DOTFILES_DIR" --target="$HOME" --restow "$module"
  success "Stow: $module → $HOME"
}

# ─── Perfiles ─────────────────────────────────────────────────
profile_devbox() {
  info "Perfil: devbox (nvim + zsh + git + lazygit)"
  section "nvim"
  stow_module nvim
  section "zsh"
  stow_module zsh
  #section "git"
  #stow_module git>wezterm
  #section "lazygit"
  #stow_module lazygit
  # ─── Oh My Zsh + plugins + powerlevel10k ───────────────────
  section "Oh My Zsh + plugins + powerlevel10k"
  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    success "Oh My Zsh instalado"
  else
    success "Oh My Zsh ya presente"
  fi

  ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  for plugin_repo in \
    "zsh-users/zsh-autosuggestions" \
    "zsh-users/zsh-syntax-highlighting" \
    "zsh-users/zsh-completions"; do
    plugin_name=$(basename "$plugin_repo")
    plugin_dir="$ZSH_CUSTOM/plugins/$plugin_name"
    if [[ ! -d "$plugin_dir" ]]; then
      git clone --depth=1 "https://github.com/$plugin_repo" "$plugin_dir"
      success "Plugin: $plugin_name"
    fi
  done

  if [[ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
      "$ZSH_CUSTOM/themes/powerlevel10k"
    success "Tema: powerlevel10k"
  fi
  section "zsh como shell por defecto"
  if [[ "$(getent passwd vscode | cut -d: -f7)" != "$(which zsh)" ]]; then
    sudo chsh -s "$(which zsh)" vscode
    success "Shell cambiado a zsh"
  else
    success "zsh ya es el shell por defecto"
  fi
}

profile_desktop() {
  info "Perfil: desktop (todo)"
  profile_devbox
  section "wezterm"
  stow_module wezterm
  section "dunst"
  stow_module dunst
  section "rofi"
  stow_module rofi
  section "gtk"
  stow_module gtk
  section "xsettingsd"
  stow_module xsettingsd
  section "qtile"
  stow_module qtile
}

# ─── Main ─────────────────────────────────────────────────────
main() {
  echo -e "${BOLD}${CYAN}"
  echo "  ┌────────────────────────────────────────┐"
  echo "  │        dotfiles install.sh             │"
  echo "  │  perfil: ${PROFILE}$(printf '%*s' $((31 - ${#PROFILE})) '')│"
  echo "  └────────────────────────────────────────┘"
  echo -e "${NC}"

  info "Dotfiles dir: $DOTFILES_DIR"
  info "Destino:      $HOME"

  case "$PROFILE" in
  devbox) profile_devbox ;;
  desktop) profile_desktop ;;
  *)
    error "Perfil desconocido: '$PROFILE'"
    echo "  Uso: bash install.sh [devbox|desktop]"
    exit 1
    ;;
  esac

  echo ""
  success "Instalación completada (perfil: $PROFILE)"
}

main
