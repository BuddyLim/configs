#!/usr/bin/env bash
set -euo pipefail

if [ ! -f ".worktree-ports" ]; then
    echo "No .worktree-ports found. Run ./dev-backend.sh first."
    exit 1
fi

# shellcheck source=/dev/null
source .worktree-ports

# Guard: bail if already running
if [ -n "${FRONTEND_PID:-}" ] && kill -0 "$FRONTEND_PID" 2>/dev/null; then
    echo "Frontend already running (PID $FRONTEND_PID). Run ./dev-stop.sh first."
    exit 1
fi

# Start Vite from the frontend directory; log goes to repo root
cd frontend
BACKEND_PORT=$BACKEND_PORT bun run dev --port "$FRONTEND_PORT" > ../.frontend.log 2>&1 &
FRONTEND_PID=$!
cd ..

# Write updated ports file with frontend PID
cat > .worktree-ports <<EOF
WORKTREE_NAME=${WORKTREE_NAME}
BACKEND_PORT=${BACKEND_PORT}
FRONTEND_PORT=${FRONTEND_PORT}
BACKEND_PID=${BACKEND_PID}
FRONTEND_PID=${FRONTEND_PID}
EOF

echo "Starting frontend (PID ${FRONTEND_PID})..."

# Poll until Vite prints the local URL
TIMEOUT=30
ELAPSED=0
while ! grep -q "Local:" .frontend.log 2>/dev/null; do
    sleep 1
    ELAPSED=$((ELAPSED + 1))
    if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
        echo "Frontend did not start within ${TIMEOUT}s. Check .frontend.log"
        exit 1
    fi
    if ! kill -0 "$FRONTEND_PID" 2>/dev/null; then
        echo "Frontend process died unexpectedly. Check .frontend.log"
        exit 1
    fi
done

echo "[smartfi/${WORKTREE_NAME}] frontend → http://localhost:${FRONTEND_PORT} (proxying to :${BACKEND_PORT})"
