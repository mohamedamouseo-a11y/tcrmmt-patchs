#!/usr/bin/env bash
set -euo pipefail

LIVE_URL="${1:-https://tcrmmm.tamiyouz.com}"
TMP_HTML="$(mktemp)"
TMP_JS="$(mktemp)"
trap 'rm -f "$TMP_HTML" "$TMP_JS"' EXIT

printf '[VERIFY] Fetching %s/super-admin\n' "$LIVE_URL"
curl -fsS "$LIVE_URL/super-admin" -o "$TMP_HTML"

python3 - "$TMP_HTML" "$TMP_JS" <<'PY'
from pathlib import Path
import re, sys
html = Path(sys.argv[1]).read_text(encoding='utf-8', errors='replace')
if r"replace(//+$/,'')" in html:
    raise SystemExit('live HTML still contains malformed replace(//+$/)')
blocks = re.findall(r'<script\b[^>]*>(.*?)</script>', html, flags=re.I|re.S)
inline = [b for b in blocks if b.strip()]
if not inline:
    raise SystemExit('no inline scripts found in /super-admin response')
Path(sys.argv[2]).write_text('\n;\n'.join(inline), encoding='utf-8')
if "loginBtn" not in html or "addEventListener('click', login)" not in html:
    raise SystemExit('expected login button wiring was not found in live HTML')
print(f'live-html-check: OK ({len(inline)} inline script block(s))')
PY

node --check "$TMP_JS"
printf '[VERIFY] Inline JavaScript syntax: OK\n'

STATUS="$(curl -sS -o /tmp/tcrmmt-superadmin-api-smoke.json -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -X POST "$LIVE_URL/api/super-admin/login" \
  --data '{}')"
if [[ "$STATUS" != "400" && "$STATUS" != "401" && "$STATUS" != "429" ]]; then
  printf '[VERIFY] Unexpected login API HTTP status: %s\n' "$STATUS" >&2
  cat /tmp/tcrmmt-superadmin-api-smoke.json >&2 || true
  exit 1
fi
printf '[VERIFY] Login API reachable: HTTP %s\n' "$STATUS"
printf '[VERIFY] PASS\n'
