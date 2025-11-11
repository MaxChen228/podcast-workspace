#!/bin/bash
# 快速啟動 podcast worker (捲佇列、執行 generate_podcast pipeline)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
DEFAULT_VENV="$REPO_ROOT/.venv"
VENV_PATH="${PODCAST_ENV_PATH:-$DEFAULT_VENV}"
PYTHON_BIN="$VENV_PATH/bin/python"

DOTENV_FILE="$REPO_ROOT/.env"
if [ -f "$DOTENV_FILE" ]; then
    set -a
    # shellcheck disable=SC2046
    export $(grep -v '^#' "$DOTENV_FILE" | xargs)
    set +a
fi

if [ ! -x "$PYTHON_BIN" ]; then
    echo "⚠️  找不到虛擬環境：$VENV_PATH" >&2
    echo "請先建立 .venv 並安裝 requirements/server.txt" >&2
    exit 1
fi

LOG_LEVEL="${PODCAST_WORKER_LOG_LEVEL:-INFO}"

cd "$REPO_ROOT"
exec "$PYTHON_BIN" -m server.app.workers.podcast_job_worker --log-level "$LOG_LEVEL"
