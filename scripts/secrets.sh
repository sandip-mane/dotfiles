refresh-secrets() {
  local ref="${1:-op://Private/Dev Secrets/notesPlain}"
  local account="${OP_SECRETS_ACCOUNT:-neetozone.1password.com}"

  if ! command -v op &>/dev/null; then
    echo "1Password CLI (op) is not installed."
    return 1
  fi

  local content
  content=$(op read --account "$account" "$ref") || {
    echo "Failed to read $ref from 1Password."
    return 1
  }

  # Never let a partial or unexpected read clobber a working ~/.secrets.
  if ! grep -qE '^[[:space:]]*export[[:space:]]+[A-Za-z_][A-Za-z0-9_]*=' <<<"$content"; then
    echo "$ref has no 'export VAR=...' lines; leaving ~/.secrets untouched."
    return 1
  fi

  [ -f ~/.secrets ] && cp ~/.secrets ~/.secrets.bak && chmod 600 ~/.secrets.bak

  local tmp
  tmp=$(mktemp "${TMPDIR:-/tmp}/secrets.XXXXXX") || return 1
  chmod 600 "$tmp"
  printf '%s\n' "$content" > "$tmp"
  mv "$tmp" ~/.secrets
  chmod 600 ~/.secrets

  source ~/.secrets
  echo "Secrets refreshed from $ref ($(grep -cE '^[[:space:]]*export[[:space:]]+[A-Za-z_]' ~/.secrets) vars loaded)."
}
