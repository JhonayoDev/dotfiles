#!/usr/bin/env bash
# lib/gen_devcontainer.sh
#
# Genera el devcontainer.json personal para .devcontainer-devpod/
# Usa las variables detectadas por detect.sh para construir
# las features, puertos y remoteEnv correctos según el proyecto.
#
# Requiere: utils.sh + detect.sh sourced, variables exportadas por detect_project()

gen_devcontainer_personal() {
  local dest="${DEVPOD_DIR:-.devcontainer-devpod}"
  local outfile="$dest/devcontainer.json"

  section "Generando devcontainer.json personal"

  safe_write "$outfile" || return 0

  mkdir -p "$dest"

  # ─── Construir bloque de features ─────────────────────────
  local features_block
  features_block=$(_build_features_block)

  # ─── Construir bloque de puertos ──────────────────────────
  local ports_block
  ports_block=$(_build_ports_block)

  # ─── Construir remoteEnv ──────────────────────────────────
  local remote_env_block
  remote_env_block=$(_build_remote_env_block)

  # ─── Construir postCreateCommand ──────────────────────────
  local post_create
  post_create=$(_build_post_create)

  # ─── Escribir JSON ────────────────────────────────────────
  cat >"$outfile" <<JSON_EOF
{
  "name": "${PROJECT_NAME} (devpod/nvim)",
  "build": {
    "dockerfile": "Dockerfile",
    "context": ".devcontainer-devpod",
    "args": {
      "USERNAME": "vscode",
      "USER_UID": "1000",
      "USER_GID": "1000"
    }
  },
  "features": {
${features_block}
  },
  "remoteEnv": {
${remote_env_block}
  },
  "postCreateCommand": "${post_create}",
  "forwardPorts": [${ports_block}],
  "remoteUser": "vscode"
}
JSON_EOF

  success "devcontainer.json personal generado: $outfile"
}

# ─── Helpers internos ─────────────────────────────────────────

_build_features_block() {
  local lines=()

  # Docker-in-Docker siempre presente
  lines+=('    "ghcr.io/devcontainers/features/docker-in-docker:2": {}')

  # Java: si es proyecto java, 21 como main + versión del proyecto adicional
  if [[ "$PROJECT_TYPE" == "java" ]]; then
    local additional=""
    # Solo agregar additionalVersions si es diferente de 21
    if [[ -n "$JAVA_VERSION" && "$JAVA_VERSION" != "21" ]]; then
      additional=",
      \"additionalVersions\": \"${JAVA_VERSION}\""
    fi
    lines+=("    \"ghcr.io/devcontainers/features/java:1\": {
      \"version\": \"21\",
      \"installMaven\": \"true\",
      \"installGradle\": \"false\"${additional}
    }")
  fi

  # Node: siempre presente (requerido por plugins de nvim)
  local node_ver="${NODE_VERSION_REQ:-22}"
  # Para proyectos Java usamos 22 fijo para nvim, no la versión del proyecto
  if [[ "$PROJECT_TYPE" == "java" ]]; then
    node_ver="22"
  fi
  lines+=("    \"ghcr.io/devcontainers/features/node:1\": {
      \"version\": \"${node_ver}\"
    }")

  # Flutter: stub — soporte pendiente
  if [[ "$PROJECT_TYPE" == "flutter" ]]; then
    warn "Flutter detectado — soporte de features pendiente"
    warn "Agrega manualmente la feature de Flutter cuando esté disponible"
  fi

  # Unir con comas — el último elemento no lleva coma
  local result=""
  local count=${#lines[@]}
  for i in "${!lines[@]}"; do
    if [[ $i -lt $((count - 1)) ]]; then
      result+="${lines[$i]},\n"
    else
      result+="${lines[$i]}\n"
    fi
  done

  echo -e "$result" | sed '$ s/,$//'
}

_build_ports_block() {
  local ports=()

  # Puertos según tipo de proyecto
  case "$PROJECT_TYPE" in
  java)
    ports+=("8080")
    ;;
  node)
    # Detectar si es Vite, Next, etc. por package.json
    if [[ -f "package.json" ]]; then
      grep -q '"vite"' package.json 2>/dev/null && ports+=("5173") || ports+=("3000")
    else
      ports+=("3000")
    fi
    ;;
  flutter)
    ports+=("8080")
    ;;
  esac

  # Agregar puertos de base de datos detectados
  if [[ -n "$DB_PORTS" ]]; then
    for p in $DB_PORTS; do
      ports+=("$p")
    done
  fi

  # Formatear como array JSON
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

_build_remote_env_block() {
  local lines=()

  # Variables del proyecto según tipo
  case "$PROJECT_TYPE" in
  java)
    # Leer remoteEnv del devcontainer del equipo si existe
    if [[ "$HAS_TEAM_CONFIG" == "true" ]] && command -v jq &>/dev/null; then
      local team_env
      team_env=$(jq -r '.remoteEnv // {} | to_entries[] | "    \"\(.key)\": \"\(.value)\""' \
        .devcontainer/devcontainer.json 2>/dev/null)
      if [[ -n "$team_env" ]]; then
        while IFS= read -r line; do
          lines+=("$line")
        done <<<"$team_env"
      fi
    fi
    ;;
  esac

  # ─── Git env (descomentar si SSH agent forwarding no funciona) ─
  # lines+=('    "GIT_AUTHOR_NAME": "jhonayo"')
  # lines+=('    "GIT_AUTHOR_EMAIL": "j.iramirezpavez@gmail.com"')
  # lines+=('    "GIT_COMMITTER_NAME": "jhonayo"')
  # lines+=('    "GIT_COMMITTER_EMAIL": "j.iramirezpavez@gmail.com"')

  # Si no hay variables, agregar placeholder
  if [[ ${#lines[@]} -eq 0 ]]; then
    echo '    "DEVCONTAINER": "true"'
    return
  fi

  # Unir con comas
  local count=${#lines[@]}
  for i in "${!lines[@]}"; do
    if [[ $i -lt $((count - 1)) ]]; then
      echo "${lines[$i]},"
    else
      echo "${lines[$i]}"
    fi
  done
}

_build_post_create() {
  local cmds=()

  # Siempre: fix permisos npm (evita EACCES en Mason)
  cmds+=("sudo chown -R \$(id -u):\$(id -g) ~/.npm 2>/dev/null || true")

  # Docker compose si existe
  cmds+=("[ -f docker-compose.yml ] && docker compose up -d || echo 'No docker-compose.yml, skipping'")

  # Unir con && explícito
  local result=""
  local count=${#cmds[@]}
  for i in "${!cmds[@]}"; do
    if [[ $i -lt $((count - 1)) ]]; then
      result+="${cmds[$i]} && "
    else
      result+="${cmds[$i]}"
    fi
  done
  echo "$result"
}
