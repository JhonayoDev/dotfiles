#!/usr/bin/env bash
# ~/dotfiles/install.sh
#
# Instala dotfiles mediante symlinks según el perfil elegido.
# No usa GNU Stow — trabaja directamente con la estructura actual del repo.
#
# Uso:
#   bash install.sh            → perfil "desktop" (todo)
#   bash install.sh devbox     → perfil "devbox"  (nvim + zsh)
#   bash install.sh desktop    → perfil "desktop" (todo)
#
# Perfiles disponibles:
#   devbox   → nvim, zsh (.zshrc + .p10k.zsh)
#   desktop  → devbox + wezterm, btop, lazygit, lazydocker, git, rofi

set -euo pipefail

# ─── Configuración ────────────────────────────────────────────
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE="${1:-desktop}"

# ─── Colores ──────────────────────────────────────────────────
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

# ─── Función central: crear symlink con backup ─────────────────
# Uso: link <origen_relativo_al_repo> <destino_absoluto>
link() {
  local src="$DOTFILES_DIR/$1"
  local dest="$2"

  # Verificar que el origen existe
  if [[ ! -e "$src" ]]; then
    warn "Origen no encontrado: $src (omitiendo)"
    return
  fi

  # Si ya es el symlink correcto, no hacer nada
  if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
    success "Ya enlazado: $dest"
    return
  fi

  # Si existe algo (archivo real o symlink diferente), hacer backup
  if [[ -e "$dest" || -L "$dest" ]]; then
    local bak="${dest}.bak_$(date +%Y%m%d_%H%M%S)"
    warn "Backup: $dest → $bak"
    mv "$dest" "$bak"
  fi

  # Crear directorio padre si no existe
  mkdir -p "$(dirname "$dest")"

  ln -sfn "$src" "$dest"
  success "Linked: $dest → $src"
}

# ─── Instaladores por paquete ─────────────────────────────────

install_nvim() {
  section "Neovim"
  link ".config/nvim" "$HOME/.config/nvim"
}

install_zsh() {
  section "Zsh"
  link ".zshrc" "$HOME/.zshrc"
  link ".p10k.zsh" "$HOME/.p10k.zsh"
}

install_wezterm() {
  section "WezTerm"
  link ".config/wezterm" "$HOME/.config/wezterm"
}

install_btop() {
  section "btop"
  link "btop" "$HOME/.config/btop"
}

install_lazygit() {
  section "Lazygit"
  link "lazygit" "$HOME/.config/lazygit"
}

install_lazydocker() {
  section "Lazydocker"
  link "lazydocker" "$HOME/.config/lazydocker"
}

install_git() {
  section "Git"
  link "git/.gitconfig" "$HOME/.gitconfig"
  link "git/.gitignore_global" "$HOME/.config/git/.gitignore_global"
}

install_rofi() {
  section "Rofi"
  link "rofi" "$HOME/.config/rofi"
}

# ─── Perfiles ─────────────────────────────────────────────────

profile_devbox() {
  info "Perfil: devbox (nvim + zsh + git + lazygit)"
  install_nvim
  install_zsh
  install_git
  install_lazygit
}

profile_desktop() {
  info "Perfil: desktop (todo)"
  # Incluye todo lo del devbox
  install_nvim
  install_zsh
  # Más el escritorio completo
  install_wezterm
  install_btop
  install_lazygit
  install_lazydocker
  install_git
  install_rofi
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
