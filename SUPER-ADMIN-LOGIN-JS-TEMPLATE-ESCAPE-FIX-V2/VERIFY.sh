#!/usr/bin/env bash
set -euo pipefail

LIVE_URL="${1:-https://tcrmmm.tamiyouz.com}"
TMP_DIR="$(mktemp -d)"
TMP_HTML="$TMP_DIR/super-admin.html"
TMP_JS="$TMP_DIR/super-admin-inline.js"
TMP_API="$TMP_DIR/login-api.json"
trap 'rm -rf "$TMP_DIR"' EXIT

printf '[VERIFY] Fetching %s/super-admin\n' "$LIVE_URL"
curl -fsS "$LIVE_URL/super-admin" -o "$TMP_HTML"

python3 - "$TMP_HTML" "$TMP_JS" <<'PY'
from pathlib import Path
import re, sys
html = Path(sys.argv[1]).read_text(encoding='utf-8', errors='replace')
broken = r"replace(//+$/,'')"
expected = r"replace(/\/+$/,'')"
if broken in html:
    raise SystemExit('live HTML still contains malformed replace(//+$/)')
if expected not in html:
    raise SystemExit("live HTML does not contain expected browser regex replace(/\\/+$/,'')")
blocks = re.findall(r'<script\b(?![^>]*\bsrc=)[^>]*>(.*?)</script>', html, flags=re.I|re.S)
inline = [b for b in blocks if b.strip()]
if not inline:
    raise SystemExit('no inline scripts found')
Path(sys.argv[2]).write_text('\n;\n'.join(inline), encoding='utf-8')
if "loginBtn" not in html or "addEventListener('click', login)" not in html:
    raise SystemExit('login button wiring not found in live HTML')
print(f'live-html-check: OK ({len(inline)} inline block(s))')
PY

node --check "$TMP_JS"
printf '[VERIFY] Live inline JavaScript syntax: OK\n'

STATUS="$(curl -sS -o "$TMP_API" -w '%{http_code}' -H 'Content-Type: application/json' -X POST "$LIVE_URL/api/super-admin/login" --data '{}')"
if [[ "$STATUS" != "400" && "$STATUS" != "401" && "$STATUS" != "429" ]]; then
  printf '[VERIFY] Unexpected login API status: %s\n' "$STATUS" >&2
  cat "$TMP_API" >&2 || true
  exit 1
fi
printf '[VERIFY] Login API reachable: HTTP %s\n' "$STATUS"
printf '[VERIFY] PASS\n'
