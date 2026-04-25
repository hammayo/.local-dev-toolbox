# .local-dev-toolbox

I work across macOS and WSL, switch between projects often, and set up new machines
more than I'd like. After years of rebuilding my environment by hand and carrying
scripts in my head, I collected everything into one place.

This is that place. Bash and PowerShell scripts for bootstrapping a dev environment,
managing Git repositories in bulk, configuring the shell, and keeping secrets off
the filesystem where possible.

## Repository structure

```
.local-dev-toolbox/
├── scripts/
│   ├── bash/                           Bash scripts and dotfiles (macOS · WSL · Linux)
│   │   ├── .bashrc                       Cross-platform interactive shell config
│   │   ├── .bash_profile                 Login shell entry point — sources .bashrc
│   │   ├── .zshrc                        Zsh equivalent of .bashrc
│   │   ├── .bashrc.local                 Personal overrides — gitignored, copied to ~ on bootstrap
│   │   ├── .bashrc.local.example         Template for .bashrc.local — sources ~/.secrets for creds
│   │   ├── .config/
│   │   │   └── starship/                 Starship prompt theme library
│   │   │       ├── hammy-toolbox.toml      Active default (Gruvbox Dark)
│   │   │       ├── gruvbox-rainbow.toml
│   │   │       ├── catppuccin-powerline.toml
│   │   │       ├── tokyo-night.toml
│   │   │       └── pastel-powerline.toml
│   │   ├── setup-distro.sh               Idempotent dev environment bootstrap (9 categories)
│   │   ├── _update-repos.sh              Bulk git fetch/pull — background subshell parallelism
│   │   ├── fc-rsync.sh                   rsync backup that honours .gitignore
│   │   ├── config.jsonc                  Fastfetch system info display config
│   │   └── sources.list                  APT sources for additional packages
│   │
│   ├── powershell/
│   │   ├── utils/                        Windows-side repo and release tooling
│   │   │   ├── _update-repos.ps1           Bulk git fetch/pull — RunspacePool parallelism
│   │   │   ├── git-history.ps1             Release notes from git log for a named period
│   │   │   └── fix-timestamps.ps1          Batch-update file timestamps by extension
│   │   ├── wsl/
│   │   │   └── migrate-wsl-distro.ps1      Export and re-import a WSL distro to a new path
│   │   └── sandbox/                      Windows Sandbox provisioning pipeline
│   │       ├── _sandbox-config.wsb         Sandbox XML config — maps host folder, sets logon command
│   │       ├── setup-wsb.ps1               Orchestrator — runs all phases in sequence
│   │       ├── shared-functions.ps1        Common helpers (logging, retry, PATH management)
│   │       ├── setup-winget.ps1            Install winget package manager
│   │       ├── setup-chocolatey.ps1        Install Chocolatey + custom NuGet source
│   │       ├── setup-nodejs.ps1            Install pinned Node.js version via Chocolatey
│   │       └── setup-angular.ps1           Install pinned Angular CLI via npm
│   │
│   ├── batch/                            Windows batch scripts
│   │   ├── _backup_fc-repo.bat             xcopy backup — wipes destination, full snapshot
│   │   └── .exclude.txt                    xcopy exclusion list (build artefacts, IDE dirs)
│   │
│   ├── git-hooks/                        Drop into any repo's .git/hooks/
│   │   ├── pre-commit                      Runs gitleaks against staged changes — blocks secrets
│   │   ├── commit-msg                      Prefixes commit message with ticket from branch name
│   │   └── .gitleaks.toml                  Gitleaks config and allowlist
│   │
│   └── .docs/                            Per-script documentation (mirrors script layout)
│      
└── .gitleaks.toml                        Root-level gitleaks config (symlinked from git-hooks/)
```

## Quick start

```bash
# Bootstrap a new WSL or Linux machine
bash /mnt/d/repos/.local-dev-toolbox/scripts/bash/setup-distro.sh

# Bootstrap a macOS machine
bash /volumes/data/projects/.local-dev-toolbox/scripts/bash/setup-distro.sh

# Dotfiles only — no tool installs
bash scripts/bash/setup-distro.sh --only=dotfiles

# Upgrade everything already installed
bash scripts/bash/setup-distro.sh --upgrade
```

After bootstrap: `source ~/.bashrc`

## What the bootstrap does

`setup-distro.sh` is idempotent — re-running it on an already-configured machine
skips what's already there unless you pass `--upgrade`. It works through nine
categories in dependency order:

```
dotfiles → core → cli → shell → languages → cloud → web → containers → powershell
```

The `dotfiles` category handles the shell config. There are three tiers, each
deployed differently because each has different trust requirements:

| File | Deployed as | Reason |
|------|-------------|--------|
| `.bashrc`, `.bash_profile`, `.zshrc` | Symlink | Repo edits are live immediately in every shell |
| `.bashrc.local` | Copy | Machine-specific — different on every machine |
| `.secrets` | Copy, chmod 600 | Credentials — never a symlink, never in the repo |

`.bashrc.local` sources `~/.secrets` at the top. Tokens and PATs live there, not
inline in `.bashrc.local`. If `scripts/bash/.secrets` exists locally in the toolbox
(gitignored), the bootstrap copies it automatically. Otherwise it prints a reminder
to create it:

```bash
touch ~/.secrets && chmod 600 ~/.secrets
```

## Managing repositories

Both scripts scan a root directory for repos matching a name prefix, then
fetch and pull in parallel. Default: 4 workers.

| Script | Platform | Docs |
|--------|----------|------|
| `scripts/bash/_update-repos.sh` | Linux / macOS | [docs](scripts/.docs/bash/_update-repos.md) |
| `scripts/powershell/utils/_update-repos.ps1` | Windows | [docs](scripts/.docs/powershell/_update-repos.md) |

```bash
# Bash
bash scripts/bash/_update-repos.sh --root-path ~/repos --prefix MyProject --verbose

# PowerShell
pwsh scripts/powershell/utils/_update-repos.ps1 --root-path D:\Repos --prefix MyProject --verbose
```

Both support `--skip-dirty`, `--stash-dirty`, `--use-rebase`, `--fetch-all-remotes`,
and `--parallel N`. The `--prefix` flag is effectively required — the default (`Hydra`)
matches nothing on a generic machine.

## Shell configuration

The `.bashrc` and `.zshrc` are built around two principles: no personal data in
version control, and graceful degradation when optional tools aren't installed.

`PLATFORM` is detected at startup (`macos` | `wsl` | `debian` | `redhat` | `arch`)
and available everywhere — including in `.bashrc.local`, where it drives
platform-conditional paths and aliases.

Optional tools enhance the shell but their absence doesn't break it:

| Tool | What it replaces |
|------|-----------------|
| [eza](https://github.com/eza-community/eza) | `ls` with icons and git status |
| [bat](https://github.com/sharkdp/bat) | `cat` with syntax highlighting |
| [fzf](https://github.com/junegunn/fzf) + [fd](https://github.com/sharkdp/fd) | Fuzzy file/dir/process pickers (`fe`, `fcd`, `fkill`) |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | `cd` with directory frecency (`z`, `Ctrl+F`) |
| [starship](https://starship.rs) | Shell prompt |

Starship themes live in `scripts/bash/.config/starship/`. The active theme is
`hammy-toolbox` (Gruvbox Dark), symlinked to `~/.config/starship/starship.toml`
by the bootstrap. Switch themes with:

```bash
starship-theme                # list available themes
starship-theme tokyo-night    # apply one
```

Full shell config docs: [.bashrc](scripts/.docs/bash/bashrc.md) · [.bashrc.local](scripts/.docs/bash/bashrc-local.md)

## Git hooks

Two hooks, installed manually into each repo's `.git/hooks/`:

```bash
cp scripts/git-hooks/pre-commit .git/hooks/pre-commit
cp scripts/git-hooks/commit-msg .git/hooks/commit-msg
chmod +x .git/hooks/pre-commit .git/hooks/commit-msg
```

**`pre-commit`** — runs [gitleaks](https://github.com/gitleaks/gitleaks) against
staged changes. Blocks commits containing secrets. Bypass with `SKIP_GITLEAKS=1`
if a false positive is blocking and you need to ship. Fix the allowlist afterward.
See [docs](scripts/.docs/git-hooks/pre-commit.md).

**`commit-msg`** — prefixes commit messages with the ticket number from the branch
name. `feature/4821-auth-fix` → `4821 - Your commit message`. Skips `main`,
`master`, `develop`, and merge commits.

## Utilities

| Script | Platform | Description | Docs |
|--------|----------|-------------|------|
| `scripts/powershell/utils/git-history.ps1` | Windows | Release notes from `git log` for a named period (`today`, `this_week`, `last_4_weeks`, etc.) | [docs](scripts/.docs/powershell/git-history.md) |
| `scripts/powershell/utils/fix-timestamps.ps1` | Windows | Batch-update file timestamps by extension | [docs](scripts/.docs/powershell/fix-timestamps.md) |
| `scripts/bash/fc-rsync.sh` | Linux / macOS | rsync backup that respects `.gitignore` | [docs](scripts/.docs/bash/fc-rsync.md) |
| `scripts/powershell/wsl/migrate-wsl-distro.ps1` | Windows | Export and re-import a WSL distro to a new path | [docs](scripts/.docs/powershell/wsl/migrate-wsl-distro.md) |
| `scripts/batch/_backup_fc-repo.bat` | Windows | xcopy backup, wipes destination first | — |

```bash
# Generate release notes for the last 4 weeks
pwsh scripts/powershell/utils/git-history.ps1 -Period "last_4_weeks"
```

## Windows Sandbox

`scripts/powershell/sandbox/` provisions a Windows Sandbox instance from scratch —
winget, Chocolatey, Node.js, Angular CLI. Open `_sandbox-config.wsb`, update
the `<HostFolder>` path, set Chocolatey source credentials as environment variables,
and double-click to launch. See [docs](scripts/.docs/powershell/sandbox.md).

## Notable configuration

The things you're most likely to need to change when running this on a new machine.

### Repository updater (`_update-repos.sh` / `_update-repos.ps1`)

| Setting | Default | How to change |
|---------|---------|---------------|
| Root scan path | `$HOME/repos` (Bash) · `D:\Repos` (PS) | `--root-path /your/path` |
| Repo name prefix | `Hydra` | `--prefix MyProject` — effectively required, the default matches nothing on a generic machine |
| Worker count | `4` | `--parallel N` |

### Bootstrap (`setup-distro.sh`)

Categories run in a fixed dependency order. Use `--only` or `--skip` to narrow the run:

```bash
# Skip categories you don't need
bash scripts/bash/setup-distro.sh --skip=cloud,containers,web

# Re-run a single category after a failure
bash scripts/bash/setup-distro.sh --only=languages --upgrade
```

### Shell history (`.bashrc`)

```bash
HISTSIZE=500        # commands kept in memory
HISTFILESIZE=10000  # lines written to ~/.bash_history
```

Both are defined in `.bashrc`. Override them in `.bashrc.local` if you want more.

### Toolbox path and secrets (`.bashrc.local`)

The two things you always set on a new machine:

```bash
# Platform-aware toolbox path — adjust to match where the repo lives
case "$PLATFORM" in
    macos) export DEV_TOOLBOX="/volumes/data/projects/.local-dev-toolbox/scripts/bash" ;;
    wsl)   export DEV_TOOLBOX="/mnt/d/repos/.local-dev-toolbox/scripts/bash" ;;
    *)     export DEV_TOOLBOX="$HOME/repos/.local-dev-toolbox/scripts/bash" ;;
esac

# AWS / Bedrock (only needed if using Claude Code via Bedrock)
export AWS_PROFILE="your-bedrock-profile"
export CLAUDE_CODE_USE_BEDROCK=0   # set to 1 to route through Bedrock
```

Tokens and PATs go in `~/.secrets` (chmod 600), not here. The bootstrap creates it or reminds you to.

### Git history / release notes (`git-history.ps1`)

Two environment variables configure output without touching the script:

```powershell
$env:GIT_HISTORY_REPO_PATH  = "D:\Repos\MyProject"   # repo to run against
$env:GIT_HISTORY_TICKET_URL = "https://jira.example.com/browse/"  # ticket link prefix
```

### Windows Sandbox (`setup-wsb.ps1`)

Version pins and the Chocolatey feed are environment variables, not hardcoded:

| Variable | Default     | Purpose |
|----------|-------------|---------|
| `NODE_VERSION` | `^25.0.0`   | Node.js version to install via Chocolatey |
| `ANGULAR_VERSION` | `^20.0.0`   | Angular CLI version to install via npm |
| `CHOCO_SOURCE_URL` | _(empty)_   | Private NuGet feed URL |
| `CHOCO_SOURCE_USER` | _(empty)_   | Feed credentials |
| `CHOCO_SOURCE_NAME` | `choco-dev` | Feed source name |

Set them before launching the sandbox or pass them via the `.wsb` `<Environment>` block.

## Adding a script

1. Place it under `scripts/<area>/`
2. Add a matching doc at `scripts/.docs/<area>/<script-name>.md`
3. Bash: `set -euo pipefail` and a `--help` block
4. PowerShell: `Set-StrictMode -Version Latest` and `[CmdletBinding()]`
