#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
APP_DIR="$ROOT_DIR/apps/web"

if [[ ! -d "$APP_DIR" ]]; then
  echo "[web.sh] 找不到 apps/web，請先建立前端專案" >&2
  exit 1
fi

cd "$APP_DIR"

if [[ ! -d node_modules ]]; then
  echo "[web.sh] 第一次執行，安裝依賴..."
  npm install
fi

if [[ ! -f .env.local && -f .env.example ]]; then
  echo "[web.sh] 偵測到缺少 .env.local，將以 .env.example 建立"
  cp .env.example .env.local
  echo "[web.sh] 已建立 .env.local，請視需要編輯 VITE_API_BASE_URL"
fi

echo "[web.sh] 啟動 Vite 開發伺服器 (Ctrl+C 結束)"
npm run dev
