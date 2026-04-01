# git-history.ps1

Generates formatted release notes from Git commit history for a specified time period. The output doubles as a source for WTS timesheet entries.

## Table of Contents

- [Overview](#overview)
- [Requirements](#requirements)
- [Usage](#usage)
- [Parameters](#parameters)
- [Supported Periods](#supported-periods)
- [How It Works](#how-it-works)
  - [Commit Parsing](#commit-parsing)
  - [Message Cleanup](#message-cleanup)
  - [Author Initials](#author-initials)
- [Output Format](#output-format)
- [Functions](#functions)
- [Examples](#examples)

## Overview

`git-history.ps1` reads the Git log of a repository, extracts ticket numbers and commit messages, normalises the formatting, and produces a Markdown document with clickable Azure DevOps ticket links and a chronological commit history.

## Requirements

- **PowerShell** 5.1 or later
- **Git** CLI installed and on PATH
- The repository must use commit messages prefixed with a ticket number (e.g. `#12345: Fix bug` or `12345 Add feature`)

## Usage

```powershell
# Last 4 weeks of the current directory
.\git-history.ps1

# Specific repository and period
.\git-history.ps1 -RepositoryPath "D:\Repos\MyProject" -Period "this_week"

# With clickable Azure DevOps ticket links
.\git-history.ps1 -TicketBaseUrl "https://dev.azure.com/myorg/myproject/_workitems/edit/"

# Set ticket URL via environment variable
$env:GIT_HISTORY_TICKET_URL = "https://dev.azure.com/myorg/myproject/_workitems/edit/"
.\git-history.ps1

# Current month, output to file instead of console
.\git-history.ps1 -Period "current_month" -OutputToConsole:$false
```

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `RepositoryPath` | string | Current directory (or `GIT_HISTORY_REPO_PATH` env) | Path to the Git repository to scan |
| `Period` | string | `last_4_weeks` | Time period for commit history (see below) |
| `TicketBaseUrl` | string | `""` (or `GIT_HISTORY_TICKET_URL` env) | Base URL for ticket hyperlinks, e.g. `https://dev.azure.com/myorg/myproject/_workitems/edit/`. When empty, tickets are rendered as plain `#N` instead of links |
| `OutputToConsole` | switch | `$true` | When `$true`, prints to console. When `$false`, writes to a `.md` file in the repo root |

## Supported Periods

| Period | Date Range |
|--------|-----------|
| `today` | Start of today to now |
| `this_week` | Monday of the current week to now |
| `last_week` | Previous Monday to previous Sunday |
| `current_month` | 1st of the current month to now |
| `last_month` | 1st of the previous month to 1st of the current month |
| `last_4_weeks` | 28 days ago to now (default) |

## How It Works

### Commit Parsing

The script runs `git log` with `--pretty="%ad|%an|%B"` (author date, author name, full message body) and `--no-merges` to skip merge commits. Each line is split on `|` to extract the three fields.

### Message Cleanup

Commit messages go through several normalisation steps in `Format-CommitMessage`:

1. Messages starting with `-` get a leading space to prevent Markdown list interpretation.
2. Dash-space (`- `) separators are collapsed.
3. Truncated at the first semicolon or ` and ` — keeps the primary action only.
4. Trailing semicolons, periods, and duplicate periods are stripped.
5. The first word is proper-cased (uppercase first letter, lowercase rest), preserving any leading ticket-number prefix.

### Author Initials

`Get-AuthorInitials` extracts initials from the author name:
- Two-word names (e.g. `Jane Smith`) produce `JS`.
- Single-word names produce the first letter uppercased.

## Output Format

The generated Markdown has two sections:

**Ticket Links** — deduplicated, sorted list of ticket numbers. When `-TicketBaseUrl` (or `GIT_HISTORY_TICKET_URL`) is set, each entry is a clickable hyperlink; otherwise it renders as plain text:

```markdown
## Ticket Links
- [12345](https://dev.azure.com/myorg/myproject/_workitems/edit/12345)
- [12346](https://dev.azure.com/myorg/myproject/_workitems/edit/12346)
```

**Commit History** — chronological list with date, author initials, ticket number, and cleaned message:

```
## MyProject History
----------------------------------------------------------------
202603 09 14:30:15 | HB | - #12345: Fix authentication jwt token expiration.
202603 09 11:22:30 | HB | - #12346: Add new user validation.
```

When `OutputToConsole` is `$false`, the output is written to `<RepoName>-release-notes.md` in the repository root.

## Functions

| Function | Description |
|----------|-------------|
| `Get-DateRange` | Calculate start and end dates from a named period string |
| `Test-GitRepository` | Validate that a path is a Git working tree |
| `Get-CommitData` | Run `git log`, parse entries, return structured commit objects |
| `Format-CommitMessage` | Clean and normalise a raw commit message |
| `Get-AuthorInitials` | Extract author initials from a full name |
| `Parse-CommitDate` | Parse an ISO date string with timezone offset |

## Examples

### Console Output (default)

```powershell
.\git-history.ps1 -RepositoryPath "D:\Repos\MyProject" -Period "current_month"
```

Prints the release notes directly to the terminal.

### File Output

```powershell
.\git-history.ps1 -OutputToConsole:$false
# Creates: <RepositoryPath>\<RepoName>-release-notes.md
```

### Sample Output

```markdown
# MyProject Release Notes

## Ticket Links
- [12345](https://dev.azure.com/myorg/myproject/_workitems/edit/12345)
- [12346](https://dev.azure.com/myorg/myproject/_workitems/edit/12346)

## MyProject History
----------------------------------------------------------------
202603 09 14:30:15 | HB | - #12345: Fix authentication jwt token expiration.
202603 09 11:22:30 | HB | - #12346: Add new user validation.
```
