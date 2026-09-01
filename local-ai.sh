#!/bin/bash
set -euo pipefail

# Opt-in local models. Not called from bootstrap.sh or sync.sh: they need more
# memory than every Mac here has.

MODEL="${OLLAMA_COMMIT_MODEL:-gemma4:26b-mlx}"
MIN_RAM_GB=32

if ! command -v brew &>/dev/null; then
  echo "Homebrew is required — run ./bootstrap.sh first."
  exit 1
fi

RAM_GB=$(($(sysctl -n hw.memsize) / 1024 / 1024 / 1024))
if [ "$RAM_GB" -lt "$MIN_RAM_GB" ]; then
  echo "This Mac has ${RAM_GB} GB of RAM; ${MODEL} wants at least ${MIN_RAM_GB} GB."
  read -r -p "Install anyway? [y/N] " reply
  case "$reply" in
    [Yy]*) ;;
    *) echo "Skipped."; exit 1 ;;
  esac
fi

if ! brew list --formula ollama &>/dev/null; then
  echo "Installing ollama..."
  brew install ollama
fi

echo "Starting the ollama service..."
brew services start ollama

for _ in $(seq 1 30); do
  ollama list &>/dev/null && break
  sleep 1
done

if ! ollama list &>/dev/null; then
  echo "ollama is not answering — check: brew services info ollama"
  exit 1
fi

if ollama list | awk 'NR > 1 { print $1 }' | grep -qx "$MODEL"; then
  echo "${MODEL} already pulled."
else
  echo "Pulling ${MODEL}..."
  ollama pull "$MODEL"
fi

echo ""
echo "AI setup complete. 'aic' now drafts commit messages from the staged diff."
