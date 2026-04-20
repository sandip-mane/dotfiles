# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="$HOME/.oh-my-zsh"

# Set Oh My Zsh theme conditionally
if [[ "$TERM_PROGRAM" == "vscode" ]]; then
  ZSH_THEME=""  # Disable Powerlevel10k for VS Code / Cursor
else
  ZSH_THEME="powerlevel10k/powerlevel10k"
fi

plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
  z
)

# Alias j as z for autojump
ZSHZ_CMD="j"

source $ZSH/oh-my-zsh.sh

# Use a minimal prompt in VS Code / Cursor to avoid command detection issues
if [[ "$TERM_PROGRAM" == "vscode" ]]; then
  PROMPT='%n@%m:%~%# '
  RPROMPT=''
else
  [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
fi

# Load secrets (API keys, tokens)
[[ -f ~/.secrets ]] && source ~/.secrets

# Aliases
alias bi="bundle install"
alias b="bundle exec"
alias t="rails test"
alias gap="git add -p"
alias repo="gh repo view --web"
alias ndlogs="neetodeploy logs"
alias ndshell="neetodeploy exec"
alias gitclean="git branch | grep -v \* | xargs git branch -D"
alias mec="ga . && git commit -m 'Minor enhancement' && ggpnp"
alias dotsync="~/Work/dotfiles/sync.sh"

# Load all scripts from dotfiles repo
for script in ~/Work/dotfiles/scripts/**/*.sh; do
  [ -e "$script" ] && source "$script"
done

# Init packages
eval "$(atuin init zsh --disable-up-arrow)"

# Skip Gatekeeper quarantine for Homebrew cask installs
export HOMEBREW_CASK_OPTS="--no-quarantine"

# PATH
export PATH="/opt/homebrew/opt/postgresql@18/bin:$PATH"
export PATH="$HOME/.local/share/mise/installs/node/22.13.1/lib/node_modules/corepack/shims:$PATH"
export PATH="$HOME/.local/bin:$PATH"

# For claude to refer to ruby from mise and not system ruby
export PATH="$HOME/.local/share/mise/shims:$PATH"

# mise setup (fast, compatible with Powerlevel10k)
eval "$(mise activate zsh --shims)"
source <(mise hook-env)
