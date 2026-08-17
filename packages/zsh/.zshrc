# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
  z
)

# Alias j as z for autojump
ZSHZ_CMD="j"

source $ZSH/oh-my-zsh.sh

[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# Load secrets (API keys, tokens)
[[ -f ~/.secrets ]] && source ~/.secrets

# Stop word deletion/motion at punctuation, like a text editor
WORDCHARS=''

# Opt+left/right moves by word (Esc+arrow and xterm modified-arrow forms)
bindkey '^[^[[D' backward-word
bindkey '^[^[[C' forward-word
bindkey '^[[1;3D' backward-word
bindkey '^[[1;3C' forward-word

# Cmd+backspace (iTerm2 sends ^U) deletes to line start, like a text editor
bindkey '^U' backward-kill-line

# Aliases
alias bi="bundle install"
alias b="bundle exec"
alias t="rails test"
alias gap="git add -p"
alias repo="gh repo view --web"
alias launch="./bin/launch"
alias setup="./bin/setup"
# Ensure Teleport (NeetoDeploy VPN) login, only when not already active
_nd_ensure_login() {
  tsh status &>/dev/null || tsh login --proxy=teleport.neetodeploy.com:443 --auth=github
}
nd() { _nd_ensure_login && neetodeploy "$@"; }
alias gitclean="git branch | grep -v \* | xargs git branch -D"
alias mec="ga . && git commit -m 'Minor enhancement' && ggpnp"
export DOTFILES="${$(readlink -f ~/.zshrc):h:h:h}"
alias dotsync="$DOTFILES/sync.sh"

# Load all scripts from dotfiles repo. Executables are standalone programs,
# not function libraries: sourcing them would run them in the interactive shell.
for script in $DOTFILES/scripts/**/*.sh; do
  [ -e "$script" ] && [ ! -x "$script" ] && source "$script"
done

# Init packages
eval "$(atuin init zsh --disable-up-arrow)"

# Skip Gatekeeper quarantine for Homebrew cask installs
export HOMEBREW_CASK_OPTS="--no-quarantine"

# PATH
export PATH="/opt/homebrew/opt/postgresql@18/bin:$PATH"
export PATH="$HOME/.local/share/mise/installs/node/22.13.1/lib/node_modules/corepack/shims:$PATH"
export PATH="$HOME/.local/bin:$PATH"

# mise setup (must run after other PATH modifications).
# Use --shims so the shims dir stays first in PATH: this keeps `mise exec`
# and binstubs (#!/usr/bin/env ruby) resolving mise's ruby instead of system
# ruby. Do NOT add `mise hook-env` here — it prepends tool install dirs that
# shadow the shims and trip mise's "tool paths not first" warning.
eval "$(mise activate zsh --shims)"
