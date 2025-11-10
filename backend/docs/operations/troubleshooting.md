# 故障排除指南

集中整理常見症狀及排除步驟，特別針對新加入的新聞閱讀功能。

## 1️⃣ 基礎檢查

1. **服務存活**：`curl -s $BASE_URL/health` 應回 `{ "status": "ok" }`。
2. **GCS 存取**：`curl -s $BASE_URL/debug/gcs | jq '.gcs_connection.bucket_exists'` → `true`。
3. **Render Logs**：檢查 `Events` 與 `Logs` 是否有 Crash/Out-of-memory。

## 2️⃣ `/books` 或媒體端點失敗

- 確認 `DATA_ROOT` 指向的 bucket/目錄存在。
- 若回傳 500，查看後端日誌中 `OutputDataCache` 或 `GCSMirror` 報錯。
- 測試 `curl "$BASE_URL/books" | head`。

## 3️⃣ 新聞牆無資料

| 檢查 | 指令 | 期望 |
|-------|-------|-------|
| 環境變數 | `render env` / `cat backend/.env` | `NEWS_FEATURE_ENABLED=1`, `NEWSDATA_API_KEY` 存在 |
| API Key | `curl "$BASE_URL/news/headlines?count=1"` | 回傳 200，若 503 表示服務未啟用 |
| NewsData 配額 | 查看日誌是否出現 `NewsAPIError rate limit exceeded` | 若出現，需等待配額或升級方案 |
| 事件記錄 | `ls backend/logs/news_events` | 應有以日期命名的 `.jsonl` |

### 排除步驟

1. **503：News feature disabled**
   - 在 Render > Environment 重新確認 `NEWS_FEATURE_ENABLED`, `NEWSDATA_API_KEY`，並重新部署。
2. **502：News API error**
   - NewsData.io 當下不可用或 key 錯誤，對照 Dashboard，必要時更新 key。
3. **iOS 持續顯示「新聞服務回傳不合法的資料」**
   - 可能是後端回傳空 JSON。以 `curl ... | jq` 驗證 response 是否可解析。
4. **互動事件未寫入**
   - 確認 `NEWS_EVENTS_DIR` 所在資料夾具寫入權限（例如 `/tmp/news_events`）。

## 4️⃣ 監控建議

- 於 Render 設定 Log Alerts，當出現 `NewsAPIError` 時寄信提醒。
- 週期性（cron）下載 `NEWS_EVENTS_DIR` 的 JSONL，以避免容器儲存被占滿。
- 若經常撞到 NewsData 限額，可將 `NEWS_CACHE_TTL_SECONDS` 提高、或在 iOS 端降低 `count`。
