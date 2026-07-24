import json
import re
import sys

CLOSES = re.compile(
    r"(?i)\b(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?)\s+((?:[\w.-]+/[\w.-]+)?#\d+)"
)

p = json.load(sys.stdin)
body = p.get("body") or ""
refs = list(dict.fromkeys(CLOSES.findall(body)))

print()
print("### {}  [{}]  by @{}".format(p["url"], p["state"], p["author"]["login"]))
print("    title: {}".format(p["title"]))
print("    closes: {}".format(", ".join(refs) if refs else "(none - log the PR number)"))
for line in [l for l in body.splitlines() if l.strip()][:4]:
    print("    | {}".format(line[:160]))
