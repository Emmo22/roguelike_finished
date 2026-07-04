#!/bin/bash
set -e

SERVER="root@141.13.99.203"
REMOTE_DIR="/opt/roguelike"
BACKUP_DIR="/opt/roguelike-backups"
LOCAL_DIR="$(dirname "$0")/server"

# Pick a working local python
PY=$(command -v python3 || command -v python || true)

rollback() {
    echo "Available backups:"
    ssh "$SERVER" "ls -1t $BACKUP_DIR"
    echo ""
    read -rp "Enter backup name to restore: " BACKUP
    restore_backup "$BACKUP"
    echo "Rolled back to $BACKUP"
    exit 0
}

restore_backup() {
    local BACKUP="$1"
    ssh "$SERVER" "
        systemctl stop roguelike
        rm -rf $REMOTE_DIR
        cp -r $BACKUP_DIR/$BACKUP $REMOTE_DIR
        systemctl start roguelike
        systemctl status roguelike --no-pager
    "
}

validate() {
    echo "Validating local version..."

    # 1. Python syntax check on all .py files
    if [ -z "$PY" ]; then
        echo "ERROR: no local python found to syntax-check the server."
        exit 1
    fi
    if ! "$PY" -m py_compile "$LOCAL_DIR"/*.py; then
        echo "ERROR: Python syntax errors found. Aborting deploy."
        exit 1
    fi

    # 2. Required game files must exist
    for f in index.html index.js index.wasm index.pck; do
        if [ ! -f "$LOCAL_DIR/game/$f" ]; then
            echo "ERROR: missing game/$f. Aborting deploy."
            exit 1
        fi
    done

    echo "Validation passed."
}

smoke_test() {
    echo "Running smoke test..."
    # Hit the Flask app directly on the server. Each line must return HTTP 200.
    local RESULT
    RESULT=$(ssh "$SERVER" '
        sleep 2
        ROOT=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8000/)
        GAME=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8000/get_game)
        WASM=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8000/index.wasm)
        echo "$ROOT $GAME $WASM"
    ')
    echo "  /  /get_game  /index.wasm  ->  $RESULT"
    for code in $RESULT; do
        if [ "$code" != "200" ]; then
            return 1
        fi
    done
    return 0
}

if [ "$1" == "rollback" ]; then
    rollback
fi

# --- Generate version.js for cache-busting (current unix timestamp) ---
BUILD_VERSION=$(date +%s)
echo "Stamping build version $BUILD_VERSION..."
echo "// Auto-generated on each deploy. Holds the build timestamp used for cache-busting.
window.APP_VERSION = \"$BUILD_VERSION\";" > "$LOCAL_DIR/game/version.js"

# --- Pre-upload validation ---
validate

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

echo "Creating backup $TIMESTAMP..."
ssh "$SERVER" "
    mkdir -p $BACKUP_DIR
    cp -r $REMOTE_DIR $BACKUP_DIR/$TIMESTAMP
    ls -1t $BACKUP_DIR | tail -n +6 | xargs -I{} rm -rf $BACKUP_DIR/{}
"

echo "Uploading files..."
if command -v rsync >/dev/null 2>&1; then
    # Fast incremental sync (only changed files), removes deleted files too.
    rsync -avz --delete \
      --exclude "*.pyc" \
      --exclude "__pycache__" \
      "$LOCAL_DIR/" "$SERVER:$REMOTE_DIR/"
else
    # Fallback for environments without rsync (e.g. Git Bash on Windows):
    # stream a compressed tar over ssh. Transfers everything, no incremental.
    echo "(rsync not found — using tar over ssh)"
    tar czf - --exclude "*.pyc" --exclude "__pycache__" -C "$LOCAL_DIR" . \
      | ssh "$SERVER" "tar xzf - -C $REMOTE_DIR"
fi

echo "Restarting server..."
ssh "$SERVER" "systemctl restart roguelike"

# --- Post-deploy smoke test, auto-rollback on failure ---
if smoke_test; then
    echo "Smoke test passed."
    echo "Done! Game is live at https://dungeon-delver.wiai-lab.de/"
else
    echo "SMOKE TEST FAILED — rolling back to $TIMESTAMP..."
    restore_backup "$TIMESTAMP"
    echo "Rolled back. The bad version was NOT left running."
    exit 1
fi

echo "To rollback manually: bash deploy.sh rollback"
