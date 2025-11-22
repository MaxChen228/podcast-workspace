# Storytelling Web Client

React + Vite 前端，提供書城（瀏覽後端書籍）與書庫（本地收藏）功能。

## 快速開始

```bash
cd apps/web
cp .env.example .env.local # 調整 VITE_API_BASE_URL
npm install                # 或 pnpm / yarn
npm run dev                # http://localhost:5173
```

## 可用腳本

| 指令 | 說明 |
| --- | --- |
| `npm run dev` | 啟動 Vite 開發伺服器 |
| `npm run build` | TypeScript 檢查並建立 production bundle |
| `npm run preview` | 使用 build 輸出啟動預覽伺服器 |
| `npm run test:unit` | 以 Vitest 執行單元測試 |
| `npm run test:e2e` | 以 Playwright 執行端對端測試（需先 `npm run dev` 另啟伺服器） |

## 功能摘要
- Server Settings：自訂後端 URL，儲存在 `localStorage`。
- 書城：呼叫 FastAPI `/books` 列表，支援搜尋、章節抽屜與加入書庫。
- 書庫：收藏資料存在 `localStorage`，並即時向目前後端同步章節數以顯示完成度。
