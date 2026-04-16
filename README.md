# dotfiles

My macOS setup, managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Fresh Machine Install

```bash
curl -fsSL https://raw.githubusercontent.com/sandip-mane/dotfiles/main/bootstrap.sh -o /tmp/bootstrap.sh && bash /tmp/bootstrap.sh
```

Or clone and run locally:

```bash
git clone https://github.com/sandip-mane/dotfiles.git ~/Work/dotfiles
cd ~/Work/dotfiles
./bootstrap.sh
```

> **Raycast import:** The bootstrap will open a Raycast import dialog. Use password: `oneringtorulethemall`

## After Bootstrap

<details>
<summary>Manual steps after bootstrap</summary>

- [ ] **Sign into 1Password** — `op account add --address domain.1password.com --email x@example.com`
- [ ] **Generate secrets** — run `refresh-secrets` to populate `~/.secrets` from 1Password
- [ ] **Remap Caps Lock to Control** — System Settings → Keyboard → Keyboard Shortcuts → Modifier Keys
- [ ] **Add Work folder to Finder sidebar** — drag `~/Work` to Favorites
- [ ] **Sync Bear notes** — run `bearin` to pull notes from GitHub into Bear; `bearout` to push the other way
- [ ] **Install [NeetoRecord](https://neetorecord.com/neetorecord/download)**

</details>

## Sync

After editing dotfiles or pulling updates:

```bash
./sync.sh
```

## What's Inside

### Dotfiles (`packages/`)

Each folder mirrors `$HOME` and is symlinked via `stow`.

| Package  | Configures                     |
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
| `claude` | Claude Code settings, MCP servers |

### App Configs

| App            | Config                          |
| -------------- | ------------------------------- |
| macOS          | `macos.sh` — sane defaults for macOS |
| VS Code        | `configs/vscode/sandip.code-profile`    |
| Raycast        | `configs/raycast/config.rayconfig`      |
| Calendr        | `configs/calendr/defaults.sh`           |
| Maccy          | `configs/maccy/defaults.sh`             |
| Mac Mouse Fix  | `configs/mac-mouse-fix/config.plist`    |

### Packages & Apps

See [`Brewfile`](Brewfile) for the full list of CLI tools, GUI apps, and Mac App Store installs.

### Shell Scripts (`scripts/`)

Sourced automatically by `.zshrc`. Organized by domain:

| Script | Command | Description |
| ------ | ------- | ----------- |
| `secrets.sh` | `refresh-secrets` | Regenerate ~/.secrets from 1Password |
| `bear.sh` | `bearin` / `bearout` | Sync Bear notes (GitHub → Bear / Bear → GitHub) |
| `ai/cldw.sh` | `cldw` | Claude worktree helper |
| `git/sendpr.sh` | `sendpr` | Create PR with issue linking |
| `git/commitlog.sh` | `commitlog` | Formatted branch commit log |
| `git/move_project_items.sh` | `move_project_items` | Bulk move GitHub project items |
| `git/bump_version.sh` | `bump_version` | Trigger a version bump PR and merge it |
| `neeto/release.sh` | `release` | Create release PR |
| `neeto/deploy.sh` | `deploy` | Merge and push release |
| `neeto/hotfix.sh` | `hotfix` | Cherry-pick hotfix release |
| `neeto/load_pg_dump.sh` | `load_pg_dump` | Restore DB dump |
| `neeto/timesheet.sh` | `timesheet` | Format timesheet entries |
| `neeto/startup.sh` | `startup` | Open dev apps |
