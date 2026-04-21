# ~/.zshrc — Cross-platform interactive zsh config (macOS · WSL · Ubuntu/Debian)
# Personal overrides and secrets go in ~/.zshrc.local (sourced at the end)

# ── PLATFORM ──────────────────────────────────────────────────────────────────

_detect_platform() {
    case "$(uname -s)" in
        Darwin) echo "macos" ;;
        Linux)
            if grep -qi microsoft /proc/version 2>/dev/null; then echo "wsl"
            elif [[ -f /etc/os-release ]]; then
                . /etc/os-release
                case "$ID" in
                    ubuntu|debian|mint)                 echo "debian" ;;
                    fedora|rhel|centos|rocky|almalinux) echo "redhat" ;;
                    arch|manjaro|endeavouros)           echo "arch" ;;
                    *)                                  echo "linux" ;;
                esac
            else echo "linux"
            fi ;;
        *) echo "unknown" ;;
    esac
}
PLATFORM=$(_detect_platform)

# ── INIT ──────────────────────────────────────────────────────────────────────

# System info on new shell (fastfetch > neofetch)
if command -v fastfetch >/dev/null 2>&1; then
    fastfetch
elif command -v neofetch >/dev/null 2>&1; then
    neofetch
fi

# ── SHELL OPTIONS ─────────────────────────────────────────────────────────────

setopt AUTO_CD              # type a directory name to cd into it
setopt GLOB_DOTS            # include dotfiles in glob patterns
setopt EXTENDED_GLOB        # extended globbing (^, #, ~)
setopt NO_CASE_GLOB         # case-insensitive globbing
setopt INTERACTIVE_COMMENTS # allow # comments in interactive shell
setopt NO_BEEP              # no terminal bell

# ── HISTORY ───────────────────────────────────────────────────────────────────

HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS SHARE_HISTORY

# ── COMPLETION ────────────────────────────────────────────────────────────────

autoload -Uz compinit && compinit
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'  # case-insensitive tab completion
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# ── ENV ───────────────────────────────────────────────────────────────────────

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

export EDITOR="${EDITOR:-vim}"
export VISUAL="${VISUAL:-$EDITOR}"
export CLICOLOR=1

# Coloured man pages
export LESS_TERMCAP_mb=$'\e[1;31m'
export LESS_TERMCAP_md=$'\e[1;31m'
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_se=$'\e[0m'
export LESS_TERMCAP_so=$'\e[1;44;33m'
export LESS_TERMCAP_ue=$'\e[0m'
export LESS_TERMCAP_us=$'\e[1;32m'
command -v bat >/dev/null 2>&1 && export MANPAGER="sh -c 'col -bx | bat -l man -p'"

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

# Homebrew (macOS)
if [[ "$PLATFORM" == "macos" ]] && command -v brew >/dev/null 2>&1; then
    eval "$(brew shellenv)"
    FPATH="$(brew --prefix)/share/zsh/site-functions:$FPATH"
fi

# FZF
if [[ -f "$HOME/.fzf.zsh" ]]; then
    . "$HOME/.fzf.zsh"
    export FZF_DEFAULT_COMMAND='fd --type f --strip-cwd-prefix --hidden --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
fi

# Clipboard (platform-aware)
if [[ "$PLATFORM" == "macos" ]]; then
    alias copy='pbcopy'
    alias paste='pbpaste'
elif [[ "$PLATFORM" == "wsl" ]] && command -v clip.exe >/dev/null 2>&1; then
    alias copy='clip.exe'
    alias paste='powershell.exe -c Get-Clipboard'
elif command -v wl-copy >/dev/null 2>&1; then
    alias copy='wl-copy'
    alias paste='wl-paste'
elif command -v xclip >/dev/null 2>&1; then
    alias copy='xclip -selection clipboard'
    alias paste='xclip -selection clipboard -o'
fi

# ── FUNCTIONS ─────────────────────────────────────────────────────────────────

# Best available directory lister (eza > lsd > ls)
_list_dir() {
    if command -v eza >/dev/null 2>&1; then
        eza --icons --group-directories-first
    elif command -v lsd >/dev/null 2>&1; then
        lsd --group-dirs=first --icon=auto
    else
        ls -CF
    fi
}

# cd and list in one step
cd() { builtin cd "${1:--}" && _list_dir; }

# Yes/no confirmation. Usage: prompt_continue "Continue?" && do_thing
prompt_continue() {
    read -rk1 "REPLY?$1 (y/n): "
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

# Extract common archive formats. Usage: extract file.tar.gz [file2 ...]
extract() {
    for file in "$@"; do
        if [[ -f "$file" ]]; then
            case "$file" in
                *.tar.bz2) tar xjf "$file" ;;
                *.tar.gz)  tar xzf "$file" ;;
                *.tar.xz)  tar xJf "$file" ;;
                *.bz2)     bunzip2 "$file" ;;
                *.rar)     unrar x "$file" ;;
                *.gz)      gunzip "$file" ;;
                *.tar)     tar xf "$file" ;;
                *.tbz2)    tar xjf "$file" ;;
                *.tgz)     tar xzf "$file" ;;
                *.zip)     unzip "$file" ;;
                *.Z)       uncompress "$file" ;;
                *.7z)      7z x "$file" ;;
                *)         print "Unknown archive: $file" ;;
            esac
        else
            print "File not found: $file"
        fi
    done
}

mkcd()   { mkdir -p "$1" && cd "$1"; }                     # mkdir then cd into it
bak()    { cp -r "$1" "$1.bak"; }                          # create .bak copy
up()     { local p="" i; for ((i=0; i<${1:-1}; i++)); do p+="../"; done; cd "$p"; }
pwdtail(){ pwd | awk -F/ '{print $(NF-1)"/"$NF}'; }        # last two path components

# Internal + external IP
myip() {
    local iface internal
    if [[ "$PLATFORM" == "macos" ]]; then
        iface=$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')
        internal=$(ipconfig getifaddr "$iface" 2>/dev/null)
    else
        iface=$(ip route 2>/dev/null | awk '/^default/{print $5; exit}')
        internal=$(ip addr show "$iface" 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1)
    fi
    print "Internal: ${internal:-n/a}"
    print "External: $(curl -s ifconfig.me || print n/a)"
}

cpg() { cp "$1" "$2" && [[ -d "$2" ]] && cd "$2"; }    # copy + cd to dest dir
mvg() { mv "$1" "$2" && [[ -d "$2" ]] && cd "$2"; }    # move + cd to dest dir

# Search file contents. Usage: search_files "TODO"
search_files() {
    if command -v rg >/dev/null 2>&1; then
        rg -n --color=always "$1" | less -R
    else
        grep -RIn --color=always "$1" . | less -R
    fi
}

# Quick git workflow
gcom()   { git add . && git commit -m "$1"; }
lazy()   { git add . && git commit -m "$1" && git push; }
gclean() { git fetch -p; git branch --merged | grep -Ev '(^\*|main|master|dev)' | xargs git branch -d 2>/dev/null; }

# Command cheatsheet. Usage: cheat curl
cheat() { curl -s "cht.sh/$1"; }

# FZF-powered interactive functions (require fzf + fd)
if command -v fzf >/dev/null 2>&1; then
    fe()    { local f; f=$(fd --type f --hidden --exclude .git | fzf --query="${1:-}" --select-1 --exit-0) && ${EDITOR:-vim} "$f"; }
    fcd()   { local d; d=$(fd --type d --hidden --exclude .git | fzf --query="${1:-}" --select-1 --exit-0) && cd "$d"; }
    fkill() { local p; p=$(ps -ef | sed 1d | fzf -m | awk '{print $2}') && print "$p" | xargs kill -"${1:-9}"; }
    fshow() { local f; f=$(fd --type f --hidden --exclude .git | fzf --query="${1:-}" --select-1 --exit-0 \
                  --preview "bat --color=always --style=numbers --line-range=:500 {}") && bat "$f"; }
fi

# Switch the active Starship prompt theme.
# Usage: starship-theme [theme-name]
# No args: list available themes. With name: apply that theme.
starship-theme() {
    if [[ -z "${DEV_TOOLBOX:-}" ]]; then
        echo "Error: DEV_TOOLBOX is not set. Run setup-distro.sh --only=dotfiles first." >&2
        return 1
    fi
    local themes_dir="$DEV_TOOLBOX/.config/starship"
    if [[ ! -d "$themes_dir" ]]; then
        echo "Error: themes directory not found: $themes_dir" >&2
        return 1
    fi
    if [[ $# -eq 0 ]]; then
        echo "Available themes:"
        for f in "$themes_dir"/*.toml; do
            [[ -f "$f" ]] && echo "  $(basename "${f%.toml}")"
        done
        echo ""
        echo "Usage: starship-theme <theme-name>"
        return 0
    fi
    local src="$themes_dir/${1}.toml"
    if [[ ! -f "$src" ]]; then
        echo "Error: theme '$1' not found. Run 'starship-theme' with no args to list available themes." >&2
        return 1
    fi
    local dest="${STARSHIP_CONFIG:-$HOME/.config/starship/starship.toml}"
    cp "$src" "$dest" && echo "Starship theme set to '$1' → $dest"
}

# ── ALIASES ───────────────────────────────────────────────────────────────────

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ~='cd ~'

# System
alias c='clear'
alias cls='clear'
alias h='history'
alias j='jobs -l'
alias path='echo ${PATH//:/\\n}'
alias now='date "+%Y-%m-%d %A %T %Z"'
alias reload='source ~/.zshrc'
alias please='sudo $(fc -ln -1)'
alias pathadd='export PATH="$PWD:$PATH" && echo "$PATH"'

# File ops (safe defaults)
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'
alias mkdir='mkdir -pv'
command -v trash >/dev/null 2>&1 && alias rm='trash'

# Listing (eza > lsd > ls)
if command -v eza >/dev/null 2>&1; then
    alias ls='eza -a -1 --icons --group-directories-first'
    alias l='eza -1 --icons --group-directories-first'
    alias la='eza -a -1 --icons --group-directories-first'
    alias ll='eza -l --icons --group-directories-first --no-user --no-group --no-permissions --no-filesize --time=modified --time-style="%Y-%m-%d %H:%M"'
    alias lt='eza -T --level=2 --icons --group-directories-first'
elif command -v lsd >/dev/null 2>&1; then
    alias ls='lsd -a -1 --group-dirs=first --icon=auto'
    alias l='lsd -1 --group-dirs=first --icon=auto'
    alias la='lsd -a -1 --group-dirs=first --icon=auto'
    alias ll='lsd -l --group-dirs=first --icon=auto --blocks date,name --date "+%Y-%m-%d %H:%M"'
    alias lt='lsd --tree --depth 2 --group-dirs=first --icon=auto'
else
    if [[ "$PLATFORM" == "macos" ]]; then
        alias ls='ls -GF'   # BSD ls (macOS)
    else
        alias ls='ls --color=auto -F'
    fi
    alias ll='ls -alF'
    alias la='ls -A'
    alias l='ls -1F'
    alias lt='ls -ltr'
fi
if [[ "$PLATFORM" == "macos" ]]; then
    alias dir='\ls -lahGt'           # BSD ls: -G enables colour
else
    alias dir='\ls -laht --color=auto'  # GNU ls
fi
alias tree='tree -C'

# Text/IO
alias grep='grep --color=auto --exclude-dir={.git,node_modules,vendor,build,dist}'
command -v bat >/dev/null 2>&1 && alias cat='bat'

# Archives
alias untar='tar -xvf'
alias targz='tar -czvf'

# Monitoring
alias df='df -h'
alias du='du -h'
[[ "$PLATFORM" != "macos" ]] && alias free='free -h'
alias ps='ps auxf'
alias psg='ps aux | grep'
command -v htop >/dev/null 2>&1 && alias top='htop'

# Ports (platform-aware)
if command -v netstat >/dev/null 2>&1; then
    if [[ "$PLATFORM" == "macos" ]]; then
        alias ports='netstat -anp tcp | grep LISTEN'
    else
        alias ports='netstat -tulanp'
    fi
elif command -v ss >/dev/null 2>&1; then
    alias ports='ss -tulpen'
fi

# Networking
alias ping='ping -c 5'
alias wget='wget -c'
alias serve='python3 -m http.server 8000'

# Package management (platform-aware)
case "$PLATFORM" in
    macos)
        alias install='brew install'
        alias update='brew update && brew upgrade'
        alias search='brew search'
        alias remove='brew uninstall'
        ;;
    debian|wsl)
        alias install='sudo apt install'
        alias update='sudo apt update && sudo apt full-upgrade'
        alias search='apt search'
        alias remove='sudo apt remove && sudo apt autoremove'
        ;;
    redhat)
        alias install='sudo dnf install'
        alias update='sudo dnf upgrade --refresh'
        alias search='dnf search'
        alias remove='sudo dnf remove && sudo dnf autoremove'
        ;;
    arch)
        alias install='sudo pacman -S'
        alias update='sudo pacman -Syu'
        alias search='pacman -Ss'
        alias remove='sudo pacman -R'
        ;;
esac

# Git
alias g='git'
alias gs='git status'
alias gst='git status -sb'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline'
alias gd='git diff'
alias gco='git checkout'
alias gb='git branch --all'
alias ggraph='git log --graph --decorate --oneline --all'
alias gamend='git commit --amend --no-edit'
alias gca='git commit --amend'
alias gcp='git cherry-pick'
alias gprune='git fetch --prune'
alias guncommit='git reset --soft HEAD~1'

# Docker
alias d='docker'
alias dc='docker compose'
alias dps='docker ps'
alias di='docker images'
alias dclean='docker system prune -af'
alias dcu='docker compose up -d'
alias dcd='docker compose down'
alias dcb='docker compose build'
alias dcl='docker compose logs -f'
alias dexec='docker exec -it'

# ── KEYBINDINGS ───────────────────────────────────────────────────────────────

bindkey -e  # Emacs key bindings (Ctrl+A/E/K/U etc.)

# Ctrl+F → zoxide interactive (registered after zoxide init below)
_zi_widget() { zi; zle reset-prompt; }
zle -N _zi_widget
bindkey '^F' _zi_widget

# ── PROMPT / ENHANCEMENTS ─────────────────────────────────────────────────────

export STARSHIP_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/starship/starship.toml"
# Apply Gruvbox Rainbow preset on first run (skipped if config already exists)
if [[ ! -f "$STARSHIP_CONFIG" ]] && command -v starship >/dev/null 2>&1; then
    mkdir -p "$(dirname "$STARSHIP_CONFIG")"
    starship preset gruvbox-rainbow -o "$STARSHIP_CONFIG" 2>/dev/null || true
fi
command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"
command -v zoxide  >/dev/null 2>&1 && eval "$(zoxide init zsh)"

# ── EXTERNAL ──────────────────────────────────────────────────────────────────

[[ -f "$HOME/.local/bin/env" ]] && . "$HOME/.local/bin/env"
[[ -f "$HOME/.cargo/env"     ]] && . "$HOME/.cargo/env"
[[ -f "$HOME/.deno/env"      ]] && . "$HOME/.deno/env"

# ── LOCAL OVERRIDES ───────────────────────────────────────────────────────────

# Personal settings, secrets, API tokens, and machine-specific config
[[ -f ~/.zshrc.local ]] && . ~/.zshrc.local
export PATH="$HOME/.bun/bin:$PATH"
