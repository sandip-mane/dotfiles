refresh-secrets() {
  if ! command -v op &>/dev/null; then
    echo "1Password CLI (op) is not installed."
    return 1
  fi

  # Create ~/.secrets if it doesn't exist
  touch ~/.secrets
  chmod 600 ~/.secrets

  _update_secret() {
    local var="$1" op_ref="$2"
    local value
    value=$(op read "$op_ref" 2>/dev/null) || { echo "  Failed to read $var from 1Password"; return 1; }
    if grep -q "^export $var=" ~/.secrets 2>/dev/null; then
      sed -i '' "s|^export $var=.*|export $var=\"$value\"|" ~/.secrets
    else
      echo "export $var=\"$value\"" >> ~/.secrets
    fi
  }

  # Claude MCP servers
  _update_secret GITHUB_TOKEN "op://Employee/Github Personal Access Token/credential"
  _update_secret HONEYBADGER_API_KEY "op://Shared accounts - P3/Honeybadger API key/credential"

  source ~/.secrets
  echo "Secrets refreshed and loaded."
}
