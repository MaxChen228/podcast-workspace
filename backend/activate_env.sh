#!/bin/bash
# 激活虛擬環境的便捷腳本

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export PODCAST_ENV_PATH="$SCRIPT_DIR/.venv"

# 如果直接執行這個腳本，啟動一個新的 shell
if [ "$0" = "${BASH_SOURCE[0]}" ]; then
    echo "✅ 已設置環境變量 PODCAST_ENV_PATH"
    echo "📂 虛擬環境: $PODCAST_ENV_PATH"
    echo ""
    echo "現在可以運行："
    echo "  uvicorn server.app.main:app --reload"
    echo "CLI 內容生產工具請改到 ../storytelling-cli/ 執行 ./run.sh"
    echo ""
    exec bash
fi
