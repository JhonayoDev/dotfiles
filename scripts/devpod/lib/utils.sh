#!/usr/bin/env bash
# lib/utils.sh
#
# Colores, helpers de output y funciones de utilidad comunes.
# Se sourcea desde todos los demás scripts — no ejecutar directamente.

# ─── Colores ──────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ─── Output ───────────────────────────────────────────────────
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }
info() { echo -e "${CYAN}[INFO]${NC}  $*"; }
section() { echo -e "\n${BOLD}── $* ──${NC}"; }
dim() { echo -e "${DIM}$*${NC}"; }

# ─── Confirmación interactiva ─────────────────────────────────
# Uso: confirm "¿Sobreescribir?" && do_something
confirm() {
  local prompt="${1:-¿Continuar?}"
  local response
  read -rp "$(echo -e "${YELLOW}${prompt}${NC} [s/N] ")" response
  [[ "$response" =~ ^[sS]$ ]]
}

# ─── Verificar dependencias ───────────────────────────────────
# Uso: require_cmd jq "sudo apt install jq"
require_cmd() {
  local cmd="$1"
  local hint="${2:-instala $cmd}"
  if ! command -v "$cmd" &>/dev/null; then
    error "Comando no encontrado: $cmd"
    error "  → $hint"
    return 1
  fi
}

# ─── Leer campo JSON con fallback ─────────────────────────────
# Uso: json_get ".name" file.json "fallback"
json_get() {
  local query="$1"
  local file="$2"
  local fallback="${3:-}"
  local result
  result=$(jq -r "$query // empty" "$file" 2>/dev/null)
  echo "${result:-$fallback}"
}

# ─── Verificar si un archivo existe y preguntar sobreescritura ─
# Uso: safe_write "path/to/file" || return
# Retorna 0 si se puede escribir, 1 si el usuario canceló
safe_write() {
  local file="$1"
  local force="${FORCE:-false}"

  if [[ -f "$file" ]]; then
    if [[ "$force" == "true" ]]; then
      warn "Sobreescribiendo: $file"
      return 0
    fi
    warn "Ya existe: $file"
    confirm "¿Sobreescribir?" || return 1
  fi
  return 0
}

# ─── Banner ───────────────────────────────────────────────────
print_banner() {
  local title="${1:-devpod init}"
  local subtitle="${2:-}"
  echo -e "${BOLD}${CYAN}"
  echo "  ┌────────────────────────────────────────────┐"
  printf "  │  %-42s│\n" "$title"
  if [[ -n "$subtitle" ]]; then
    printf "  │  ${DIM}%-42s${BOLD}${CYAN}│\n" "$subtitle"
  fi
  echo "  └────────────────────────────────────────────┘"
  echo -e "${NC}"
}

# ─── Resumen de archivos generados ────────────────────────────
print_summary() {
  local files=("$@")
  echo ""
  echo -e "${BOLD}${GREEN}  Archivos generados:${NC}"
  for f in "${files[@]}"; do
    if [[ -f "$f" ]]; then
      echo -e "  ${GREEN}✓${NC} $f"
    else
      echo -e "  ${RED}✗${NC} $f (no creado)"
    fi
  done
  echo ""
}
