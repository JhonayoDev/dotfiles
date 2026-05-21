#!/usr/bin/env bash
# ~/dotfiles/scripts/devpod/init-devpod.sh
#
# Genera la configuración de DevPod para un proyecto.
# Corre desde la raíz del proyecto.
#
# Uso:
#   bash init-devpod.sh                   # interactivo, detecta automático
#   bash init-devpod.sh --mode personal   # solo .devcontainer-devpod/
#   bash init-devpod.sh --mode team       # solo .devcontainer/
#   bash init-devpod.sh --mode both       # ambos
#   bash init-devpod.sh --force           # sobreescribe sin preguntar
#   bash init-devpod.sh --help

set -euo pipefail

# ─── Rutas ────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# ─── Source de módulos ────────────────────────────────────────
# shellcheck source=lib/utils.sh
source "$LIB_DIR/utils.sh"
# shellcheck source=lib/detect.sh
source "$LIB_DIR/detect.sh"
# shellcheck source=lib/gen_dockerfile.sh
source "$LIB_DIR/gen_dockerfile.sh"
# shellcheck source=lib/gen_devcontainer.sh
source "$LIB_DIR/gen_devcontainer.sh"
# shellcheck source=lib/gen_team.sh
source "$LIB_DIR/gen_team.sh"

# ─── Variables globales ───────────────────────────────────────
MODE="" # personal | team | both
FORCE="false"
DEVPOD_DIR=".devcontainer-devpod"

# ─── Ayuda ────────────────────────────────────────────────────
usage() {
  echo ""
  echo -e "${BOLD}Uso:${NC}"
  echo "  bash init-devpod.sh [opciones]"
  echo ""
  echo -e "${BOLD}Opciones:${NC}"
  echo "  --mode personal   Genera solo .devcontainer-devpod/ (uso personal con nvim)"
  echo "  --mode team       Genera solo .devcontainer/ (compartir con el equipo)"
  echo "  --mode both       Genera ambos"
  echo "  --force           Sobreescribe archivos existentes sin preguntar"
  echo "  --help            Muestra esta ayuda"
  echo ""
  echo -e "${BOLD}Ejemplos:${NC}"
  echo "  bash init-devpod.sh                    # interactivo"
  echo "  bash init-devpod.sh --mode personal    # solo personal"
  echo "  bash init-devpod.sh --mode both --force"
  echo ""
}

# ─── Parsear argumentos ───────────────────────────────────────
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --mode)
      shift
      MODE="$1"
      if [[ "$MODE" != "personal" && "$MODE" != "team" && "$MODE" != "both" ]]; then
        error "Modo inválido: $MODE"
        error "Opciones válidas: personal | team | both"
        exit 1
      fi
      ;;
    --force)
      FORCE="true"
      export FORCE
      ;;
    --help | -h)
      usage
      exit 0
      ;;
    *)
      error "Argumento desconocido: $1"
      usage
      exit 1
      ;;
    esac
    shift
  done
}

# ─── Selección interactiva del modo ───────────────────────────
select_mode_interactive() {
  echo -e "${BOLD}¿Qué deseas generar?${NC}"
  echo ""
  echo "  1) personal  — .devcontainer-devpod/ (tu setup con nvim)"
  echo "  2) team      — .devcontainer/ (para compartir con el equipo)"
  echo "  3) both      — ambos"
  echo ""
  local choice
  read -rp "$(echo -e "${CYAN}Opción [1/2/3]:${NC} ")" choice

  case "$choice" in
  1) MODE="personal" ;;
  2) MODE="team" ;;
  3) MODE="both" ;;
  *)
    error "Opción inválida: $choice"
    exit 1
    ;;
  esac
}

# ─── Verificaciones previas ───────────────────────────────────
preflight_checks() {
  if ! command -v jq &>/dev/null; then
    error "jq no encontrado — instalar con: sudo apt install jq"
    exit 1
  fi

  # Verificar que estamos en la raíz de un proyecto
  if [[ ! -f "pom.xml" && ! -f "package.json" &&
    ! -f "pubspec.yaml" && ! -f ".devcontainer/devcontainer.json" ]]; then
    warn "No se detectó ningún archivo de proyecto conocido"
    warn "Asegúrate de correr desde la raíz del proyecto"
    confirm "¿Continuar de todas formas?" || exit 0
  fi
}

# ─── Main ─────────────────────────────────────────────────────
main() {
  parse_args "$@"

  print_banner "init-devpod" "Generador de configuración DevPod"

  preflight_checks

  # Detectar proyecto
  detect_project "$(pwd)"
  print_detection

  # Si no se pasó --mode, preguntar interactivamente
  # Pero si hay config del equipo, sugerir personal como default
  if [[ -z "$MODE" ]]; then
    if [[ "$HAS_TEAM_CONFIG" == "true" ]]; then
      info "Se detectó .devcontainer/ del equipo — modo sugerido: personal"
    else
      info "No se detectó .devcontainer/ — puedes generar ambos"
    fi
    select_mode_interactive
  fi

  info "Modo seleccionado: $MODE"
  echo ""

  # Advertencia para Flutter
  if [[ "$PROJECT_TYPE" == "flutter" ]]; then
    warn "Soporte Flutter en desarrollo — se generará estructura básica"
    warn "Revisa y ajusta manualmente las features de Flutter"
    echo ""
  fi

  # Ejecutar según modo
  local generated_files=()

  case "$MODE" in
  personal)
    gen_dockerfile
    gen_devcontainer_personal
    generated_files+=("$DEVPOD_DIR/Dockerfile" "$DEVPOD_DIR/devcontainer.json")
    ;;
  team)
    gen_devcontainer_team
    generated_files+=(".devcontainer/devcontainer.json")
    ;;
  both)
    gen_devcontainer_team
    gen_dockerfile
    gen_devcontainer_personal
    generated_files+=(
      ".devcontainer/devcontainer.json"
      "$DEVPOD_DIR/Dockerfile"
      "$DEVPOD_DIR/devcontainer.json"
    )
    ;;
  esac

  # Resumen
  print_summary "${generated_files[@]}"

  # Siguiente paso
  echo -e "${BOLD}Siguiente paso:${NC}"
  if [[ "$MODE" == "personal" || "$MODE" == "both" ]]; then
    echo ""
    echo "  devpod up . \\"
    echo "    --devcontainer-path $DEVPOD_DIR/devcontainer.json \\"
    echo "    --id ${PROJECT_NAME} \\"
    echo "    --ide none"
  fi
}

main "$@"
