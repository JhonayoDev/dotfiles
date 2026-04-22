# 💤 LazyVim

A starter template for [LazyVim](https://github.com/LazyVim/LazyVim).
Refer to the [documentation](https://lazyvim.github.io/installation) to get started.

# My Neovim Configuration

Neovim setup optimized for Java/Spring Boot development with LSP, DAP, and modern tooling.

## 🚀 Quick Start

### 1. Prerequisites

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install git curl build-essential

# Clone dotfiles
git clone https://github.com/tu-usuario/dotfiles.git ~/.config
cd ~/.config/nvim
```

### 2. Install Dependencies

```bash
# Run installation script
chmod +x scripts/install-dependencies.sh
./scripts/install-dependencies.sh
```

This will install:

- ✅ Neovim (latest stable)
- ✅ Node.js (via nvm) - for Copilot and LSP servers
- ✅ Java 21 & 17 (via SDKMAN) - for Java development
- ✅ lazygit - Git TUI
- ✅ lazydocker - Docker TUI

### 3. Start Neovim

```bash
nvim
```

Lazy.nvim will automatically install all plugins on first launch.

### 4. Verify Installation

```vim
:checkhealth
```

## 📦 Manual Installation (Alternative)

### lazygit

```bash
cd /tmp
LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
tar xf lazygit.tar.gz lazygit
sudo install lazygit /usr/local/bin
```

### lazydocker

```bash
curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
```

### Java (SDKMAN)

```bash
curl -s "https://get.sdkman.io" | bash
source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk install java 21.0.8-tem
sdk install java 17.0.16-tem
```

## ⌨️ Key Features

### Java Development

- Full JDTLS integration with LSP
- Debug Adapter Protocol (DAP) for debugging
- Java file creator (`<leader>cN`)
- Package refactoring (`<leader>cM`)
- Extract refactorings (`<leader>ce`)

### Git Integration

- `<leader>gg` - LazyGit
- `<leader>ghb` - Git Blame Line
- `<leader>gb` - Open in GitHub/GitLab

### Docker Integration

- `<leader>gd` - LazyDocker

### Testing

- `<leader>cTc` - Test Class (console)
- `<leader>cTm` - Test Method (console)
- `<leader>cTC` - Debug Test Class
- `<leader>cTM` - Debug Test Method

## 📁 Structure

```
~/.config/nvim/
├── lua/
│   ├── config/           # Core configuration
│   ├── plugins/          # Plugin configurations
│   │   ├── snacks.lua
│   │   ├── lazydocker.lua
│   │   └── java/
│   │       └── creator.lua
│   └── ...
├── ftplugin/
│   └── java.lua          # Java-specific configuration
└── scripts/
    └── install-dependencies.sh
```

## 🔧 Troubleshooting

### Plugins not loading

```vim
:Lazy sync
:Lazy health
```

### LSP not working

```vim
:checkhealth lsp
:LspInfo
```

### Java not detected

```bash
which java
java --version
# Should show Java 21
```

## 📚 Documentation

- [LazyVim Docs](https://www.lazyvim.org/)
- [JDTLS Setup](https://github.com/mfussenegger/nvim-jdtls)
- [nvim-dap Guide](https://github.com/mfussenegger/nvim-dap)

## 🎯 Tested On

- ✅ Ubuntu 22.04 / 24.04
- ✅ Debian 12
- ⚠️ Arch Linux (adapt package manager in script)

```

## 📂 Estructura final de tu repo:
```

dotfiles/
├── .config/
│ └── nvim/
│ ├── lua/
│ │ ├── config/
│ │ └── plugins/
│ ├── ftplugin/
│ ├── scripts/
│ │ └── install-dependencies.sh
│ └── init.lua
├── README.md
└── .gitignore
