refresh-secrets() {
  if ! command -v op &>/dev/null; then
    echo "1Password CLI (op) is not installed."
    return 1
  fi

  cat > ~/.secrets <<'TEMPLATE'
export GITHUB_TOKEN="PLACEHOLDER_GITHUB"
export HONEYBADGER_API_KEY="PLACEHOLDER_HONEYBADGER"
TEMPLATE

  sed -i '' "s|PLACEHOLDER_GITHUB|$(op read 'op://Employee/Github Personal Access Token/credential')|" ~/.secrets
  sed -i '' "s|PLACEHOLDER_HONEYBADGER|$(op read 'op://Shared accounts - P3/Honeybadger API key/credential')|" ~/.secrets

  chmod 600 ~/.secrets
  source ~/.secrets
  echo "Secrets refreshed and loaded."
}
