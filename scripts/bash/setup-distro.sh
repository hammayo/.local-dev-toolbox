#!/usr/bin/env bash
# setup-distro.sh — Cross-platform dev environment bootstrap (macOS + Debian/Ubuntu)
# Idempotent: skips tools already installed unless --upgrade is set.
set -euo pipefail

# -------------------------------------------------------------------------
# Unicode support detection
# $'\xNN' hex bytes work in bash 3.2+ but rendering requires a UTF-8 locale.
# Minimal servers / Docker containers often have LANG=C — fall back to ASCII.
_locale_is_utf8() {
    local loc="${LANG:-}${LC_ALL:-}${LC_CTYPE:-}"
    [[ "$loc" =~ [Uu][Tt][Ff]-?8 ]]
}

# Status symbols
if _locale_is_utf8; then
    SYM_SUCCESS=$'\xe2\x9c\x85'                 # ✅
    SYM_FAILED=$'\xf0\x9f\x94\xb4'              # 🔴
    SYM_SKIPPED=$'\xe2\x8f\xad\xef\xb8\x8f'     # ⏭️
    SYM_STEP=$'\xe2\x96\xb6\xef\xb8\x8f'        # ▶️
    SYM_WARNING=$'\xe2\x9a\xa0\xef\xb8\x8f'     # ⚠️
else
    SYM_SUCCESS="[OK]  "
    SYM_FAILED="[FAIL]"
    SYM_SKIPPED="[SKIP]"
    SYM_STEP="[>>]  "
    SYM_WARNING="[WARN]"
fi

# ANSI colour codes
C_RESET=$'\033[0m'
C_RED=$'\033[31m'
C_GREEN=$'\033[32m'
C_YELLOW=$'\033[33m'
C_CYAN=$'\033[36m'
C_WHITE=$'\033[37m'
C_BRIGHT_GREEN=$'\033[92m'
C_BRIGHT_CYAN=$'\033[96m'

# -------------------------------------------------------------------------
# Formatting helpers
# -------------------------------------------------------------------------

fmt() {
    local text="$1" color="${2:-white}"
    case "$color" in
        red)          printf '%s%s%s' "$C_RED"          "$text" "$C_RESET" ;;
        green)        printf '%s%s%s' "$C_GREEN"        "$text" "$C_RESET" ;;
        yellow)       printf '%s%s%s' "$C_YELLOW"       "$text" "$C_RESET" ;;
        cyan)         printf '%s%s%s' "$C_CYAN"         "$text" "$C_RESET" ;;
        bright_green) printf '%s%s%s' "$C_BRIGHT_GREEN" "$text" "$C_RESET" ;;
        bright_cyan)  printf '%s%s%s' "$C_BRIGHT_CYAN"  "$text" "$C_RESET" ;;
        *)            printf '%s%s%s' "$C_WHITE"        "$text" "$C_RESET" ;;
    esac
}

msg() {
    local text="$1" color="${2:-white}" newline="${3:-true}"
    if [[ "$newline" == "true" ]]; then
        fmt "$text" "$color"
        printf '\n'
    else
        fmt "$text" "$color"
    fi
}

warn() { printf '%sWARNING: %s%s\n' "$C_YELLOW" "$1" "$C_RESET" >&2; }
err()  { printf '%sERROR: %s%s\n'   "$C_RED"    "$1" "$C_RESET" >&2; }

step()    { msg "$SYM_STEP $1" "cyan"; }

success() {
    msg "  $SYM_SUCCESS $1" "green"
    if [[ "$1" == *"(already installed"* ]]; then
        ((COUNT_SKIPPED++)) || true
    else
        ((COUNT_INSTALLED++)) || true
    fi
}

failure() {
    msg "  $SYM_FAILED $1" "red"
    ((COUNT_FAILED++)) || true
}

skipped() {
    msg "  $SYM_SKIPPED $1" "yellow"
    ((COUNT_SKIPPED++)) || true
}

# -------------------------------------------------------------------------
# Platform detection (get_distro extended from .bashrc to include macOS)
# -------------------------------------------------------------------------

PLATFORM=""
PKG_MANAGER=""

get_distro() {
    if [[ "$(uname -s)" == "Darwin" ]]; then
        echo "macos"
        return
    fi

    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian|mint)                 echo "debian" ;;
            fedora|rhel|centos|rocky|almalinux) echo "redhat" ;;
            arch|manjaro|endeavouros)           echo "arch" ;;
            opensuse*|sles)                     echo "suse" ;;
            *)                                  echo "unknown" ;;
        esac
    else
        echo "unknown"
    fi
}

detect_platform() {
    local distro
    distro=$(get_distro)

    case "$distro" in
        macos)
            PLATFORM="macos"
            PKG_MANAGER="brew"
            # Install Homebrew if missing
            if ! command -v brew >/dev/null 2>&1; then
                step "Installing Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null)"
                success "Homebrew (installed)"
            fi
            ;;
        debian)
            PLATFORM="debian"
            PKG_MANAGER="apt"
            ;;
        *)
            err "Unsupported platform: $distro. Only macOS and Debian/Ubuntu are supported."
            exit 1
            ;;
    esac
}

# -------------------------------------------------------------------------
# Package manager abstraction
# -------------------------------------------------------------------------

# Translate package names across platforms
pkg_name() {
    local name="$1"
    if [[ "$PKG_MANAGER" == "brew" ]]; then
        case "$name" in
            build-essential)       echo "" ;;
            python3-pip)           echo "" ;;
            python3-venv)          echo "" ;;
            python3-certbot-nginx) echo "" ;;
            *)                     echo "$name" ;;
        esac
    else
        echo "$name"
    fi
}

# Install one or more packages via the detected package manager
pkg_install() {
    local resolved=()
    for name in "$@"; do
        local translated
        translated=$(pkg_name "$name")
        [[ -n "$translated" ]] && resolved+=("$translated")
    done

    [[ ${#resolved[@]} -eq 0 ]] && return 0

    if is_dry_run; then dry_step "pkg install: ${resolved[*]}"; return; fi
    case "$PKG_MANAGER" in
        brew) brew install "${resolved[@]}" ;;
        apt)  sudo apt install -y "${resolved[@]}" ;;
    esac
}

# Refresh package index
pkg_update() {
    if is_dry_run; then dry_step "update package index ($PKG_MANAGER)"; return; fi
    case "$PKG_MANAGER" in
        brew) brew update ;;
        apt)  sudo apt update ;;
    esac
}

# Upgrade specific packages
pkg_upgrade() {
    local resolved=()
    for name in "$@"; do
        local translated
        translated=$(pkg_name "$name")
        [[ -n "$translated" ]] && resolved+=("$translated")
    done

    [[ ${#resolved[@]} -eq 0 ]] && return 0

    case "$PKG_MANAGER" in
        brew) brew upgrade "${resolved[@]}" 2>/dev/null || true ;;
        apt)  sudo apt install --only-upgrade -y "${resolved[@]}" ;;
    esac
}

# Check if a command exists on PATH
cmd_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Guard: skip if command exists and --upgrade is not set
needs_install() {
    local cmd="$1"
    if cmd_exists "$cmd" && [[ "$UPGRADE" == "false" ]]; then
        return 1
    fi
    return 0
}

# Dry-run helpers
is_dry_run() { [[ "$DRY_RUN" == "true" ]]; }
dry_step()   { msg "  [DRY RUN] would: $1" "cyan"; }

# -------------------------------------------------------------------------
# Configuration
# -------------------------------------------------------------------------

ALL_CATEGORIES="dotfiles core cli shell languages cloud web containers powershell"

# Resolve DEV_TOOLBOX from this script's location
DEV_TOOLBOX="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPGRADE=false
DRY_RUN=false
ONLY_CATEGORIES=""
SKIP_CATEGORIES=""
INVALID_ARGS=()

COUNT_INSTALLED=0
COUNT_SKIPPED=0
COUNT_FAILED=0

# -------------------------------------------------------------------------
# Argument parsing
# -------------------------------------------------------------------------

show_usage() {
    cat <<'EOF'
Usage: setup-distro.sh [OPTIONS]

Cross-platform dev environment bootstrap (macOS + Debian/Ubuntu).

Options:
  --all                Install all categories (default)
  --only=<csv>         Install only these categories (e.g. --only=core,cli)
  --skip=<csv>         Skip these categories (e.g. --skip=cloud,containers)
  --upgrade            Re-install/upgrade tools even if already present
  --dry-run            Print what would be installed without making changes
  --help               Show this help message

Categories: dotfiles, core, cli, shell, languages, cloud, web, containers, powershell
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        local arg="$1"
        local name="" value=""

        # Handle --key=value syntax
        if [[ "$arg" =~ ^(--?[^=]+)=(.+)$ ]]; then
            name="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
        else
            name="$arg"
        fi

        # Normalise: strip leading dashes, lowercase
        local normalised
        normalised="$(printf '%s' "$name" | sed 's/^-*//' | tr '[:upper:]' '[:lower:]')"

        case "$normalised" in
            all)      ;;  # default behaviour, no-op
            only)
                if [[ -z "$value" ]]; then
                    if [[ $# -ge 2 ]]; then shift; value="$1"; else INVALID_ARGS+=("$arg"); shift; continue; fi
                fi
                ONLY_CATEGORIES="$value"
                ;;
            skip)
                if [[ -z "$value" ]]; then
                    if [[ $# -ge 2 ]]; then shift; value="$1"; else INVALID_ARGS+=("$arg"); shift; continue; fi
                fi
                SKIP_CATEGORIES="$value"
                ;;
            upgrade)  UPGRADE=true ;;
            dry-run)  DRY_RUN=true ;;
            help)     show_usage; exit 0 ;;
            *)        INVALID_ARGS+=("$arg") ;;
        esac
        shift
    done

    # Validate mutual exclusivity
    if [[ -n "$ONLY_CATEGORIES" && -n "$SKIP_CATEGORIES" ]]; then
        err "--only and --skip are mutually exclusive."
        exit 2
    fi
}

# Check whether a category should run
should_run_category() {
    local category="$1"

    if [[ -n "$ONLY_CATEGORIES" ]]; then
        [[ ",$ONLY_CATEGORIES," == *",$category,"* ]]
        return
    fi

    if [[ -n "$SKIP_CATEGORIES" ]]; then
        [[ ",$SKIP_CATEGORIES," != *",$category,"* ]]
        return
    fi

    return 0
}

# -------------------------------------------------------------------------
# Category: dotfiles
# -------------------------------------------------------------------------

link_dotfile() {
    local src="$1" dest="$2" name
    name="$(basename "$dest")"

    if [[ -L "$dest" && "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then
        success "$name (already linked)"
        return
    fi

    if is_dry_run; then
        dry_step "link $dest → $src"
        return
    fi

    # Back up existing file if it's not a symlink to our source
    if [[ -e "$dest" || -L "$dest" ]]; then
        mv "$dest" "${dest}.bak.$(date +%Y%m%d%H%M%S)"
        warn "$name — existing file backed up to ${dest}.bak.*"
    fi

    if ln -sf "$src" "$dest"; then
        success "$name → $src (linked)"
    else
        failure "$name (failed to link)"
    fi
}

install_dotfiles() {
    step "Linking dotfiles from DEV_TOOLBOX..."

    # Shell config
    link_dotfile "$DEV_TOOLBOX/.bashrc"        "$HOME/.bashrc"
    link_dotfile "$DEV_TOOLBOX/.bash_profile"  "$HOME/.bash_profile"
    link_dotfile "$DEV_TOOLBOX/.zshrc"         "$HOME/.zshrc"

    # Starship prompt config → ~/.config/starship/starship.toml
    # Deploys the hammy-toolbox theme as the active config; theme library stays in $DEV_TOOLBOX/.config/starship/
    mkdir -p "$HOME/.config/starship"
    link_dotfile "$DEV_TOOLBOX/.config/starship/hammy-toolbox.toml"  "$HOME/.config/starship/starship.toml"

    # Fastfetch config → ~/.config/fastfetch/config.jsonc
    mkdir -p "$HOME/.config/fastfetch"
    link_dotfile "$DEV_TOOLBOX/config.jsonc"   "$HOME/.config/fastfetch/config.jsonc"

    # Copy .bashrc.local if it exists in the toolbox (gitignored, user-specific)
    if [[ -f "$HOME/.bashrc.local" ]]; then
        success ".bashrc.local (already exists)"
    elif is_dry_run; then
        if [[ -f "$DEV_TOOLBOX/.bashrc.local" ]]; then
            dry_step "copy .bashrc.local from toolbox to $HOME/.bashrc.local"
        elif [[ -f "$DEV_TOOLBOX/.bashrc.local.example" ]]; then
            dry_step "create $HOME/.bashrc.local from .bashrc.local.example template"
        else
            skipped ".bashrc.local (skipped — no .bashrc.local or template found)"
        fi
    elif [[ -f "$DEV_TOOLBOX/.bashrc.local" ]]; then
        cp "$DEV_TOOLBOX/.bashrc.local" "$HOME/.bashrc.local"
        success ".bashrc.local (copied from toolbox)"
    elif [[ -f "$DEV_TOOLBOX/.bashrc.local.example" ]]; then
        sed "s|<SET_BY_SETUP_DISTRO>|$DEV_TOOLBOX|g" \
            "$DEV_TOOLBOX/.bashrc.local.example" > "$HOME/.bashrc.local"
        success ".bashrc.local (created from template — edit with: nano ~/.bashrc.local)"
    else
        skipped ".bashrc.local (skipped — no .bashrc.local or template found)"
    fi

    # Copy ~/.secrets if a local copy exists in the toolbox (gitignored, credentials file)
    # Never symlinked — always a plain copy so it stays local to this machine.
    if [[ -f "$HOME/.secrets" ]]; then
        success ".secrets (already exists at $HOME/.secrets)"
    elif is_dry_run; then
        if [[ -f "$DEV_TOOLBOX/.secrets" ]]; then
            dry_step "copy .secrets from toolbox to $HOME/.secrets (chmod 600)"
        else
            skipped ".secrets (skipped — create $HOME/.secrets manually with chmod 600)"
        fi
    elif [[ -f "$DEV_TOOLBOX/.secrets" ]]; then
        cp "$DEV_TOOLBOX/.secrets" "$HOME/.secrets"
        chmod 600 "$HOME/.secrets"
        success ".secrets (copied from toolbox — permissions set to 600)"
    else
        skipped ".secrets (not found in toolbox — create $HOME/.secrets manually: touch ~/.secrets && chmod 600 ~/.secrets)"
    fi

    msg "  DEV_TOOLBOX=$DEV_TOOLBOX" "cyan"
}

# -------------------------------------------------------------------------
# Category: core
# -------------------------------------------------------------------------

install_gitleaks() {
    if ! needs_install gitleaks; then
        success "gitleaks (already installed)"
        return
    fi

    local os arch url tmpdir
    os="$(uname -s)"
    arch="$(uname -m)"

    case "$os" in
        Darwin) os="darwin" ;;
        Linux)  os="linux" ;;
        *)      failure "gitleaks — unsupported OS: $os"; return ;;
    esac

    case "$arch" in
        x86_64)  arch="x64" ;;
        aarch64|arm64) arch="arm64" ;;
        *)       failure "gitleaks — unsupported arch: $arch"; return ;;
    esac

    # Fetch latest release tag from GitHub API
    local latest_tag
    latest_tag=$(curl -fsSL "https://api.github.com/repos/gitleaks/gitleaks/releases/latest" \
        | grep '"tag_name"' | head -1 | sed 's/.*"v\([^"]*\)".*/\1/')

    if [[ -z "$latest_tag" ]]; then
        failure "gitleaks — could not determine latest version"
        return
    fi

    if is_dry_run; then dry_step "install gitleaks v${latest_tag} from GitHub release"; return; fi

    url="https://github.com/gitleaks/gitleaks/releases/download/v${latest_tag}/gitleaks_${latest_tag}_${os}_${arch}.tar.gz"
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"; trap - RETURN' RETURN

    if curl -fsSL "$url" -o "${tmpdir}/gitleaks.tar.gz" && \
       tar xzf "${tmpdir}/gitleaks.tar.gz" -C "$tmpdir" && \
       sudo install -m 755 "${tmpdir}/gitleaks" /usr/local/bin/gitleaks; then
        success "gitleaks v${latest_tag} (installed)"
    else
        failure "gitleaks (failed)"
    fi
}

install_core() {
    step "Installing core tools..."

    local tools=(curl wget git unzip build-essential)
    for tool in "${tools[@]}"; do
        local cmd="$tool"
        [[ "$tool" == "build-essential" ]] && cmd="gcc"

        if ! needs_install "$cmd"; then
            success "$tool (already installed)"
            continue
        fi

        if pkg_install "$tool" 2>/dev/null; then
            success "$tool (installed)"
        else
            failure "$tool (failed)"
        fi
    done

    install_gitleaks
    install_tailscale
}

install_tailscale() {
    if ! needs_install tailscale; then
        success "tailscale (already installed)"
        return
    fi

    if [[ "$PLATFORM" == "macos" ]]; then
        if is_dry_run; then dry_step "brew install --cask tailscale"; return; fi
        if brew install --cask tailscale 2>/dev/null; then
            success "tailscale (installed)"
        else
            failure "tailscale (failed)"
        fi
        return
    fi

    # Linux: official install script
    if is_dry_run; then dry_step "install tailscale via tailscale.com/install.sh"; return; fi
    if curl -fsSL https://tailscale.com/install.sh | sh >/dev/null 2>&1; then
        success "tailscale (installed)"
    else
        failure "tailscale (failed)"
    fi
}

# -------------------------------------------------------------------------
# Category: cli
# -------------------------------------------------------------------------

install_cli() {
    step "Installing CLI tools..."

    local tools=(bat ripgrep fzf zoxide fastfetch htop gh)
    for tool in "${tools[@]}"; do
        local cmd="$tool"
        [[ "$tool" == "ripgrep" ]] && cmd="rg"
        [[ "$tool" == "bat" && "$PLATFORM" == "debian" ]] && cmd="batcat"

        if ! needs_install "$cmd"; then
            success "$tool (already installed)"
            continue
        fi

        if pkg_install "$tool" 2>/dev/null; then
            success "$tool (installed)"
        elif [[ "$tool" == "fastfetch" && "$PLATFORM" == "debian" ]]; then
            _install_fastfetch_deb
        elif [[ "$tool" == "gh" && "$PLATFORM" == "debian" ]]; then
            _install_gh_deb
        else
            failure "$tool (failed)"
        fi
    done
}

# fastfetch fallback: download .deb from GitHub releases (not in Ubuntu repos pre-24.04)
_install_fastfetch_deb() {
    local arch latest_tag
    arch=$(uname -m)
    [[ "$arch" == "x86_64" ]] && arch="amd64"
    latest_tag=$(curl -fsSL "https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest" \
        | grep '"tag_name"' | head -1 | sed 's/.*"\([^"]*\)".*/\1/')
    if [[ -z "$latest_tag" ]]; then
        failure "fastfetch (failed)"
        return
    fi
    if is_dry_run; then dry_step "install fastfetch ${latest_tag} from GitHub release (.deb)"; return; fi
    local tmpdir
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"; trap - RETURN' RETURN
    if curl -fsSL "https://github.com/fastfetch-cli/fastfetch/releases/download/${latest_tag}/fastfetch-linux-${arch}.deb" \
           -o "${tmpdir}/fastfetch.deb" \
        && sudo dpkg -i "${tmpdir}/fastfetch.deb" >/dev/null 2>&1; then
        success "fastfetch (installed)"
    else
        failure "fastfetch (failed)"
    fi
}

# gh fallback: add official GitHub CLI apt repo (not in default Ubuntu/Debian repos)
_install_gh_deb() {
    if is_dry_run; then dry_step "add GitHub CLI apt repo and apt install gh"; return; fi
    local keyring="/usr/share/keyrings/githubcli-archive-keyring.gpg"
    local list="/etc/apt/sources.list.d/github-cli.list"

    if curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
           | sudo dd of="$keyring" 2>/dev/null \
        && sudo chmod go+r "$keyring" \
        && echo "deb [arch=$(dpkg --print-architecture) signed-by=${keyring}] https://cli.github.com/packages stable main" \
           | sudo tee "$list" >/dev/null \
        && sudo apt update >/dev/null 2>&1 \
        && sudo apt install -y gh >/dev/null 2>&1; then
        success "gh (installed)"
    else
        failure "gh (failed)"
    fi
}

# -------------------------------------------------------------------------
# Category: shell
# -------------------------------------------------------------------------

install_nerd_font() {
    local font_name="FiraCode"
    local font_dir

    if [[ "$PLATFORM" == "macos" ]]; then
        if brew list --cask "font-fira-code-nerd-font" >/dev/null 2>&1 && [[ "$UPGRADE" == "false" ]]; then
            success "Nerd Font $font_name (already installed)"
            return
        fi

        if brew install --cask "font-fira-code-nerd-font" 2>/dev/null; then
            success "Nerd Font $font_name (installed)"
        else
            failure "Nerd Font $font_name (failed)"
        fi
        return
    fi

    # Linux: download to ~/.local/share/fonts
    font_dir="$HOME/.local/share/fonts/NerdFonts"
    if [[ -d "$font_dir" && "$(ls -A "$font_dir" 2>/dev/null)" ]] && [[ "$UPGRADE" == "false" ]]; then
        success "Nerd Font $font_name (already installed)"
        return
    fi

    local tmpdir latest_tag url
    latest_tag=$(curl -fsSL "https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest" \
        | grep '"tag_name"' | head -1 | sed 's/.*"\([^"]*\)".*/\1/')

    if [[ -z "$latest_tag" ]]; then
        failure "Nerd Font $font_name — could not determine latest version"
        return
    fi

    if is_dry_run; then dry_step "install Nerd Font $font_name $latest_tag from GitHub release"; return; fi

    url="https://github.com/ryanoasis/nerd-fonts/releases/download/${latest_tag}/${font_name}.zip"
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"; trap - RETURN' RETURN

    if curl -fsSL "$url" -o "${tmpdir}/${font_name}.zip"; then
        mkdir -p "$font_dir"
        unzip -o "${tmpdir}/${font_name}.zip" -d "$font_dir" >/dev/null
        fc-cache -f "$font_dir" 2>/dev/null || true
        success "Nerd Font $font_name $latest_tag (installed)"
    else
        failure "Nerd Font $font_name (failed)"
    fi
}

install_shell() {
    step "Installing shell enhancements..."

    # Starship prompt
    if ! needs_install starship; then
        success "starship (already installed)"
    elif is_dry_run; then
        dry_step "install starship via starship.rs/install.sh"
    else
        if curl -fsSL https://starship.rs/install.sh | sh -s -- -y >/dev/null 2>&1; then
            success "starship (installed)"
        else
            failure "starship (failed)"
        fi
    fi

    # Nerd Font
    install_nerd_font
}

# -------------------------------------------------------------------------
# Category: languages
# -------------------------------------------------------------------------

install_languages() {
    step "Installing language runtimes..."

    # NVM + Node LTS
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
    if [[ -s "$NVM_DIR/nvm.sh" ]] && [[ "$UPGRADE" == "false" ]]; then
        success "nvm (already installed)"
    elif is_dry_run; then
        dry_step "install nvm via nvm-sh/nvm install script"
    else
        local nvm_version
        nvm_version=$(curl -fsSL "https://api.github.com/repos/nvm-sh/nvm/releases/latest" \
            | grep '"tag_name"' | head -1 | sed 's/.*"\([^"]*\)".*/\1/')
        nvm_version="${nvm_version:-master}"
        if curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${nvm_version}/install.sh" | bash >/dev/null 2>&1; then
            success "nvm (installed)"
        else
            failure "nvm (failed)"
        fi
    fi

    # Source nvm so we can install node
    [[ -s "$NVM_DIR/nvm.sh" ]] && \. "$NVM_DIR/nvm.sh"

    if cmd_exists node && [[ "$UPGRADE" == "false" ]]; then
        success "node LTS (already installed — $(node --version))"
    elif is_dry_run; then
        dry_step "nvm install --lts"
    else
        if cmd_exists nvm; then
            if nvm install --lts >/dev/null 2>&1; then
                success "node LTS (installed — $(node --version))"
            else
                failure "node LTS (failed)"
            fi
        else
            skipped "node LTS (skipped — nvm not available)"
        fi
    fi

    # Python3 + pip
    if cmd_exists python3 && [[ "$UPGRADE" == "false" ]]; then
        success "python3 (already installed — $(python3 --version))"
    else
        if pkg_install python3 python3-pip python3-venv 2>/dev/null; then
            success "python3 + pip (installed)"
        else
            failure "python3 (failed)"
        fi
    fi
}

# -------------------------------------------------------------------------
# Category: cloud
# -------------------------------------------------------------------------

install_awscli() {
    if ! needs_install aws; then
        success "aws-cli (already installed)"
        return
    fi

    if [[ "$PLATFORM" == "macos" ]]; then
        if pkg_install awscli 2>/dev/null; then
            success "aws-cli (installed)"
        else
            failure "aws-cli (failed)"
        fi
        return
    fi

    # Linux: official installer
    if is_dry_run; then dry_step "install aws-cli v2 via awscli.amazonaws.com installer"; return; fi
    local tmpdir
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"; trap - RETURN' RETURN

    if curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o "${tmpdir}/awscliv2.zip" && \
       unzip -o "${tmpdir}/awscliv2.zip" -d "$tmpdir" >/dev/null && \
       sudo "${tmpdir}/aws/install" --update >/dev/null 2>&1; then
        success "aws-cli v2 (installed)"
    else
        failure "aws-cli (failed)"
    fi
}

install_azure_cli() {
    if ! needs_install az; then
        success "azure-cli (already installed)"
        return
    fi

    if [[ "$PLATFORM" == "macos" ]]; then
        if pkg_install azure-cli 2>/dev/null; then
            success "azure-cli (installed)"
        else
            failure "azure-cli (failed)"
        fi
        return
    fi

    # Linux: Microsoft install script
    if is_dry_run; then dry_step "install azure-cli via aka.ms/InstallAzureCLIDeb"; return; fi
    if curl -fsSL https://aka.ms/InstallAzureCLIDeb | sudo bash >/dev/null 2>&1; then
        success "azure-cli (installed)"
    else
        failure "azure-cli (failed)"
    fi
}

install_wrangler() {
    if ! needs_install wrangler; then
        success "wrangler (already installed)"
        return
    fi

    if ! cmd_exists npm; then
        skipped "wrangler (skipped — npm not available, install languages category first)"
        return
    fi

    if is_dry_run; then dry_step "npm install -g wrangler"; return; fi
    if npm install -g wrangler >/dev/null 2>&1; then
        success "wrangler (installed)"
    else
        failure "wrangler (failed)"
    fi
}

install_cloud() {
    step "Installing cloud CLIs..."
    install_awscli
    install_azure_cli
    install_wrangler
}

# -------------------------------------------------------------------------
# Category: web
# -------------------------------------------------------------------------

install_web() {
    step "Installing web server tools..."

    # nginx
    if ! needs_install nginx; then
        success "nginx (already installed)"
    else
        if pkg_install nginx 2>/dev/null; then
            success "nginx (installed)"
        else
            failure "nginx (failed)"
        fi
    fi

    # certbot
    if ! needs_install certbot; then
        success "certbot (already installed)"
    else
        if [[ "$PLATFORM" == "debian" ]]; then
            if pkg_install certbot python3-certbot-nginx 2>/dev/null; then
                success "certbot (installed)"
            else
                failure "certbot (failed)"
            fi
        else
            if pkg_install certbot 2>/dev/null; then
                success "certbot (installed)"
            else
                failure "certbot (failed)"
            fi
        fi
    fi

    # mkcert
    if ! needs_install mkcert; then
        success "mkcert (already installed)"
    else
        if pkg_install mkcert 2>/dev/null; then
            success "mkcert (installed)"
        else
            failure "mkcert (failed)"
        fi
    fi
}

# -------------------------------------------------------------------------
# Category: containers
# -------------------------------------------------------------------------

install_containers() {
    step "Installing container tools..."

    if ! needs_install docker; then
        success "docker (already installed)"
        return
    fi

    if [[ "$PLATFORM" == "macos" ]]; then
        if is_dry_run; then dry_step "brew install --cask docker"; return; fi
        if brew install --cask docker 2>/dev/null; then
            success "docker desktop (installed)"
        else
            failure "docker (failed)"
        fi
        return
    fi

    # Linux: official install script
    if is_dry_run; then dry_step "install docker via get.docker.com + add $USER to docker group"; return; fi
    if curl -fsSL https://get.docker.com | sudo sh >/dev/null 2>&1; then
        # Add current user to docker group
        sudo usermod -aG docker "$USER" 2>/dev/null || true
        success "docker + compose (installed — log out and back in for group changes)"
    else
        failure "docker (failed)"
    fi
}

# -------------------------------------------------------------------------
# Category: powershell
# -------------------------------------------------------------------------

install_powershell() {
    step "Installing PowerShell..."

    if ! needs_install pwsh; then
        success "powershell (already installed)"
        return
    fi

    if [[ "$PLATFORM" == "macos" ]]; then
        if is_dry_run; then dry_step "brew install --cask powershell"; return; fi
        if brew install --cask powershell >/dev/null 2>&1; then
            success "powershell (installed)"
        else
            skipped "powershell (skipped — cask unavailable; install manually: brew install --cask powershell)"
        fi
        return
    fi

    local arch
    arch=$(dpkg --print-architecture 2>/dev/null || uname -m)

    # On non-amd64 (e.g. arm64/Apple Silicon VM) the Microsoft apt repo only
    # provides amd64 packages; use snap instead.
    if [[ "$arch" != "amd64" ]]; then
        if is_dry_run; then dry_step "snap install powershell --classic"; return; fi
        if ! cmd_exists snap; then
            sudo apt install -y snapd >/dev/null 2>&1 || true
        fi
        if sudo snap install powershell --classic 2>/dev/null; then
            success "powershell (installed)"
        else
            failure "powershell (failed)"
        fi
        return
    fi

    if is_dry_run; then dry_step "register Microsoft apt repo and apt install powershell"; return; fi
    # amd64: register Microsoft package repo then install via apt
    if ! [[ -f /etc/apt/sources.list.d/microsoft-prod.list ]] && \
       ! [[ -f /etc/apt/sources.list.d/microsoft.list ]]; then
        local release_id release_version deb_url
        . /etc/os-release
        release_id="${ID}"
        release_version="${VERSION_ID}"

        # Use Ubuntu repo for Ubuntu, Debian repo for Debian
        deb_url="https://packages.microsoft.com/config/${release_id}/${release_version}/packages-microsoft-prod.deb"

        local tmpdir
        tmpdir=$(mktemp -d)
        trap 'rm -rf "$tmpdir"; trap - RETURN' RETURN
        if curl -fsSL "$deb_url" -o "${tmpdir}/packages-microsoft-prod.deb"; then
            sudo dpkg -i "${tmpdir}/packages-microsoft-prod.deb" >/dev/null 2>&1
            sudo apt update >/dev/null 2>&1
        fi
    fi

    if sudo apt install -y powershell 2>/dev/null; then
        success "powershell (installed)"
    else
        failure "powershell (failed)"
    fi
}

# -------------------------------------------------------------------------
# Main
# -------------------------------------------------------------------------

main() {
    detect_platform
    msg "Platform: $PLATFORM ($PKG_MANAGER)" "bright_cyan"
    if is_dry_run; then
        msg "[DRY RUN] No changes will be made." "yellow"
    fi
    printf '\n'

    # Update package index
    step "Updating package index..."
    pkg_update >/dev/null 2>&1
    if ! is_dry_run; then success "Package index updated"; fi
    printf '\n'

    # Run categories in dependency order
    local categories=(dotfiles core cli shell languages cloud web containers powershell)
    local ran=0

    for category in "${categories[@]}"; do
        if should_run_category "$category"; then
            "install_${category}"
            printf '\n'
            ((ran++)) || true
        fi
    done

    if [[ $ran -eq 0 ]]; then
        warn "No categories selected. Run with --help for usage."
        exit 0
    fi

    # Summary
    printf '\n'
    msg "Summary:" "bright_cyan"
    msg "  Installed: $COUNT_INSTALLED" "green"
    msg "  Skipped:   $COUNT_SKIPPED" "yellow"
    msg "  Failed:    $COUNT_FAILED" "red"
    printf '\n'

    if is_dry_run; then
        msg "$SYM_SUCCESS Dry run complete — no changes were made." "bright_green"
    elif [[ $COUNT_FAILED -gt 0 ]]; then
        msg "$SYM_WARNING Setup completed with $COUNT_FAILED failure(s)." "yellow"
    else
        msg "$SYM_SUCCESS Setup complete." "bright_green"
    fi
}

# -------------------------------------------------------------------------
# Entry point
# -------------------------------------------------------------------------

parse_args "$@"

if [[ ${#INVALID_ARGS[@]} -gt 0 ]]; then
    msg "Unrecognised option(s):" "red"
    for arg in "${INVALID_ARGS[@]}"; do
        msg "  $arg" "red"
    done
    show_usage
    exit 2
fi

main
