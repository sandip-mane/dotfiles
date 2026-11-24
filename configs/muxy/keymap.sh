#!/bin/bash
# Muxy keeps shortcuts in settings.toml next to per-Mac state, so merge only the [keymap] overrides
set -euo pipefail

KEYMAP="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/keymap.toml"
SETTINGS="$HOME/Library/Application Support/Muxy 2/settings.toml"
mkdir -p "$(dirname "$SETTINGS")"
touch "$SETTINGS"

python3 - "$KEYMAP" "$SETTINGS" <<'PY'
import re, sys

keymap_path, settings_path = sys.argv[1:]
with open(keymap_path) as f:
    overrides = dict(re.findall(r'^\s*"?([\w.-]+)"?\s*=\s*"([^"]*)"', f.read(), re.M))
with open(settings_path) as f:
    lines = f.read().splitlines()

def key_of(line):
    m = re.match(r'\s*("[^"]+"|[A-Za-z0-9_.-]+)\s*=', line)
    return m and m.group(1).strip('"')

def render(key, value):
    k = f'"{key}"' if "." in key else key
    return f'{k} = "{value}"'

start = next((i for i, l in enumerate(lines) if l.strip() == "[keymap]"), None)
if start is None:
    lines += ["", "[keymap]"]
    start = len(lines) - 1
end = next((i for i in range(start + 1, len(lines)) if lines[i].lstrip().startswith("[")), len(lines))
while end > start + 1 and not lines[end - 1].strip():
    end -= 1

pending = dict(overrides)
for i in range(start + 1, end):
    key = key_of(lines[i])
    if key in pending:
        lines[i] = render(key, pending.pop(key))
lines[end:end] = [render(k, v) for k, v in pending.items()]

with open(settings_path, "w") as f:
    f.write("\n".join(lines) + "\n")
PY

command -v muxy >/dev/null && muxy config reload >/dev/null 2>&1 || true
