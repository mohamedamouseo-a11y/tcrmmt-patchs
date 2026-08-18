#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-/var/www/TCRMMT}"
PM2_NAME="${PM2_NAME:-tamiyouz-crm}"
LIVE_URL="${LIVE_URL:-https://tcrmmm.tamiyouz.com}"
PATCH_NAME="SUPER-ADMIN-LOGIN-JS-PARSE-FIX-V1"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="/tmp/${PATCH_NAME}-${STAMP}"

log() { printf '[%s] %s\n' "$PATCH_NAME" "$*"; }
fail() { printf '[%s] ERROR: %s\n' "$PATCH_NAME" "$*" >&2; exit 1; }

[[ -d "$ROOT" ]] || fail "Project directory not found: $ROOT"
cd "$ROOT"

[[ -f package.json ]] || fail "package.json not found in $ROOT"
[[ -f server/_core/index.ts ]] || fail "server/_core/index.ts not found"
command -v node >/dev/null 2>&1 || fail "node is required"
command -v npm >/dev/null 2>&1 || fail "npm is required"
command -v pm2 >/dev/null 2>&1 || fail "pm2 is required"
command -v python3 >/dev/null 2>&1 || fail "python3 is required"
command -v curl >/dev/null 2>&1 || fail "curl is required"

mkdir -p "$BACKUP_DIR"
log "Recording current deployment state in $BACKUP_DIR"
(git status --short || true) > "$BACKUP_DIR/git-status-before.txt"
(git rev-parse HEAD || true) > "$BACKUP_DIR/git-head-before.txt"
(pm2 describe "$PM2_NAME" || true) > "$BACKUP_DIR/pm2-before.txt"
if [[ -f dist/index.js ]]; then
  cp -a dist/index.js "$BACKUP_DIR/index.js.before"
fi

log "Checking corrected source expression before build"
python3 - <<'PY'
from pathlib import Path
p = Path('server/_core/index.ts')
s = p.read_text(encoding='utf-8')
correct = r"replace(/\/+$/,'')"
broken = r"replace(//+$/,'')"
if broken in s:
    raise SystemExit('Source still contains malformed regex: replace(//+$/)')
if correct not in s:
    raise SystemExit("Expected corrected source expression replace(/\\/+$/,'') was not found; stop rather than patch unknown source")
print('source-check: OK')
PY

log "Building from the existing source tree (no git pull/reset, no DB migration)"
npm run build

[[ -f dist/index.js ]] || fail "Build completed without dist/index.js"

log "Checking generated bundle syntax"
node --check dist/index.js

log "Rejecting the known malformed generated regex"
python3 - <<'PY'
from pathlib import Path
s = Path('dist/index.js').read_text(encoding='utf-8')
if r"replace(//+$/,'')" in s:
    raise SystemExit('Build still contains malformed replace(//+$/); refusing PM2 reload')
print('bundle-regex-check: OK')
PY

log "Reloading PM2 process $PM2_NAME"
pm2 reload "$PM2_NAME"

log "Running post-deploy verification"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/VERIFY.sh" "$LIVE_URL"

log "Patch applied successfully"
log "Backup/state snapshot: $BACKUP_DIR"
