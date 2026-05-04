#!/usr/bin/env bash
# ~/dotfiles/install-devbox.sh
#
# Atajo para aplicar el perfil devbox.
# Equivalente a: bash install.sh devbox
exec bash "$(dirname "$0")/install.sh" devbox
