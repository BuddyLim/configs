#!/usr/bin/env bash
# No set -e: cleanup steps are expected to be no-ops (dead process, port not in use)
# and should not abort the rest of teardown.

# Load ports or derive fallback if .worktree-ports was never written
if [ -f ".worktree-ports" ]; then
    # shellcheck source=/dev/null
    source .worktree-ports
else
    echo "No .worktree-ports found — deriving ports from directory name."
    WORKTREE_NAME=$(basename "$PWD")
    HASH=$(echo -n "$WORKTREE_NAME" | cksum | awk '{print $1}')
    BACKEND_PORT=$(( HASH % 900 + 8100 ))
    FRONTEND_PORT=$(( HASH % 900 + 5100 ))
    BACKEND_PID=
    FRONTEND_PID=
fi

# Stop frontend — try PID first, fall back to killing by port
if [ -n "${FRONTEND_PID:-}" ] && kill -0 "$FRONTEND_PID" 2>/dev/null; then
    echo "Stopping frontend (PID ${FRONTEND_PID})..."
    kill "$FRONTEND_PID" || true
else
    LSOF_PID=$(lsof -t -i "tcp:${FRONTEND_PORT}" 2>/dev/null || true)
    if [ -n "$LSOF_PID" ]; then
        echo "Stopping frontend on port ${FRONTEND_PORT}..."
        kill $LSOF_PID || true
    else
        echo "Frontend not running."
    fi
fi

# Stop backend — down -v removes containers AND the named venv volume
echo "Stopping backend containers..."
export COMPOSE_PROJECT_NAME="smartfi-${WORKTREE_NAME}"
export WORKTREE_NAME
export BACKEND_PORT
docker compose down -v || true

# Remove runtime files
rm -f .worktree-ports .backend.log .frontend.log
echo "Cleaned up runtime files."

# Optional: remove the worktree
printf "Remove this worktree? [y/N] "
read -r ANSWER
if [ "${ANSWER}" = "y" ] || [ "${ANSWER}" = "Y" ]; then
    WORKTREE_PATH=$(pwd)

    # Abort if there are uncommitted changes
    if ! git diff --quiet || ! git diff --cached --quiet; then
        echo "Worktree has uncommitted changes. Aborting removal."
        exit 1
    fi

    # In a worktree, git-common-dir returns an absolute path like /path/to/main/.git
    # In the main repo, it returns the relative string ".git"
    COMMON_DIR=$(git rev-parse --git-common-dir)
    if [ "$COMMON_DIR" = ".git" ]; then
        echo "This is the main worktree — cannot remove it."
        exit 0
    fi
    MAIN_REPO="${COMMON_DIR%/.git}"

    git -C "$MAIN_REPO" worktree remove "$WORKTREE_PATH"
    echo "Worktree removed."
fi
