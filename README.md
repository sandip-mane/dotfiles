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

## Sync Changes

After editing dotfiles or pulling updates:

```bash
./sync.sh
```

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

## Updating Raycast Config

**Raycast → Settings → Advanced → Export** (without encryption), then replace `raycast/config.rayconfig`.

<details>
<summary>Stow Packages</summary>

Each folder in `packages/` mirrors `$HOME` and is symlinked via `stow`.

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

</details>

<details>
<summary>Homebrew Packages</summary>

**CLI tools:** aria2, atuin, defaultbrowser, fzf, gh, imagemagick, libyaml, mas, mise, node, opensearch, postgresql@18, redis, stow, tunnelto, zsh

**GUI apps:** 1Password, 1Password CLI, Brave Browser, Calendr, Claude, Claude Code, CleanShot, Docker Desktop, Firefox, Fira Code font, GitHub Desktop, HTTPie Desktop, Lunar, Mac Mouse Fix, Maccy, Notion, Numi, Raycast, Spark, Slack, WezTerm, WhatsApp, Zoom

**Mac App Store:** 1Password for Safari, Amphetamine, Bear, Magnet

</details>

<details>
<summary>Shell Scripts</summary>

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
    ├── hotfix.sh            # hotfix — cherry-pick hotfix release
    ├── timesheet.sh         # timesheet — format timesheet entries
    └── startup.sh           # startup — open dev apps
```

</details>

<details>
<summary>App Configs</summary>

These app preferences are applied automatically during bootstrap:

| App            | Config                          |
| -------------- | ------------------------------- |
| VS Code        | `vscode/sandip.code-profile`    |
| Raycast        | `raycast/config.rayconfig`      |
| Calendr        | `calendr/defaults.sh`           |
| Maccy          | `maccy/defaults.sh`             |
| Mac Mouse Fix  | `mac-mouse-fix/config.plist`    |
| macOS          | `macos.sh`                      |

</details>
