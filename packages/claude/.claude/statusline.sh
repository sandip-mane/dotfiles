#!/bin/bash
set -f

input=$(cat)

if [ -z "$input" ]; then
    printf "Claude"
    exit 0
fi

# ── Colors ──────────────────────────────────────────────
blue='\033[38;2;0;153;255m'
orange='\033[38;2;255;176;85m'
green='\033[38;2;0;175;80m'
red='\033[38;2;255;85;85m'
yellow='\033[38;2;230;200;0m'
dim='\033[2m'
reset='\033[0m'

sep=" ${dim}│${reset} "

color_for_pct() {
    local pct=$1
    if [ "$pct" -ge 90 ]; then printf "$red"
    elif [ "$pct" -ge 70 ]; then printf "$yellow"
    elif [ "$pct" -ge 50 ]; then printf "$orange"
    else printf "$green"
    fi
}

# ── Model (strip trailing "(... context)" suffix) ──────
model_name=$(echo "$input" | jq -r '.model.display_name // "Claude"' | sed 's/ *([^)]*context)$//')

# ── Usage % (5-hour rolling quota) ─────────────────────
usage_pct=""

stdin_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
if [ -n "$stdin_pct" ]; then
    usage_pct=$(printf "%.0f" "$stdin_pct")
fi

if [ -z "$usage_pct" ]; then
    cache_file="/tmp/claude/statusline-usage-cache.json"
    cache_max_age=60
    mkdir -p /tmp/claude

    needs_refresh=true
    if [ -f "$cache_file" ]; then
        cache_mtime=$(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null)
        now=$(date +%s)
        if [ $(( now - cache_mtime )) -lt "$cache_max_age" ]; then
            needs_refresh=false
        fi
    fi

    if $needs_refresh; then
        token=""
        if [ -n "$CLAUDE_CODE_OAUTH_TOKEN" ]; then
            token="$CLAUDE_CODE_OAUTH_TOKEN"
        elif command -v security >/dev/null 2>&1; then
            blob=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
            [ -n "$blob" ] && token=$(echo "$blob" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
        fi
        if [ -z "$token" ] || [ "$token" = "null" ]; then
            creds_file="${HOME}/.claude/.credentials.json"
            [ -f "$creds_file" ] && token=$(jq -r '.claudeAiOauth.accessToken // empty' "$creds_file" 2>/dev/null)
        fi

        if [ -n "$token" ] && [ "$token" != "null" ]; then
            response=$(curl -s --max-time 5 \
                -H "Accept: application/json" \
                -H "Content-Type: application/json" \
                -H "Authorization: Bearer $token" \
                -H "anthropic-beta: oauth-2025-04-20" \
                -H "User-Agent: claude-code/2.1.34" \
                "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)
            if [ -n "$response" ] && echo "$response" | jq -e '.five_hour' >/dev/null 2>&1; then
                echo "$response" > "$cache_file"
            fi
        fi
    fi

    if [ -f "$cache_file" ]; then
        usage_data=$(cat "$cache_file" 2>/dev/null)
        if [ -n "$usage_data" ] && echo "$usage_data" | jq -e . >/dev/null 2>&1; then
            usage_pct=$(echo "$usage_data" | jq -r '.five_hour.utilization // 0' | awk '{printf "%.0f", $1}')
        fi
    fi
fi

[ -z "$usage_pct" ] && usage_pct=0
pct_color=$(color_for_pct "$usage_pct")

# ── Git branch ─────────────────────────────────────────
cwd=$(echo "$input" | jq -r '.cwd // ""')
[ -z "$cwd" ] || [ "$cwd" = "null" ] && cwd=$(pwd)

git_branch=""
if git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)
fi

# ── Output: Model │ ✻ pct% │ branch ────────────────────
line="${blue}${model_name}${reset}"
line+="${sep}${pct_color}✻ ${usage_pct}%${reset}"
if [ -n "$git_branch" ]; then
    line+="${sep}${green}${git_branch}${reset}"
fi

printf "%b" "$line"
exit 0
