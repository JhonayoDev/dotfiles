#!/usr/bin/env bash
# lib/gen_team.sh
#
# Genera el .devcontainer/devcontainer.json para compartir con el equipo.
# Solo VS Code por ahora — sin Dockerfile, usa image directo.
#
# Requiere: utils.sh + detect.sh sourced

gen_devcontainer_team() {
  local dest=".devcontainer"
  local outfile="$dest/devcontainer.json"

  section "Generando devcontainer.json del equipo"

  safe_write "$outfile" || return 0

  mkdir -p "$dest"

  local image
  local features_block
  local ports_block
  local remote_env_block
  local extensions_block
  local post_create

  image=$(_team_image)
  features_block=$(_team_features_block)
  ports_block=$(_team_ports_block)
  remote_env_block=$(_team_remote_env_block)
  extensions_block=$(_team_extensions_block)
  post_create=$(_team_post_create)

  cat >"$outfile" <<JSON_EOF
{
  "name": "${PROJECT_NAME}",
  "image": "${image}",
  "features": {
${features_block}
  },
  "remoteEnv": {
${remote_env_block}
  },
  "customizations": {
    "vscode": {
      "extensions": [
${extensions_block}
      ]
    }
  },
  "postCreateCommand": "${post_create}",
  "forwardPorts": [${ports_block}],
  "remoteUser": "vscode"
}
JSON_EOF

  success "devcontainer.json equipo generado: $outfile"
  warn "Recuerda revisar y ajustar remoteEnv antes de compartir"
}

# ─── Helpers internos ─────────────────────────────────────────

_team_image() {
  case "$PROJECT_TYPE" in
  java)
    # Imagen base estándar de devcontainers para Java
    echo "mcr.microsoft.com/devcontainers/java:21-noble"
    ;;
  node)
    echo "mcr.microsoft.com/devcontainers/javascript-node:22-noble"
    ;;
  flutter)
    warn "Flutter: imagen base pendiente — define manualmente"
    echo "mcr.microsoft.com/devcontainers/base:noble"
    ;;
  *)
    echo "mcr.microsoft.com/devcontainers/base:noble"
    ;;
  esac
}

_team_features_block() {
  local lines=()

  case "$PROJECT_TYPE" in
  java)
    local additional=""
    if [[ -n "$JAVA_VERSION" && "$JAVA_VERSION" != "21" ]]; then
      additional=",
      \"additionalVersions\": \"${JAVA_VERSION}\""
    fi
    lines+=("    \"ghcr.io/devcontainers/features/java:1\": {
      \"version\": \"21\",
      \"installMaven\": \"true\",
      \"installGradle\": \"false\"${additional}
    }")
    lines+=('    "ghcr.io/devcontainers/features/docker-in-docker:2": {}')
    ;;
  node)
    lines+=("    \"ghcr.io/devcontainers/features/node:1\": {
      \"version\": \"${NODE_VERSION_REQ:-22}\"
    }")
    ;;
  *)
    lines+=('    "ghcr.io/devcontainers/features/docker-in-docker:2": {}')
    ;;
  esac

  local count=${#lines[@]}
  for i in "${!lines[@]}"; do
    if [[ $i -lt $((count - 1)) ]]; then
      echo "${lines[$i]},"
    else
      echo "${lines[$i]}"
    fi
  done
}

_team_ports_block() {
  local ports=()

  case "$PROJECT_TYPE" in
  java) ports+=("8080") ;;
  node)
    if [[ -f "package.json" ]]; then
      grep -q '"vite"' package.json 2>/dev/null && ports+=("5173") || ports+=("3000")
    else
      ports+=("3000")
    fi
    ;;
  flutter) ports+=("8080") ;;
  esac

  if [[ -n "$DB_PORTS" ]]; then
    for p in $DB_PORTS; do
      ports+=("$p")
    done
  fi

  local result=""
  local count=${#ports[@]}
  for i in "${!ports[@]}"; do
    if [[ $i -lt $((count - 1)) ]]; then
      result+="${ports[$i]}, "
    else
      result+="${ports[$i]}"
    fi
  done
  echo "$result"
}

_team_remote_env_block() {
  case "$PROJECT_TYPE" in
  java)
    # Placeholders para que el equipo complete
    cat <<'ENV_EOF'
    "DB_URL": "jdbc:mysql://localhost:3306/db_name",
    "DB_USER": "db_user",
    "DB_PASSWORD": "db_password"
ENV_EOF
    ;;
  node)
    echo '    "NODE_ENV": "development"'
    ;;
  *)
    echo '    "DEVCONTAINER": "true"'
    ;;
  esac
}

_team_extensions_block() {
  case "$PROJECT_TYPE" in
  java)
    cat <<'EXT_EOF'
        "vscjava.vscode-java-pack",
        "vmware.vscode-spring-boot",
        "vscjava.vscode-spring-initializr",
        "vscjava.vscode-spring-boot-dashboard"
EXT_EOF
    ;;
  node)
    cat <<'EXT_EOF'
        "dbaeumer.vscode-eslint",
        "esbenp.prettier-vscode"
EXT_EOF
    ;;
  flutter)
    cat <<'EXT_EOF'
        "Dart-Code.dart-code",
        "Dart-Code.flutter"
EXT_EOF
    ;;
  *)
    echo '        "editorconfig.editorconfig"'
    ;;
  esac
}

_team_post_create() {
  case "$PROJECT_TYPE" in
  java)
    echo "[ -f docker-compose.yml ] && docker compose up -d || echo 'No docker-compose.yml, skipping'"
    ;;
  node)
    echo "npm install"
    ;;
  *)
    echo "echo 'devcontainer ready'"
    ;;
  esac
}
