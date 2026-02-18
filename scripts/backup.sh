#!/bin/bash
# ~/dotfiles/scripts/backup.sh
#
# Detecta automáticamente qué herramientas están instaladas,
# muestra el listado y pregunta qué respaldar antes de ejecutar.
#
# Uso: bash ~/dotfiles/scripts/backup.sh [--push]

set -euo pipefail

# ─── Configuración ────────────────────────────────────────────────────────────
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
LOG_DIR="$DOTFILES_DIR/logs"
LOG_FILE="$LOG_DIR/backup_$(date +%Y%m%d_%H%M%S).log"
AUTO_PUSH=false

# ─── Colores ──────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ─── Utilidades ───────────────────────────────────────────────────────────────
log()     { echo -e "$*" | tee -a "$LOG_FILE"; }
info()    { log "${BLUE}[INFO]${NC}  $*"; }
success() { log "${GREEN}[OK]${NC}    $*"; }
warn()    { log "${YELLOW}[WARN]${NC}  $*"; }
section() { log "\n${BOLD}${CYAN}══ $* ══${NC}"; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

ask_yn() {
  local question="$1"
  local default="${2:-S}"
  while true; do
    echo -ne "  ${BOLD}${question}${NC} [S/N] (Enter = $default): "
    read -r yn
    yn="${yn:-$default}"
    yn="${yn^^}"
    case "$yn" in
      S|SI|Y|YES) return 0 ;;
      N|NO)       return 1 ;;
      *) echo -e "  ${RED}Responde S o N.${NC}" ;;
    esac
  done
}

# Copia archivo o directorio al repo.
# Detecta automáticamente si ya es symlink al repo.
backup_item() {
  local src="$1"
  local dest="$2"
  local label="${3:-$src}"

  if [[ ! -e "$src" ]]; then
    warn "No encontrado: $src"
    return 1
  fi

  if [[ -L "$src" ]]; then
    local target
    target=$(readlink -f "$src")
    if [[ "$target" == "$DOTFILES_DIR"* ]]; then
      success "Symlink activo (ya en repo): $label"
      return 0
    fi
  fi

  mkdir -p "$(dirname "$dest")"
  if [[ -d "$src" ]]; then
    rsync -a --delete "$src/" "$dest/" >> "$LOG_FILE" 2>&1
  else
    cp -f "$src" "$dest"
  fi
  success "Respaldado: $label"
  return 0
}

# ─── Detección del entorno ────────────────────────────────────────────────────

# Detecta versiones de SDKs gestionados
detect_java_versions() {
  if [[ -d "$HOME/.sdkman/candidates/java" ]]; then
    ls "$HOME/.sdkman/candidates/java/" 2>/dev/null | grep -v "^current$" || true
  fi
}

detect_node_versions() {
  if [[ -d "$HOME/.nvm/versions/node" ]]; then
    ls "$HOME/.nvm/versions/node/" 2>/dev/null || true
  fi
}

# ─── Parseo de argumentos ─────────────────────────────────────────────────────
parse_args() {
  for arg in "$@"; do
    case "$arg" in
      --push) AUTO_PUSH=true ;;
      --help)
        echo "Uso: $0 [--push]"
        echo "  --push   Hace commit y push automáticamente al finalizar"
        exit 0
        ;;
    esac
  done
}

# ─── Pantalla de detección ────────────────────────────────────────────────────
show_detection() {
  clear
  echo -e "${BOLD}${CYAN}"
  echo "  ╔════════════════════════════════════════════╗"
  echo "  ║        Backup de dotfiles — detección      ║"
  echo "  ╚════════════════════════════════════════════╝"
  echo -e "${NC}"
  echo -e "  ${DIM}Destino: $DOTFILES_DIR${NC}"
  echo ""
  echo -e "  ${BOLD}Herramientas y versiones detectadas:${NC}"
  echo ""

  # Herramientas simples
  local tools=(nvim zsh wezterm node npm lazygit lazydocker fzf rg bat fd btop htop docker python3)
  for tool in "${tools[@]}"; do
    if command_exists "$tool"; then
      local ver
      ver=$("$tool" --version 2>/dev/null | head -n1 || echo "instalado")
      echo -e "  ${GREEN}✓${NC} ${BOLD}$tool${NC}  ${DIM}$ver${NC}"
    else
      echo -e "  ${DIM}✗ $tool — no instalado${NC}"
    fi
  done

  # Flutter — versión se obtiene distinto (lento + formato multilínea)
  if command_exists flutter; then
    local flutter_ver
    flutter_ver=$(flutter --version 2>/dev/null | grep -oP 'Flutter \K[0-9]+\.[0-9]+\.[0-9]+' || echo "instalado")
    echo -e "  ${GREEN}✓${NC} ${BOLD}flutter${NC}  ${DIM}$flutter_ver${NC}"
  else
    echo -e "  ${DIM}✗ flutter — no instalado${NC}"
  fi

  # Java vía SDKMAN
  local java_versions
  java_versions=$(detect_java_versions)
  if [[ -n "$java_versions" ]]; then
    echo -e "  ${GREEN}✓${NC} ${BOLD}Java (SDKMAN)${NC}"
    while IFS= read -r v; do
      [[ -n "$v" ]] && echo -e "      ${DIM}↳ $v${NC}"
    done <<< "$java_versions"
  fi

  # Node vía nvm
  local node_versions
  node_versions=$(detect_node_versions)
  if [[ -n "$node_versions" ]]; then
    echo -e "  ${GREEN}✓${NC} ${BOLD}Node (nvm)${NC}"
    while IFS= read -r v; do
      [[ -n "$v" ]] && echo -e "      ${DIM}↳ $v${NC}"
    done <<< "$node_versions"
  fi

  echo ""
  echo -e "  ${BOLD}Archivos de configuración encontrados:${NC}"
  echo ""

  # Mapa: etiqueta → ruta de origen
  declare -gA CONFIG_MAP=(
    ["zsh (.zshrc + .p10k.zsh)"]="$HOME/.zshrc"
    ["git (.gitconfig + .gitignore_global)"]="$HOME/.gitconfig"
    ["nvim"]="$HOME/.config/nvim"
    ["wezterm"]="$HOME/.config/wezterm"
    ["lazygit"]="$HOME/.config/lazygit"
    ["lazydocker"]="$HOME/.config/lazydocker"
    ["btop"]="$HOME/.config/btop"
    ["htop"]="$HOME/.config/htop"
    ["logid (/etc/logid.cfg)"]="/etc/logid.cfg"
    ["solaar"]="$HOME/.config/solaar/config.yaml"
    ["mpd"]="$HOME/.config/mpd"
    ["rmpc"]="$HOME/.config/rmpc"
    ["smb (plantilla)"]="$HOME/dotfiles/smb/.smbcredentials.example"
  )

  declare -gA CONFIG_FOUND=()
  for label in "${!CONFIG_MAP[@]}"; do
    local path="${CONFIG_MAP[$label]}"
    if [[ -e "$path" ]]; then
      echo -e "  ${GREEN}✓${NC} $label"
      CONFIG_FOUND["$label"]=true
    else
      echo -e "  ${DIM}✗ $label — no encontrado${NC}"
      CONFIG_FOUND["$label"]=false
    fi
  done

  echo ""
}

# ─── Selección interactiva ────────────────────────────────────────────────────
select_items_to_backup() {
  echo -e "  ${BOLD}¿Qué deseas respaldar?${NC}"
  echo ""
  echo -e "    ${CYAN}[1]${NC} Todo lo encontrado (recomendado)"
  echo -e "    ${CYAN}[2]${NC} Elegir manualmente sección por sección"
  echo -e "    ${CYAN}[Q]${NC} Cancelar"
  echo ""

  while true; do
    read -r -p "  → Elige una opción: " choice
    choice="${choice^^}"
    case "$choice" in
      1)
        # Marcar todo lo encontrado como seleccionado
        declare -gA SELECTED=()
        for label in "${!CONFIG_FOUND[@]}"; do
          [[ "${CONFIG_FOUND[$label]}" == true ]] && SELECTED["$label"]=true
        done
        break
        ;;
      2)
        declare -gA SELECTED=()
        echo ""
        for label in "${!CONFIG_MAP[@]}"; do
          if [[ "${CONFIG_FOUND[$label]}" == true ]]; then
            if ask_yn "¿Respaldar $label?"; then
              SELECTED["$label"]=true
            fi
          fi
        done
        break
        ;;
      Q) echo "Cancelado."; exit 0 ;;
      *) echo -e "  ${RED}Opción inválida.${NC}" ;;
    esac
  done
}

# ─── Confirmación final ───────────────────────────────────────────────────────
show_confirmation() {
  echo ""
  echo -e "  ${BOLD}Se respaldarán las siguientes secciones:${NC}"
  echo ""
  for label in "${!SELECTED[@]}"; do
    [[ "${SELECTED[$label]}" == true ]] && echo -e "  ${GREEN}→${NC} $label"
  done
  echo ""

  if ! ask_yn "¿Confirmar y ejecutar backup?"; then
    echo "Cancelado."; exit 0
  fi
}

# ─── Ejecución del backup ─────────────────────────────────────────────────────
run_backup() {
  mkdir -p "$LOG_DIR"
  log "════════════════════════════════════════════════"
  log "  Backup iniciado: $(date)"
  log "  Destino: $DOTFILES_DIR"
  log "════════════════════════════════════════════════"

  for label in "${!SELECTED[@]}"; do
    [[ "${SELECTED[$label]}" != true ]] && continue

    section "$label"

    case "$label" in
      "zsh (.zshrc + .p10k.zsh)")
        backup_item "$HOME/.zshrc"    "$DOTFILES_DIR/.zshrc"    ".zshrc"
        backup_item "$HOME/.p10k.zsh" "$DOTFILES_DIR/.p10k.zsh" ".p10k.zsh"
        ;;
      "git (.gitconfig + .gitignore_global)")
        backup_item "$HOME/.gitconfig" "$DOTFILES_DIR/git/.gitconfig" ".gitconfig"
        backup_item "$HOME/.config/git/.gitignore_global" \
          "$DOTFILES_DIR/git/.gitignore_global" ".gitignore_global"
        ;;
      "nvim")
        backup_item "$HOME/.config/nvim" "$DOTFILES_DIR/.config/nvim" "nvim/"
        ;;
      "wezterm")
        backup_item "$HOME/.config/wezterm" "$DOTFILES_DIR/.config/wezterm" "wezterm/"
        ;;
      "lazygit")
        backup_item "$HOME/.config/lazygit" "$DOTFILES_DIR/lazygit" "lazygit/"
        ;;
      "lazydocker")
        backup_item "$HOME/.config/lazydocker" "$DOTFILES_DIR/lazydocker" "lazydocker/"
        ;;
      "btop")
        backup_item "$HOME/.config/btop" "$DOTFILES_DIR/btop" "btop/"
        ;;
      "htop")
        backup_item "$HOME/.config/htop" "$DOTFILES_DIR/htop" "htop/"
        ;;
      "logid (/etc/logid.cfg)")
        mkdir -p "$DOTFILES_DIR/mouse"
        sudo cp /etc/logid.cfg "$DOTFILES_DIR/mouse/logid.cfg"
        success "Respaldado: /etc/logid.cfg"
        # Timer si existe
        if [[ -f "/usr/lib/systemd/system/logid.timer" ]]; then
          sudo cp /usr/lib/systemd/system/logid.timer "$DOTFILES_DIR/mouse/logid.timer"
          success "Respaldado: logid.timer"
        fi
        ;;
      "solaar")
        backup_item "$HOME/.config/solaar/config.yaml" \
          "$DOTFILES_DIR/mouse/solaar-config.yaml" "solaar config"
        ;;
      "mpd")
        backup_item "$HOME/.config/mpd" "$DOTFILES_DIR/mpd" "mpd/"
        ;;
      "rmpc")
        backup_item "$HOME/.config/rmpc" "$DOTFILES_DIR/rmpc" "rmpc/"
        ;;
      "smb (plantilla)")
        # Solo verifica que la plantilla exista — el archivo real con contraseña NUNCA se respalda
        if [[ -f "$DOTFILES_DIR/smb/.smbcredentials.example" ]]; then
          success "Plantilla SMB ya en repo (smb/.smbcredentials.example)"
        else
          warn "Plantilla SMB no encontrada en repo."
        fi
        ;;
    esac
  done

  # Snapshot de paquetes apt y versiones
  section "Snapshot del sistema"

  mkdir -p "$DOTFILES_DIR/system"
  apt-mark showmanual | sort > "$DOTFILES_DIR/system/apt-packages.txt"
  success "apt-packages.txt actualizado ($(wc -l < "$DOTFILES_DIR/system/apt-packages.txt") paquetes)"

  # Versiones de Java instaladas vía SDKMAN
  local java_versions
  java_versions=$(detect_java_versions)
  if [[ -n "$java_versions" ]]; then
    echo "$java_versions" > "$DOTFILES_DIR/system/java-versions.txt"
    success "java-versions.txt actualizado"
  fi

  # Versiones de Node instaladas vía nvm
  local node_versions
  node_versions=$(detect_node_versions)
  if [[ -n "$node_versions" ]]; then
    echo "$node_versions" > "$DOTFILES_DIR/system/node-versions.txt"
    success "node-versions.txt actualizado"
  fi

  # npm paquetes globales
  if command_exists npm; then
    npm list -g --depth=0 --json > "$DOTFILES_DIR/system/npm-global.json" 2>/dev/null || true
    success "npm-global.json actualizado"
  fi
}

# ─── Git commit y push ────────────────────────────────────────────────────────
git_commit_push() {
  section "Git"
  cd "$DOTFILES_DIR"

  local changes
  changes=$(git status --porcelain)

  if [[ -z "$changes" ]]; then
    success "No hay cambios nuevos."
    return
  fi

  info "Cambios detectados:"
  git status --short | tee -a "$LOG_FILE"

  git add -A
  local msg="backup: $(date '+%Y-%m-%d %H:%M') [$(hostname)]"
  git commit -m "$msg" >> "$LOG_FILE" 2>&1
  success "Commit: $msg"

  if [[ "$AUTO_PUSH" == true ]]; then
    git push >> "$LOG_FILE" 2>&1
    success "Push completado."
  else
    echo ""
    info "Para subir los cambios: cd ~/dotfiles && git push"
    info "O la próxima vez: bash backup.sh --push"
  fi
}

print_summary() {
  echo ""
  echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}${CYAN}  Backup completo${NC}"
  echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  Log: ${DIM}$LOG_FILE${NC}"
  echo ""
  echo -e "  ${BOLD}Alias sugerido para ~/.zshrc:${NC}"
  echo -e "  ${DIM}alias dotbackup='bash ~/dotfiles/scripts/backup.sh --push'${NC}"
  echo ""
  log "Backup completado: $(date)"
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
  parse_args "$@"
  show_detection
  select_items_to_backup
  show_confirmation
  run_backup
  git_commit_push
  print_summary
}

main "$@"
