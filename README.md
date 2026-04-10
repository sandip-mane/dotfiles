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

> **Raycast import:** The bootstrap will open a Raycast import dialog. Use password: `12345678`

## After Bootstrap

Sign into these apps manually (use 1Password to autofill):

1. **1Password** — master password + secret key
2. **Firefox** — Firefox Sync to restore bookmarks, extensions, passwords
3. **Brave** — Brave Sync
4. **Slack** — sign in via browser
5. **GitHub Desktop** — sign in via browser
6. **Spark** — sign in to restore email and settings

Grant Accessibility permissions: **Magnet, Maccy, Raycast, Lunar**

Install manually: [NeetoRecord](https://neetorecord.com/neetorecord/download)

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

### App Configs

| App            | Config                          |
| -------------- | ------------------------------- |
| macOS          | `macos.sh` — sane defaults for macOS |
| VS Code        | `vscode/sandip.code-profile`    |
| Raycast        | `raycast/config.rayconfig`      |
| Calendr        | `calendr/defaults.sh`           |
| Maccy          | `maccy/defaults.sh`             |
| Mac Mouse Fix  | `mac-mouse-fix/config.plist`    |

### Packages & Apps

See [`Brewfile`](Brewfile) for the full list of CLI tools, GUI apps, and Mac App Store installs.

### Shell Scripts (`scripts/`)

Sourced automatically by `.zshrc`. Organized by domain:

| Script | Command | Description |
| ------ | ------- | ----------- |
| `ai/cldw.sh` | `cldw` | Claude worktree helper |
| `git/sendpr.sh` | `sendpr` | Create PR with issue linking |
| `git/commitlog.sh` | `commitlog` | Formatted branch commit log |
| `git/move_project_items.sh` | `move_project_items` | Bulk move GitHub project items |
| `neeto/release.sh` | `release` | Create release PR |
| `neeto/deploy.sh` | `deploy` | Merge and push release |
| `neeto/hotfix.sh` | `hotfix` | Cherry-pick hotfix release |
| `neeto/load_pg_dump.sh` | `load_pg_dump` | Restore DB dump |
| `neeto/timesheet.sh` | `timesheet` | Format timesheet entries |
| `neeto/startup.sh` | `startup` | Open dev apps |
