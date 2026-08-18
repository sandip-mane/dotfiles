# Drafts a commit subject from the staged diff using a local Ollama model
aic() {
  local model="${OLLAMA_COMMIT_MODEL:-gemma4:26b-mlx}"
  local prompt msg key

  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "not a git repository"
    return 1
  fi

  if ! command -v ollama >/dev/null 2>&1; then
    echo "ollama not installed — brew install ollama"
    return 1
  fi

  if ! ollama list >/dev/null 2>&1; then
    echo "ollama not running — brew services start ollama"
    return 1
  fi

  if git diff --cached --quiet; then
    echo "nothing staged — git add your changes first"
    return 1
  fi

  prompt=$(cat <<EOF
Write a git commit subject line for the staged changes below.

Rules:
- Output only the subject line and nothing else.
- One line, at most 72 characters.
- Imperative mood, sentence case, like "Add ollama commit helper".
- No conventional-commit prefix such as feat:, fix: or chore:.
- No trailing period, no surrounding quotes, no markdown.

$(git diff --cached --stat)

$(git diff --cached | head -n 400)
EOF
)

  while true; do
    echo "→ drafting from staged diff..."
    msg=$(printf '%s' "$prompt" \
      | ollama run --think=false --hidethinking "$model" 2>/dev/null \
      | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
      | grep -m 1 -v '^$')
    msg="${msg#[\"\'\`]}"
    msg="${msg%[\"\'\`]}"
    msg="${msg%.}"

    if [[ -z "$msg" ]]; then
      echo "ollama returned nothing"
      return 1
    fi

    echo "\n  $msg\n"
    read -k 1 "key?[a]ccept  [r]egenerate  [e]dit  [q]uit › "
    echo

    case "$key" in
      a) git commit -m "$msg"; return $? ;;
      e) git commit -e -m "$msg"; return $? ;;
      r) ;;
      *) echo "aborted"; return 1 ;;
    esac
  done
}
