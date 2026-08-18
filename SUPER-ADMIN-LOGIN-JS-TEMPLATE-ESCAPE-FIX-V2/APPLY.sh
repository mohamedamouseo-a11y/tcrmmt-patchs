#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-/var/www/TCRMMT}"
PM2_NAME="${PM2_NAME:-tamiyouz-crm}"
LIVE_URL="${LIVE_URL:-https://tcrmmm.tamiyouz.com}"
PATCH_NAME="SUPER-ADMIN-LOGIN-JS-TEMPLATE-ESCAPE-FIX-V2"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="/tmp/${PATCH_NAME}-${STAMP}"

log() { printf '[%s] %s\n' "$PATCH_NAME" "$*"; }
fail() { printf '[%s] ERROR: %s\n' "$PATCH_NAME" "$*" >&2; exit 1; }

[[ -d "$ROOT" ]] || fail "Project directory not found: $ROOT"
cd "$ROOT"
[[ -f package.json ]] || fail "package.json not found"
[[ -f server/_core/index.ts ]] || fail "server/_core/index.ts not found"
command -v python3 >/dev/null 2>&1 || fail "python3 is required"
command -v npm >/dev/null 2>&1 || fail "npm is required"
command -v node >/dev/null 2>&1 || fail "node is required"
command -v pm2 >/dev/null 2>&1 || fail "pm2 is required"
command -v curl >/dev/null 2>&1 || fail "curl is required"

mkdir -p "$BACKUP_DIR"
cp -a server/_core/index.ts "$BACKUP_DIR/index.ts.before"
[[ -f dist/index.js ]] && cp -a dist/index.js "$BACKUP_DIR/index.js.before"
(git status --short || true) > "$BACKUP_DIR/git-status-before.txt"
(git rev-parse HEAD || true) > "$BACKUP_DIR/git-head-before.txt"
(pm2 describe "$PM2_NAME" || true) > "$BACKUP_DIR/pm2-before.txt"

log "Applying the exact template-literal escape correction"
python3 - <<'PY'
from pathlib import Path
p = Path('server/_core/index.ts')
s = p.read_text(encoding='utf-8')
old = r"replace(/\/+$/,'')"
new = r"replace(/\\/+$/,'')"
old_count = s.count(old)
new_count = s.count(new)
if old_count != 1:
    raise SystemExit(f'Expected exactly 1 old template occurrence, found {old_count}; refusing ambiguous edit')
if new_count != 0:
    raise SystemExit(f'Corrected template occurrence already exists {new_count} time(s); refusing mixed state')
p.write_text(s.replace(old, new, 1), encoding='utf-8')
check = p.read_text(encoding='utf-8')
if check.count(new) != 1:
    raise SystemExit('Post-edit source verification failed')
print('source-edit: OK — one exact template escape corrected')
PY

log "Building from current working tree"
npm run build
[[ -f dist/index.js ]] || fail "Build did not produce dist/index.js"

log "Checking generated server bundle syntax"
node --check dist/index.js

log "Checking generated bundle contains browser-safe escaped regex"
python3 - <<'PY'
from pathlib import Path
s = Path('dist/index.js').read_text(encoding='utf-8')
broken = r"replace(//+$/,'')"
expected = r"replace(/\/+$/,'')"
if broken in s:
    raise SystemExit('Generated bundle still contains malformed replace(//+$/); refusing PM2 reload')
if expected not in s:
    raise SystemExit("Generated bundle does not contain expected browser-safe replace(/\\/+$/,''); refusing PM2 reload")
print('bundle-template-check: OK')
PY

log "Reloading PM2 process $PM2_NAME"
pm2 reload "$PM2_NAME"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log "Running live verification"
"$SCRIPT_DIR/VERIFY.sh" "$LIVE_URL"

log "PASS"
log "Backup/state snapshot: $BACKUP_DIR"
