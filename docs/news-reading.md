# 新聞閱讀整合指南

集中說明 NewsData.io 功能的啟用方式、後端設定與 iOS 行為，方便前後端同步排查。

## 架構速覽

| 層 | 元件 | 角色 |
|----|------|------|
| iOS | `NewsFeedView` → `NewsFeedViewModel` → `NewsService` | 發送 `/news/headlines`、`/news/search` 並在互動時呼叫 `POST /news/events` |
| Backend | FastAPI (`server/app/main.py`) + `NewsService` + `NewsEventLogger` | 套用 market/category 篩選、寫入快取、代理 NewsData.io、記錄 JSONL |
| 外部 | NewsData.io API | 提供最新新聞資料來源 |

## 前置需求

1. **Render / 環境變數**
   - `NEWS_FEATURE_ENABLED=1`
   - `NEWSDATA_API_KEY=<your key>`
   - `NEWSDATA_DEFAULT_LANGUAGE=en`、`NEWSDATA_DEFAULT_COUNTRY=us`（可選）
   - `NEWS_EVENTS_DIR=logs/news_events`（或任何具寫入權限的資料夾）
   - `GOOGLE_APPLICATION_CREDENTIALS=/etc/secrets/gcs-service-account.json`
2. **NewsData.io 帳戶**：免費層每日 200 credits、每次請求最多 10 篇；建議在 Dashboard 設定限制與警示。
3. **iOS App 版本**：需包含 `NewsFeedView`（2025/11/09 之後的 `audio-earning-ios`）。

## 端到端流程

1. 使用者打開「新聞」分頁 → `NewsFeedViewModel` 從 `NewsPreferenceStore` 讀 market/分類 → 呼叫 `NewsService.fetchHeadlines()`。
2. iOS 將 `category`、`market`、`count` 參數傳給 backend `/news/headlines`，後端 `NewsService` 會：
   - 檢查快取 (`NEWS_CACHE_TTL_SECONDS` 預設 900 秒)
   - 若需刷新，帶上 `apikey`, `language`, `country` 呼叫 NewsData.io
   - 把結果映射成 `NewsArticle` 陣列
3. 使用者輸入關鍵字 → `searchNews()` → 後端 `/news/search?q=...`，結果會夾帶 `query` 欄位。
4. 點擊／分享／收藏 → `NewsService.log()` 以 best-effort POST `/news/events`；後端 `NewsEventLogger` 將 enriched payload 寫到 `NEWS_EVENTS_DIR/YYYY-MM-DD.jsonl`。
5. 若 NewsData.io 回傳錯誤（401、429、5xx），FastAPI 會轉譯為 4xx/5xx，iOS 會顯示錯誤訊息並允許重新整理。

## 後端檢查清單

```bash
# 1. 健康檢查
curl -s "$BASE_URL/health"

# 2. 驗證 headlines（Technology 分類、最多 3 篇）
curl -s "$BASE_URL/news/headlines?category=technology&market=en-US&count=3" | jq '.articles | length'

# 3. 驗證全文搜尋
curl -s "$BASE_URL/news/search?q=ai&market=en-GB&count=2"

# 4. 確認事件已寫入（容器內）
tail -f backend/logs/news_events/$(date +%F).jsonl
```

若收到 `503`，代表 `NEWS_FEATURE_ENABLED` 為停用或 `NEWSDATA_API_KEY` 未設定。

## iOS 使用者體驗

- 分類按鈕 (`NewsCategoryFilter`) 將對應 `category` 參數，熱門新聞使用 `nil`。
- 市場切換器會呼叫 `NewsPreferenceStore.market = ...` 並立即重新整理。
- 搜尋結果顯示「搜尋結果」標題，清除搜尋會自動回到分類列表。
- `NewsArticleRow` 會顯示來源、相對時間（若 `published_at` 可解析）。
- 互動事件：`open`, `share`, `save`, `impression`；前兩者由 UI 操作觸發，後兩者可依需求擴充。

## 疑難排解速記

| 症狀 | 可能原因 | 解法 |
|------|----------|------|
| iOS 顯示「新聞服務回傳錯誤碼 503」 | 環境變數缺漏或 Render 未重新部署 | 確認 Render Env → 重新 Deploy → 重跑 `curl /news/headlines` |
| API 回傳 502，log 出現 `NewsAPIError rate limit exceeded` | NewsData.io 免費額度用完 | 降低 `count`、增加 `NEWS_CACHE_TTL_SECONDS` 或升級方案 |
| `/news/events` 沒有產生檔案 | `NEWS_EVENTS_DIR` 無寫入權限 | 改到 `/tmp/news_events` 或為資料夾設 `chmod -R 755` |
| iOS 搜尋永遠回 0 篇 | 查詢字串被空白裁剪成空 | 確認前端輸入、後端日誌是否收到 `q` 參數 |

## 相關文件

- [backend/README.md](../backend/README.md#%E6%96%B0%E8%81%9E%E6%95%B4%E5%90%88)
- [backend/docs/api/reference.md](../backend/docs/api/reference.md#%E6%96%B0%E8%81%9E)
- [audio-earning-ios/docs/features.md](../audio-earning-ios/docs/features.md)
- [backend/DEPLOY_RENDER.md](../backend/DEPLOY_RENDER.md)
