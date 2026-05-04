#!/usr/bin/env bash
# ~/dotfiles/install.sh
#
# Aplica dotfiles mediante GNU Stow según el perfil elegido.
#
# Uso:
#   bash install.sh            → perfil "desktop" (todo)
#   bash install.sh devbox     → perfil "devbox"  (nvim + zsh + git + lazygit)
#   bash install.sh desktop    → perfil "desktop" (todo)
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

# ─── Función central: stow de un módulo ───────────────────────
# Uso: stow_module <nombre_del_modulo>
# El módulo debe existir como carpeta en $DOTFILES_DIR
stow_module() {
  local module="$1"
  local module_path="$DOTFILES_DIR/$module"

  if [[ ! -d "$module_path" ]]; then
    warn "Módulo no encontrado: $module (omitiendo)"
    return
  fi

  # --restow: re-crea symlinks si ya existen (idempotente)
  # --target: destino explícito ($HOME)
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
  section "git"
  stow_module git
  section "lazygit"
  stow_module lazygit
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
