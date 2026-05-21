#!/usr/bin/env bash
# lib/gen_dockerfile.sh
#
# Genera el Dockerfile personal para .devcontainer-devpod/
# Siempre usa devbox-base como imagen — una sola línea FROM.
# Los build.args los pasa el devcontainer.json, no el Dockerfile.
#
# Requiere: utils.sh sourced, variables de entorno:
#   DEVPOD_DIR   ruta al directorio destino (ej: .devcontainer-devpod)
#   FORCE        true | false

gen_dockerfile() {
  local dest="${DEVPOD_DIR:-.devcontainer-devpod}"
  local outfile="$dest/Dockerfile"

  section "Generando Dockerfile personal"

  safe_write "$outfile" || return 0

  mkdir -p "$dest"

  cat >"$outfile" <<'DOCKERFILE_EOF'
# .devcontainer-devpod/Dockerfile
#
# Imagen base personal con nvim, lazygit, zsh, OMZ y plugins incluidos.
# Las features del proyecto (Java, Node, Docker) se agregan en devcontainer.json.
# No modificar — regenerar con init-devpod.sh si es necesario.
FROM ghcr.io/jhonayodev/devbox-base:latest
DOCKERFILE_EOF

  success "Dockerfile generado: $outfile"
}
