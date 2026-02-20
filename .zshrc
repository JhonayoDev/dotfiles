# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="powerlevel10k/powerlevel10k"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
# plugins=(git)
plugins=(
    git
    sudo
    z
    extract
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-completions
    colored-man-pages
    command-not-found
    docker
    history
    npm
   # web-search
)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

# ========================================
# ALIAS PERSONALIZADOS
# ========================================

# Clipboard utilities
alias clip="xclip -selection clipboard"
alias paste="xclip -selection clipboard -o"
alias clipfile="xclip -selection clipboard <"

# MySQL Docker services
alias mysql-start='cd ~/Development/tools/docker-services/mysql && sudo docker compose up -d'
alias mysql-stop='cd ~/Development/tools/docker-services/mysql && sudo docker compose stop'
alias mysql-logs='cd ~/Development/tools/docker-services/mysql && sudo docker compose logs -f'
#alias mysql-status="docker ps --filter 'name=dev-mysql'"
alias mysql-status='docker ps --filter "name=dev-mysql" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias mysql-status-short="docker inspect -f '{{.Name}} - {{.State.Status}}' dev-mysql"
alias mysql-docker="docker exec -it dev-mysql mysql -u root -p"

# System utilities
alias fix-mouse='sudo systemctl restart logid'

# Navegación común
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Git shortcuts (adicionales a los del plugin)
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline'

# Docker shortcuts
alias dc='docker compose'
alias dcu='docker compose up -d'
alias dcd='docker compose down'
alias dcl='docker compose logs -f'

# ========================================
# Funciones de fzf
# ========================================

# Función para buscar alias interactivamente
find-alias() {
    # Buscar entre todos tus alias
    selected=$(alias | fzf --height 40% --reverse --border \
        --preview 'echo {}' \
        --preview-window=up:1:wrap)
    
    if [[ -n $selected ]]; then
        # Extraer solo el comando del alias
        command=$(echo $selected | cut -d'=' -f1)
        echo "Alias seleccionado: $command"
        # Opcional: ejecutarlo directamente
        # eval $command
    fi
}

# Buscar solo tus alias personalizados
my-alias() {
    alias | grep -E "(clip|mysql|fix-)" | fzf --height 40% --reverse --border
}

# Buscar y ejecutar comando del historial
fh() {
    eval $(history | fzf --tac --height 40% | sed 's/^[ ]*[0-9]*[ ]*//')
}

# Buscar archivos de código y abrirlos
fcode() {
    file=$(find . -name "*.js" -o -name "*.py" -o -name "*.php" -o -name "*.html" | fzf)
    [[ -n $file ]] && code $file
}

# Buscar procesos
fkill() {
    ps aux | fzf | awk '{print $2}' | xargs kill
}

# Buscar directorios y navegar
fcd() {
    dir=$(find . -type d | fzf --height 40% --reverse --border)
    [[ -n $dir ]] && cd "$dir"
}

# Buscar texto en archivos
fsearch() {
    if [[ -z "$1" ]]; then
        echo "Uso: fsearch <término>"
        echo "Ejemplo: fsearch 'function'"
        return 1
    fi
    
    # Buscar en archivos de código principalmente
    grep -r --include="*.js" --include="*.py" --include="*.php" --include="*.html" \
          --include="*.css" --include="*.json" --include="*.yml" --include="*.yaml" \
          --include="*.md" --include="*.txt" \
          --color=always -n "$1" . | fzf --ansi --height 60% --reverse --border
}

# Función alternativa para buscar en todos los archivos
fsearch-all() {
    if [[ -z "$1" ]]; then
        echo "Uso: fsearch-all <término>"
        return 1
    fi
    grep -r --color=always -n "$1" . | fzf --ansi --height 60% --reverse --border
}
export PATH="$HOME/.local/bin:$PATH"

export NVM_DIR="$HOME/.config/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
export ANDROID_HOME=$HOME/android-sdk
export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$PATH
export PATH=$ANDROID_HOME/platform-tools:$PATH

# opencode
export PATH=/home/jhonayo/.opencode/bin:$PATH
export PATH="$PATH:$HOME/.pub-cache/bin"

# Neovim (binario oficial)
export PATH="$PATH:/opt/nvim-linux-x86_64/bin"
