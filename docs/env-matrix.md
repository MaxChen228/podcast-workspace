# 環境變數矩陣

| 變數 | 說明 | backend | worker | storytelling-cli | gemini-2-podcast | 預設/範例 |
| --- | --- | :---: | :---: | :---: | :---: | --- |
| `PROJECT_ROOT` | Monorepo 根路徑 | ✔︎ | ✔︎ | ✔︎ | ✔︎ | `$(pwd)` |
| `OUTPUT_ROOT` | 本地輸出資料夾 | ✔︎ | ✔︎ | ✔︎ |  | `../output` |
| `DATA_ROOT` | API 讀取的資料來源，可為本地或 GCS | ✔︎ |  | ✔︎ |  | `../output` (local) / `gs://storytelling-output/output` (prod) |
| `MEDIA_DELIVERY_MODE` | `local` / `gcs-public` / `gcs-signed` | ✔︎ |  |  |  | `local` |
| `STORYTELLING_GCS_CACHE_DIR` | 當 `DATA_ROOT` 指向 GCS 時的快取路徑 | ✔︎ |  |  |  | `/tmp/storytelling-output` |
| `STORYTELLING_SYNC_BUCKET` | worker/CLI 同步目標 Bucket |  | ✔︎ | ✔︎ |  | `gs://storytelling-output/output` |
| `STORYTELLING_SYNC_EXCLUDE_REGEX` | `gsutil rsync` 排除規則 |  | ✔︎ | ✔︎ |  | `(^|/)\.DS_Store$|(^|/)\.gitignore$|(^|/)\.env$|(^|/)\.pytest_cache($|/.*)|.*\.wav$|.*\.textgrid$` |
| `QUEUE_URL` | Redis 佇列 URL | ✔︎ | ✔︎ |  |  | `redis://...` (web) / `rediss://...` (worker) |
| `PODCAST_JOB_QUEUE_NAME` | 佇列名稱 | ✔︎ | ✔︎ |  |  | `podcast_jobs` |
| `DATABASE_URL` | Postgres 連線字串 | ✔︎ | ✔︎ |  |  | `postgresql+psycopg://...` |
| `GEMINI_API_KEY` | Gemini API 金鑰 | ✔︎ | ✔︎ | ✔︎ | ✔︎ | `env` 中設定 |
| `NEWS_USER_AGENT` | Newspaper4k user-agent |  | ✔︎ |  | ✔︎ | `gemini-2-podcast/1.0` |
| `NEWS_REQUEST_TIMEOUT` | Newspaper4k timeout (秒) |  | ✔︎ |  | ✔︎ | `15` |
| `NEWS_LANGUAGE_HINT` | Newspaper4k 語言提示 |  | ✔︎ |  | ✔︎ | `en` |
| `GOOGLE_APPLICATION_CREDENTIALS` | GCS service account | ✔︎ | ✔︎ | ✔︎ |  | `/path/to/sa.json` |

> 本表僅列出跨專案共用的環境變數。各子專案額外參數請參考對應 `.env.example`。
