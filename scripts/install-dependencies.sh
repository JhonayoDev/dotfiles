# ~/.config/nvim/scripts/install-dependencies.sh
#!/bin/bash

set -e # Exit on error

echo "🚀 Installing Neovim dependencies..."

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to install lazygit
install_lazygit() {
  if command_exists lazygit; then
    echo -e "${GREEN}✓${NC} lazygit already installed"
    lazygit --version
    return
  fi

  echo -e "${YELLOW}→${NC} Installing lazygit..."

  cd /tmp
  LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
  curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
  tar xf lazygit.tar.gz lazygit
  sudo install lazygit /usr/local/bin
  rm lazygit lazygit.tar.gz

  echo -e "${GREEN}✓${NC} lazygit installed successfully"
  lazygit --version
}

# Function to install lazydocker
install_lazydocker() {
  if command_exists lazydocker; then
    echo -e "${GREEN}✓${NC} lazydocker already installed"
    lazydocker --version
    return
  fi

  echo -e "${YELLOW}→${NC} Installing lazydocker..."

  cd /tmp
  curl -s https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash

  echo -e "${GREEN}✓${NC} lazydocker installed successfully"
  lazydocker --version
}

# Function to install Java (SDKMAN)
install_java() {
  if command_exists sdk; then
    echo -e "${GREEN}✓${NC} SDKMAN already installed"
    return
  fi

  echo -e "${YELLOW}→${NC} Installing SDKMAN..."
  curl -s "https://get.sdkman.io" | bash
  source "$HOME/.sdkman/bin/sdkman-init.sh"

  echo -e "${YELLOW}→${NC} Installing Java 21..."
  sdk install java 21.0.8-tem
  sdk install java 17.0.16-tem
  sdk default java 21.0.8-tem

  echo -e "${GREEN}✓${NC} Java installed successfully"
  java --version
}

# Function to install Node.js (for Copilot, etc)
install_node() {
  if command_exists node; then
    echo -e "${GREEN}✓${NC} Node.js already installed"
    node --version
    return
  fi

  echo -e "${YELLOW}→${NC} Installing Node.js (via nvm)..."
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

  nvm install --lts
  nvm use --lts

  echo -e "${GREEN}✓${NC} Node.js installed successfully"
  node --version
}

# Function to install Neovim (if not installed)
install_neovim() {
  if command_exists nvim; then
    echo -e "${GREEN}✓${NC} Neovim already installed"
    nvim --version | head -n 1
    return
  fi

  echo -e "${YELLOW}→${NC} Installing Neovim (latest stable)..."

  # For Ubuntu/Debian
  if command_exists apt; then
    sudo add-apt-repository ppa:neovim-ppa/unstable -y
    sudo apt update
    sudo apt install neovim -y
  # For Arch
  elif command_exists pacman; then
    sudo pacman -S neovim
  fi

  echo -e "${GREEN}✓${NC} Neovim installed successfully"
  nvim --version | head -n 1
}

# Main installation
main() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Neovim Development Environment Setup"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # Core tools
  install_neovim
  install_node

  # Development tools
  install_java

  # Git & Docker TUI
  install_lazygit
  install_lazydocker

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "${GREEN}✓ All dependencies installed!${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "Next steps:"
  echo "  1. Restart your shell or run: source ~/.bashrc (or ~/.zshrc)"
  echo "  2. Open Neovim: nvim"
  echo "  3. Let Lazy.nvim install plugins automatically"
  echo "  4. Run :checkhealth to verify everything"
  echo ""
}

# Run main function
main
