#!/usr/bin/env bash
set -euo pipefail

# Returns the first port >= $1 that is not already listening
find_free_port() {
    local port=$1
    while lsof -i "tcp:$port" -sTCP:LISTEN -t >/dev/null 2>&1; do
        port=$((port + 1))
    done
    echo "$port"
}

WORKTREE_NAME=$(basename "$PWD")
HASH=$(echo -n "$WORKTREE_NAME" | cksum | awk '{print $1}')
BACKEND_PORT=$(find_free_port $(( HASH % 900 + 8100 )))
FRONTEND_PORT=$(find_free_port $(( HASH % 900 + 5100 )))

# Guard: bail if already running
if [ -f ".worktree-ports" ]; then
    EXISTING_PID=$(grep "^BACKEND_PID=" .worktree-ports | cut -d= -f2)
    if [ -n "$EXISTING_PID" ] && kill -0 "$EXISTING_PID" 2>/dev/null; then
        echo "Backend already running (PID $EXISTING_PID). Run ./dev-stop.sh first."
        exit 1
    fi
fi

# Start compose in background, capture PID
export COMPOSE_PROJECT_NAME="smartfi-${WORKTREE_NAME}"
export WORKTREE_NAME
export BACKEND_PORT
docker compose up > .backend.log 2>&1 &
BACKEND_PID=$!

# Write ports file — FRONTEND_PID left empty for dev-frontend.sh to fill
cat > .worktree-ports <<EOF
WORKTREE_NAME=${WORKTREE_NAME}
BACKEND_PORT=${BACKEND_PORT}
FRONTEND_PORT=${FRONTEND_PORT}
BACKEND_PID=${BACKEND_PID}
FRONTEND_PID=
EOF

echo "Starting backend (PID ${BACKEND_PID})..."

# Poll until FastAPI signals startup complete
TIMEOUT=60
ELAPSED=0
while ! grep -q "Application startup complete" .backend.log 2>/dev/null; do
    sleep 1
    ELAPSED=$((ELAPSED + 1))
    if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
        echo "Backend did not start within ${TIMEOUT}s. Check .backend.log"
        exit 1
    fi
    if ! kill -0 "$BACKEND_PID" 2>/dev/null; then
        echo "Backend process died unexpectedly. Check .backend.log"
        exit 1
    fi
done

echo "[smartfi/${WORKTREE_NAME}] backend → http://localhost:${BACKEND_PORT}"
