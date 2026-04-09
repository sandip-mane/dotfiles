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

Sourced automatically by `.zshrc`:

| Script              | Functions                                      |
| ------------------- | ---------------------------------------------- |
| `llm.sh`            | `cldw` — Claude worktree helper                |
| `neeto_db.sh`       | `load_pg_dump` — PostgreSQL dump loader         |
| `neeto_release.sh`  | `release`, `deploy`, `release_micro`            |
| `neeto_workflow.sh` | `sendpr`, `commitlog`, `move_project_items`, `timesheet` |
| `startup.sh`        | `startup` — project startup                    |

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

## Raycast

Raycast config uses encrypted storage. Use Raycast's built-in export/import feature:
**Raycast → Settings → Advanced → Export/Import**

## Secrets

Secrets are managed via [1Password CLI](https://developer.1password.com/docs/cli/) and never committed:

```bash
export SOME_TOKEN="$(op read 'op://Vault/Item/field')"
```
