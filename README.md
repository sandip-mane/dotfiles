# dotfiles

My macOS setup, managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Fresh Machine Install

```bash
curl -fsSL https://raw.githubusercontent.com/sandip-mane/dotfiles/main/bootstrap.sh -o /tmp/bootstrap.sh && bash /tmp/bootstrap.sh
```

Or clone and run locally:

```bash
git clone https://github.com/sandip-mane/dotfiles.git ~/Work/sandip-mane/dotfiles
cd ~/Work/sandip-mane/dotfiles
./bootstrap.sh
```

> **Raycast import:** The bootstrap will open a Raycast import dialog. Use password: `oneringtorulethemall`

## After Bootstrap

<details>
<summary>Manual steps after bootstrap</summary>

- [ ] **Sign into 1Password** — `op account add --address domain.1password.com --email x@example.com`
- [ ] **Generate secrets** — run `refresh-secrets` to overwrite `~/.secrets` with the "Dev Secrets" note (`op://Private/Dev Secrets/notesPlain` on the `neetozone` account)
- [ ] **Remap Caps Lock to Control** — System Settings → Keyboard → Keyboard Shortcuts → Modifier Keys
- [ ] **Add Work folder to Finder sidebar** — drag `~/Work` to Favorites
- [ ] **Sync Bear notes** — run `bearin` to pull notes from GitHub into Bear; `bearout` to push the other way
- [ ] **Install [NeetoRecord](https://neetorecord.com/neetorecord/download)**
- [ ] **Grafana MCP** — the `grafana-deploy` / `grafana-ci` entries in `.mcp.json` run `mcp/grafana` via Docker, read-only; their `GRAFANA_URL_*` / `GRAFANA_SAT_*` vars come from `refresh-secrets`

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
| `ssh`    | `.ssh/config`                  |
| `mise`   | mise runtime versions          |
| `gh`     | GitHub CLI config              |
| `atuin`  | shell history config           |
| `docker` | Docker client config           |
| `claude` | Claude Code `CLAUDE.md`, skills, MCP servers |

### Claude Settings

Claude Code rewrites `~/.claude/settings.json` at runtime — `/config` toggles,
`model`, plugin state — and other apps inject hooks into it, so it can't be a
stow symlink: those writes would land in this public repo. `claude-settings.sh`
generates it from `configs/claude/settings.base.json` instead, carrying over the
runtime-owned `autoMode` key, and runs from both `bootstrap.sh` and `sync.sh`.

### App Configs

| App            | Config                          |
| -------------- | ------------------------------- |
| macOS          | `macos.sh` — sane defaults for macOS |
| Raycast        | `configs/raycast/config.rayconfig`      |
| Calendr        | `configs/calendr/defaults.sh`           |
| Maccy          | `configs/maccy/defaults.sh`             |
| Mac Mouse Fix  | `configs/mac-mouse-fix/config.plist`    |
| iTerm2         | `configs/iterm2/Default.json`           |
| cmux           | `configs/cmux/` — `cmux.json` (settings + shortcuts), `ghostty.conf` (terminal) |

### Packages & Apps

See [`Brewfile`](Brewfile) for the full list of CLI tools, GUI apps, and Mac App Store installs.

### Fast Downloads

Use [`aria2`](https://aria2.github.io/) to download a file over 16 parallel connections:

```bash
aria2c -x 16 -s 16 {LINK}
```

### Shell Scripts (`scripts/`)

Sourced automatically by `.zshrc`. Organized by domain:

| Script | Command | Description |
| ------ | ------- | ----------- |
| `secrets.sh` | `refresh-secrets` | Rewrite ~/.secrets from a 1Password note (`refresh-secrets "op://Vault/Item/field"` to use another) |
| `bear.sh` | `bearin` / `bearout` | Sync Bear notes (GitHub → Bear / Bear → GitHub) |
| `git/sendpr.sh` | `sendpr` | Create PR with issue linking |
| `git/commitlog.sh` | `commitlog` | Formatted branch commit log |
| `git/aicommit.sh` | `aic` | Draft a commit message from the staged diff with a local Ollama model |
| `git/move_project_items.sh` | `move_project_items` | Bulk move GitHub project items |
| `git/project_columns.sh` | `create_project_column` / `move_project_column` / `set_project_column_color` / `create_next_milestone` / `deprecate_old_milestone` | Manage GitHub project Status columns |
| `git/bump_version.sh` | `bump_version` | Trigger a version bump PR and merge it |
| `neeto/release.sh` | `release` | Create release PR |
| `neeto/deploy.sh` | `deploy` | Merge and push release |
| `neeto/hotfix.sh` | `hotfix` | Cherry-pick hotfix release |
| `neeto/load_pg_dump.sh` | `load_pg_dump` | Restore DB dump |
| `neeto/timesheet.sh` | `timesheet` | Format timesheet entries |
| `neeto/startup.sh` | `startup` | Open dev apps |
