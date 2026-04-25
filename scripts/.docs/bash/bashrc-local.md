# .bashrc.local

A per-user override file for machine-specific configuration and references to secrets. Sourced at the end of `.bashrc` (and `.zshrc`) so anything defined here takes precedence.

## Overview

The shared `.bashrc` is committed to version control and contains no personal data. Settings that vary per developer — credentials, project-specific aliases, startup commands — belong in `~/.bashrc.local` instead. This file is gitignored and never shared.

## Setup

```bash
# Copy the template and fill in your values
cp scripts/bash/.bashrc.local.example ~/.bashrc.local

# Edit with your config
vim ~/.bashrc.local
```

## Secrets: Use `~/.secrets`

**Do not store tokens or passwords in `~/.bashrc.local`** — if you ever inspect or share the file you risk exposing credentials.

Instead, put all secrets in a separate `~/.secrets` file with restricted permissions, and source it from `.bashrc.local`:

```bash
# Create the secrets file
touch ~/.secrets && chmod 600 ~/.secrets

# ~/.secrets — never commit this
export GITHUB_PERSONAL_ACCESS_TOKEN="ghp_..."
export ANTHROPIC_API_KEY="sk-ant-..."
export AZURE_DEVOPS_PAT="..."
export ATLASSIAN_API_TOKEN="..."
```

`.bashrc.local` then simply sources it:

```bash
[[ -f "$HOME/.secrets" ]] && source "$HOME/.secrets"
```

This keeps `.bashrc.local` safe to inspect, grants secrets a dedicated `600`-permissioned file, and makes it easy to audit what credentials are loaded.

## What Goes in `.bashrc.local`

| Category | Examples |
|----------|---------|
| **Secret loader** | `source ~/.secrets` |
| **Cloud config** | `AWS_PROFILE`, `AWS_REGION`, `CLAUDE_CODE_USE_BEDROCK` |
| **Service config** | `AZURE_DEVOPS_ORG_URL`, `ATLASSIAN_SITE_NAME`, `ATLASSIAN_USER_EMAIL` |
| **DEV_TOOLBOX path** | Platform-aware `case` block setting `DEV_TOOLBOX` and `PATH` |
| **Personal aliases** | `cdtoolbox`, `repos`, `cdfs` — platform-aware via `$PLATFORM` |
| **Startup commands** | Platform-guarded auto-cd, `git status`, SSO login prompt |
| **Editor overrides** | `export EDITOR=nvim` if different from team default |

## Platform-Aware Paths

`PLATFORM` is set by `.bashrc` before `.bashrc.local` is sourced, so you can use it directly:

```bash
case "$PLATFORM" in
    macos) export DEV_TOOLBOX="/volumes/data/projects/.local-dev-toolbox/scripts/bash" ;;
    wsl)   export DEV_TOOLBOX="/mnt/d/repos/.local-dev-toolbox/scripts/bash" ;;
    *)     export DEV_TOOLBOX="$HOME/repos/.local-dev-toolbox/scripts/bash" ;;
esac
export PATH="$PATH:$DEV_TOOLBOX"
```

The same pattern applies to navigation aliases:

```bash
case "$PLATFORM" in
    macos)
        alias repos='cd /volumes/data/projects'
        alias cdtoolbox='cd "/volumes/data/projects/.local-dev-toolbox"'
        ;;
    wsl)
        alias repos='cd /mnt/d/repos'
        alias cdtoolbox='cd "/mnt/d/repos/.local-dev-toolbox"'
        alias cdfs='cd "/mnt/d/repos/<your-repo>"'
        ;;
    *)
        alias repos='cd "$HOME/repos"'
        alias cdtoolbox='cd "$HOME/repos/.local-dev-toolbox"'
        ;;
esac
```

## Template

A [`.bashrc.local.example`](../../../scripts/bash/.bashrc.local.example) template is provided in `scripts/bash/` with all sections pre-structured. Copy it and fill in your values.

## Security

- **Never commit `.bashrc.local`** — it is listed in `.gitignore`.
- **Never store raw tokens in `.bashrc.local`** — use `~/.secrets` (chmod 600).
- The shared `.bashrc` contains no secrets, tokens, or personal paths.
- If you rotate a token, update it in `~/.secrets` and run `reload` to pick up the change.
- The pre-commit gitleaks hook will block commits containing secrets — this is the safety net.
