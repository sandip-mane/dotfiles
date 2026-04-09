# dotfiles

My macOS setup and dotfiles, managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Fresh Machine Install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/sandip-mane/dotfiles/main/bootstrap.sh)
```

Or clone and run locally:

```bash
git clone https://github.com/sandip-mane/dotfiles.git ~/Work/dotfiles
cd ~/Work/dotfiles
./bootstrap.sh
```

## Updating

After pulling changes or editing dotfiles:

```bash
./sync.sh
# or
make sync
```

## What's Included

### Stow Packages (`packages/`)

Each folder mirrors `$HOME` and is symlinked via `stow`.

| Package  | What it configures             |
| -------- | ------------------------------ |
| `zsh`    | `.zshrc` — shell config        |
| `p10k`   | `.p10k.zsh` — Powerlevel10k    |
| `git`    | `.gitconfig`                   |
| `vim`    | `.vimrc`                       |
| `wezterm`| `.wezterm.lua` — terminal      |
| `ssh`    | `.ssh/config`                  |
| `mise`   | mise runtime versions          |
| `gh`     | GitHub CLI config              |
| `atuin`  | shell history config           |
| `docker` | Docker client config           |

### Shell Scripts (`scripts/`)

Sourced automatically by `.zshrc`. Organized by domain:

```
scripts/
├── ai/
│   └── cldw.sh              # cldw — Claude worktree helper
├── git/
│   ├── sendpr.sh            # sendpr — create PR with issue linking
│   ├── commitlog.sh         # commitlog — formatted branch commit log
│   └── move_project_items.sh # move_project_items — bulk move GitHub project items
└── neeto/
    ├── _helpers.sh          # show_progress — shared progress display
    ├── load_pg_dump.sh      # load_pg_dump — restore DB dump
    ├── release.sh           # release — create release PR
    ├── deploy.sh            # deploy — merge and push release
    ├── release_micro.sh     # release_micro — cherry-pick micro release
    ├── timesheet.sh         # timesheet — format timesheet entries
    └── startup.sh           # startup — open dev apps
```

### Other Files

- `Brewfile` — Homebrew formulae, casks, and Mac App Store apps
- `macos.sh` — macOS system defaults
- `vscode/extensions.txt` — VS Code extensions list

## Adding a New Dotfile

1. Create a stow package: `mkdir -p packages/toolname`
2. Place the file mirroring its `$HOME` path:
   - `~/.somerc` → `packages/toolname/.somerc`
   - `~/.config/tool/config.toml` → `packages/toolname/.config/tool/config.toml`
3. Remove the original and stow: `stow -d packages -t ~ -R toolname`

## Manual Installs

These apps can't be installed via Homebrew or the Mac App Store:

| App | Download |
| --- | -------- |
| NeetoRecord | https://neetorecord.com/neetorecord/download |

## Raycast

Raycast config is stored at `raycast/config.rayconfig`. The bootstrap script opens it automatically — just confirm the import in the Raycast dialog.

To update: **Raycast → Settings → Advanced → Export** (without encryption), then replace `raycast/config.rayconfig`.

## Secrets

Secrets are managed via [1Password CLI](https://developer.1password.com/docs/cli/) and never committed:

```bash
export SOME_TOKEN="$(op read 'op://Vault/Item/field')"
```
