#!/usr/bin/env bash
# SessionStart hook — prepend the user's cognitive profile to Claude's context.
# Fails silently (returns empty output) so a Mengram outage never blocks
# Claude Code from starting.
set -u

# Credentials: env var → ~/.mengram/config.json → give up silently.
# sed (not python3) for the config parse: on Windows Git Bash, python3 can be
# the Microsoft Store stub that passes `command -v` but can't run (issue #55).
KEY="${MENGRAM_API_KEY:-}"
BASE="${MENGRAM_URL:-}"
CFG="$HOME/.mengram/config.json"
if [ -f "$CFG" ]; then
  [ -z "$KEY" ] && KEY=$(sed -n 's/.*"api_key"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$CFG" | head -1)
  [ -z "$BASE" ] && BASE=$(sed -n 's/.*"base_url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$CFG" | head -1)
fi
BASE="${BASE:-https://mengram.io}"
if [ -z "$KEY" ]; then
  exit 0  # no key configured; behave like the plugin isn't installed
fi

URL="${BASE%/}/v1/profile"

# 5-second budget — anything slower delays session start more than the value
# of the profile is worth on a cold open.
RESPONSE=$(curl -fsS --max-time 5 \
  -H "Authorization: Bearer $KEY" \
  -H "User-Agent: mengram-plugin/0.1.0" \
  "$URL" 2>/dev/null) || exit 0

# Profile is JSON. Use jq if available, otherwise a REAL python3/python —
# probe with an actual import, not `command -v` (Windows Store stub).
SUMMARY=""
if command -v jq >/dev/null 2>&1; then
  SUMMARY=$(printf '%s' "$RESPONSE" | jq -r '.summary // empty' 2>/dev/null)
else
  for PY in python3 python; do
    if "$PY" -c "import json" >/dev/null 2>&1; then
      SUMMARY=$(printf '%s' "$RESPONSE" | "$PY" -c 'import json,sys
try: print(json.loads(sys.stdin.read()).get("summary",""))
except: pass' 2>/dev/null)
      break
    fi
  done
fi

if [ -n "$SUMMARY" ]; then
  echo "[Mengram memory — what you remember about this user]"
  echo "$SUMMARY"
fi
