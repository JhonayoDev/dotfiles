#!/usr/bin/env bash
# lib/detect.sh
#
# Detecta el tipo de proyecto y si ya existe un devcontainer del equipo.
# Exporta variables que los demás módulos consumen.
#
# Variables exportadas:
#   PROJECT_TYPE      java | node | flutter | unknown
#   PROJECT_NAME      nombre del proyecto (dirname o desde json/pom)
#   HAS_TEAM_CONFIG   true | false  (.devcontainer/devcontainer.json existe)
#   HAS_POM           true | false
#   HAS_PACKAGE_JSON  true | false
#   HAS_PUBSPEC       true | false
#   HAS_COMPOSE       true | false
#   JAVA_VERSION      versión del proyecto desde pom.xml (ej: "17")
#   NODE_VERSION_REQ  versión de node desde package.json engines (ej: "22")
#   DB_PORTS          puertos detectados de base de datos (ej: "3306 5432")

# Se asume que utils.sh ya fue sourceado antes de llamar detect_project

detect_project() {
  local cwd="${1:-$(pwd)}"

  # ─── Defaults ─────────────────────────────────────────────
  PROJECT_TYPE="unknown"
  PROJECT_NAME="$(basename "$cwd")"
  HAS_TEAM_CONFIG="false"
  HAS_POM="false"
  HAS_PACKAGE_JSON="false"
  HAS_PUBSPEC="false"
  HAS_COMPOSE="false"
  JAVA_VERSION=""
  NODE_VERSION_REQ="22"
  DB_PORTS=""

  # ─── devcontainer del equipo ──────────────────────────────
  if [[ -f "$cwd/.devcontainer/devcontainer.json" ]]; then
    HAS_TEAM_CONFIG="true"
  fi

  # ─── Detectar archivos clave ──────────────────────────────
  [[ -f "$cwd/pom.xml" ]] && HAS_POM="true"
  [[ -f "$cwd/package.json" ]] && HAS_PACKAGE_JSON="true"
  [[ -f "$cwd/pubspec.yaml" ]] && HAS_PUBSPEC="true"
  [[ -f "$cwd/docker-compose.yml" || -f "$cwd/compose.yml" ]] && HAS_COMPOSE="true"

  # ─── Determinar tipo de proyecto ──────────────────────────
  if [[ "$HAS_POM" == "true" ]]; then
    PROJECT_TYPE="java"
  elif [[ "$HAS_PUBSPEC" == "true" ]]; then
    PROJECT_TYPE="flutter"
  elif [[ "$HAS_PACKAGE_JSON" == "true" ]]; then
    PROJECT_TYPE="node"
  fi

  # ─── Leer versión Java desde pom.xml ──────────────────────
  if [[ "$HAS_POM" == "true" ]]; then
    local pom="$cwd/pom.xml"

    # Prioridad: maven.compiler.release > maven.compiler.source > java.version
    local ver
    ver=$(grep -oP '(?<=<maven\.compiler\.release>)\d+(?=</maven\.compiler\.release>)' "$pom" 2>/dev/null | head -1 || true)

    if [[ -z "$ver" ]]; then
      ver=$(grep -oP '(?<=<maven\.compiler\.source>)\d+(?=</maven\.compiler\.source>)' "$pom" 2>/dev/null | head -1 || true)
    fi

    if [[ -z "$ver" ]]; then
      ver=$(grep -oP '(?<=<java\.version>)\d+(?=</java\.version>)' "$pom" 2>/dev/null | head -1 || true)
    fi

    # Normalizar: 1.8 → 8
    if [[ "$ver" == "1.8" ]]; then
      ver="8"
    fi

    JAVA_VERSION="${ver:-21}"

    # Nombre del proyecto desde pom.xml si está disponible
    local pom_name
    pom_name=$(grep -oP '(?<=<artifactId>)[^<]+(?=</artifactId>)' "$pom" 2>/dev/null | head -1 || true)
    [[ -n "$pom_name" ]] && PROJECT_NAME="$pom_name"
  fi

  # ─── Leer versión Node desde package.json ─────────────────
  if [[ "$HAS_PACKAGE_JSON" == "true" ]] && command -v jq &>/dev/null; then
    local pkg="$cwd/package.json"
    local node_engine
    node_engine=$(jq -r '.engines.node // empty' "$pkg" 2>/dev/null)

    if [[ -n "$node_engine" ]]; then
      # Extraer solo el número major (ej: ">=18.0.0" → "18", "22" → "22")
      local node_major
      node_major=$(echo "$node_engine" | grep -oP '\d+' | head -1)
      [[ -n "$node_major" ]] && NODE_VERSION_REQ="$node_major"
    fi

    # Nombre desde package.json
    local pkg_name
    pkg_name=$(jq -r '.name // empty' "$pkg" 2>/dev/null)
    [[ -n "$pkg_name" ]] && PROJECT_NAME="$pkg_name"
  fi

  # ─── Detectar puertos de base de datos desde compose ──────
  if [[ "$HAS_COMPOSE" == "true" ]]; then
    local compose_file="$cwd/docker-compose.yml"
    [[ ! -f "$compose_file" ]] && compose_file="$cwd/compose.yml"

    # Detectar puertos conocidos de bases de datos
    local ports=""
    grep -qP '3306' "$compose_file" 2>/dev/null && ports="$ports 3306" || true
    grep -qP '5432' "$compose_file" 2>/dev/null && ports="$ports 5432" || true
    grep -qP '6379' "$compose_file" 2>/dev/null && ports="$ports 6379" || true
    grep -qP '27017' "$compose_file" 2>/dev/null && ports="$ports 27017" || true
    grep -qP '5672' "$compose_file" 2>/dev/null && ports="$ports 5672" || true

    DB_PORTS=$(echo "$ports" | xargs) # trim spaces
  fi

  # ─── Nombre del proyecto desde devcontainer del equipo ────
  if [[ "$HAS_TEAM_CONFIG" == "true" ]] && command -v jq &>/dev/null; then
    local team_name
    team_name=$(jq -r '.name // empty' "$cwd/.devcontainer/devcontainer.json" 2>/dev/null)
    [[ -n "$team_name" ]] && PROJECT_NAME="$team_name"
  fi

  # Exportar todo
  export PROJECT_TYPE PROJECT_NAME HAS_TEAM_CONFIG
  export HAS_POM HAS_PACKAGE_JSON HAS_PUBSPEC HAS_COMPOSE
  export JAVA_VERSION NODE_VERSION_REQ DB_PORTS
}

# ─── Print del resultado de detección ─────────────────────────
print_detection() {
  section "Proyecto detectado"

  echo -e "  ${BOLD}Nombre:${NC}        $PROJECT_NAME"
  echo -e "  ${BOLD}Tipo:${NC}          $PROJECT_TYPE"
  echo ""

  # Archivos encontrados
  echo -e "  ${BOLD}Archivos:${NC}"
  local found_any=false
  [[ "$HAS_POM" == "true" ]] && {
    echo -e "  ${GREEN}✓${NC} pom.xml"
    found_any=true
  }
  [[ "$HAS_PACKAGE_JSON" == "true" ]] && {
    echo -e "  ${GREEN}✓${NC} package.json"
    found_any=true
  }
  [[ "$HAS_PUBSPEC" == "true" ]] && {
    echo -e "  ${GREEN}✓${NC} pubspec.yaml"
    found_any=true
  }
  [[ "$HAS_COMPOSE" == "true" ]] && {
    echo -e "  ${GREEN}✓${NC} docker-compose.yml"
    found_any=true
  }
  [[ "$found_any" == "false" ]] && echo -e "  ${YELLOW}⚠${NC} ninguno reconocido"
  echo ""

  # Config del equipo
  if [[ "$HAS_TEAM_CONFIG" == "true" ]]; then
    echo -e "  ${GREEN}✓${NC} .devcontainer/devcontainer.json encontrado ${DIM}(modo A — leerá del equipo)${NC}"
  else
    echo -e "  ${YELLOW}⚠${NC} .devcontainer/ no encontrado ${DIM}(modo B — se generará desde cero)${NC}"
  fi
  echo ""

  # Versiones detectadas
  echo -e "  ${BOLD}Versiones:${NC}"
  [[ "$PROJECT_TYPE" == "java" ]] &&
    echo -e "  ${CYAN}Java proyecto:${NC}  $JAVA_VERSION  ${DIM}(additionalVersions)${NC}"
  echo -e "  ${CYAN}Java jdtls:${NC}     21  ${DIM}(siempre, para LSP)${NC}"
  echo -e "  ${CYAN}Node:${NC}           ${NODE_VERSION_REQ}  ${DIM}(plugins nvim)${NC}"

  # Puertos de DB detectados
  if [[ -n "$DB_PORTS" ]]; then
    echo ""
    echo -e "  ${BOLD}Puertos DB detectados:${NC} $DB_PORTS"
  fi
  echo ""
}
