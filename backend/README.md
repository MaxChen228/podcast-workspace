# Storytelling Podcast API

> FastAPI 服務，提供播客內容的 RESTful API

[![Python 3.12+](https://img.shields.io/badge/python-3.12+-blue.svg)](https://www.python.org/downloads/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.115+-green.svg)](https://fastapi.tiangolo.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## 核心特性

- 🚀 **FastAPI 服務** - 高效能的 RESTful API
- 📚 **內容管理** - 管理書籍、章節、音訊和字幕
- ☁️ **多種交付模式** - 支援本地檔案、GCS 直傳、簽名 URL
- 🔍 **新聞整合** - 透過 NewsData.io 提供分類新聞
- 📝 **句子解釋** - Gemini API 提供即時句子說明
- ⚙️ **靈活配置** - 支援環境變數覆寫所有設定

## 快速開始

### 本地開發

```bash
# 1. 安裝依賴
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements/server.txt

# 2. 配置環境變數
cp .env.example .env
# 編輯 .env，設定必要的 API 金鑰

# 3. 啟動開發服務器
uvicorn server.app.main:app --reload --host 0.0.0.0 --port 8000
```

訪問 API 文檔：
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

### Docker 部署

```bash
# 建置映像
docker build -t storytelling-api .

# 執行容器
docker run -p 8000:8000 \
  -e DATA_ROOT=output \
  -e GEMINI_API_KEY=your_key \
  storytelling-api
```

## 環境變數配置

### 核心設定

| 環境變數 | 用途 | 預設值 |
|---------|------|--------|
| `DATA_ROOT` | 內容數據目錄（books、transcripts、音訊等） | `../output` |
| `CORS_ORIGINS` | CORS 允許的來源（逗號分隔） | `""` |
| `GZIP_MIN_SIZE` | Gzip 壓縮的最小檔案大小（bytes） | `512` |

### 媒體交付模式

| 環境變數 | 用途 | 預設值 |
|---------|------|--------|
| `MEDIA_DELIVERY_MODE` | 交付模式：`local`、`gcs-direct`、`gcs-signed` | `local` |
| `GCS_MIRROR_INCLUDE_SUFFIXES` | GCS 模式下需要鏡像的檔案類型（如 `.json,.srt`） | `None` |
| `SIGNED_URL_TTL_SECONDS` | 簽名 URL 有效期限（秒） | `600` |
| `STORYTELLING_GCS_CACHE_DIR` | GCS 快取目錄 | `/tmp/storytelling-output` |

### 句子解釋功能

| 環境變數 | 用途 | 預設值 |
|---------|------|--------|
| `SENTENCE_EXPLAINER_MODEL` | Gemini 模型名稱 | `gemini-2.5-flash-lite` |
| `SENTENCE_EXPLAINER_TIMEOUT` | API 超時時間（秒） | `30` |
| `SENTENCE_EXPLAINER_CACHE_SIZE` | 快取大小 | `128` |
| `GEMINI_API_KEY` | Gemini API 金鑰 | (必需) |

### 新聞整合（NewsData.io）

| 環境變數 | 用途 | 預設值 |
|---------|------|--------|
| `NEWS_FEATURE_ENABLED` | 啟用新聞功能（`1`/`true`） | `false` |
| `NEWSDATA_API_KEY` | NewsData.io API Key | (必需) |
| `NEWSDATA_DEFAULT_LANGUAGE` | 預設語言代碼 | `en` |
| `NEWSDATA_DEFAULT_COUNTRY` | 預設國家代碼（選填） | `None` |
| `NEWS_CATEGORY_WHITELIST` | 允許的分類（逗號分隔，空白表示全部） | `""` |
| `NEWS_CACHE_TTL_SECONDS` | 快取有效期限（秒） | `900` |
| `NEWS_DEFAULT_COUNT` | 預設文章數量 | `10` |
| `NEWS_MAX_COUNT` | 最大文章數量 | `25` |
| `NEWS_EVENTS_DIR` | 事件日誌目錄 | `logs/news_events` |

👉 詳細配置說明請參考 [`.env.example`](.env.example)

## API 端點

### 書籍與章節

- `GET /books` - 取得書籍列表
- `GET /books/{book_id}/chapters` - 取得章節列表
- `GET /books/{book_id}/chapters/{chapter_id}` - 取得章節詳情
- `GET /books/{book_id}/chapters/{chapter_id}/audio` - 音訊串流或簽名 URL
- `GET /books/{book_id}/chapters/{chapter_id}/subtitles` - 字幕下載或簽名 URL

### 新聞功能

- `GET /news/headlines` - 分類新聞標題
- `GET /news/search` - 搜尋最新文章
- `POST /news/events` - 回報使用者互動事件

### 句子解釋

- `POST /explain` - 取得句子的即時說明

👉 **[查看完整 API 文檔](docs/api/reference.md)**

## 媒體交付模式

### Local Mode（預設）

API 直接從本地檔案系統串流音訊和字幕。適合開發環境。

```bash
export MEDIA_DELIVERY_MODE=local
```

### GCS Direct Mode

API 從 GCS 下載檔案到記憶體後串流給客戶端。

```bash
export MEDIA_DELIVERY_MODE=gcs-direct
export DATA_ROOT=../output
```

### GCS Signed URL Mode（推薦用於生產環境）

API 回傳 GCS 簽名 URL，客戶端直接從 GCS 下載。節省記憶體，加快冷啟動。

```bash
export MEDIA_DELIVERY_MODE=gcs-signed
export DATA_ROOT=gs://your-bucket/output
export GCS_MIRROR_INCLUDE_SUFFIXES=.json,.srt
export SIGNED_URL_TTL_SECONDS=600
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
```

## 新聞整合

本 API 整合 [NewsData.io](https://newsdata.io/) 提供分類新聞功能：

**支援的分類：** business, entertainment, environment, food, health, politics, science, sports, technology, top, world

**免費層級限制：**
- 200 credits/天（約 2000 篇文章）
- 最多 10 篇文章/請求

**使用範例：**

```bash
# 啟用新聞功能
export NEWS_FEATURE_ENABLED=true
export NEWSDATA_API_KEY=your_api_key

# 可選：設定預設語言和國家
export NEWSDATA_DEFAULT_LANGUAGE=en
export NEWSDATA_DEFAULT_COUNTRY=us

# 可選：限制分類
export NEWS_CATEGORY_WHITELIST=technology,business
```

## 項目結構

```
backend/
├── server/                  # FastAPI 服務
│   └── app/
│       ├── main.py         # API 端點
│       ├── config.py       # 配置管理
│       ├── schemas.py      # 數據模型
│       └── services/       # 業務邏輯
│           ├── books.py    # 書籍服務
│           ├── media.py    # 媒體交付
│           ├── news.py     # 新聞服務
│           └── explain.py  # 句子解釋
├── requirements/
│   └── server.txt          # API 依賴（不含 CLI 套件）
├── Dockerfile              # Docker 映像定義
├── render.yaml             # Render 部署配置
└── tests/                  # API 測試
```

## 依賴管理

本專案使用精簡的 `requirements/server.txt`，**不包含** CLI 相關的大型套件（LLM、TTS、音訊處理等）：

```bash
# 只安裝 API 必需的依賴
pip install -r requirements/server.txt
```

這使得 Docker 映像大小從 ~2GB 減少至 ~500MB，大幅縮短建置時間。

## 部署

### Render 部署

1. 連接 GitHub 倉庫
2. 選擇 `render.yaml` 自動配置
3. 設定環境變數：
   - `GEMINI_API_KEY`
   - `DATA_ROOT=gs://your-bucket/output`
   - `MEDIA_DELIVERY_MODE=gcs-signed`
   - `GCS_MIRROR_INCLUDE_SUFFIXES=.json,.srt`
4. 部署會自動觸發

👉 **[查看詳細部署指南](DEPLOY_RENDER.md)**

### 其他平台

本 API 可部署至任何支援 Docker 的平台（AWS ECS、Google Cloud Run、Azure Container Instances 等）。

## 開發與測試

### 執行測試

```bash
# 安裝測試依賴
pip install pytest httpx

# 執行測試
pytest tests/ -v
```

### 本地開發

```bash
# 啟動開發服務器（自動重載）
uvicorn server.app.main:app --reload

# 或使用 backend.sh
./backend.sh
```

## 內容生產

本 API 服務**僅負責提供內容**，內容生產（腳本生成、音訊合成、字幕對齊）請使用 **[storytelling-cli](../storytelling-cli/)**。

### 共享目錄架構

```
podcast-workspace/
├── backend/           # API 服務（本專案）
├── storytelling-cli/  # 內容生產工具
├── data/             # 共享：書籍源文件（CLI 寫入）
└── output/           # 共享：生成結果（CLI 寫入、API 讀取）
    └── foundation/
        └── chapter0/
            ├── metadata.json
            ├── podcast.mp3
            └── subtitles.srt
```

## 常見問題

### Q: 如何更改 API 監聽的 host 和 port？

A: 使用 uvicorn 參數：
```bash
uvicorn server.app.main:app --host 0.0.0.0 --port 8080
```

### Q: 如何啟用 CORS？

A: 設定環境變數：
```bash
export CORS_ORIGINS="http://localhost:3000,https://your-app.com"
```

### Q: GCS 模式下如何處理認證？

A: 設定服務帳號金鑰：
```bash
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
```

### Q: 如何監控 API 效能？

A: FastAPI 內建 `/docs` 可以測試端點，可整合 Prometheus、Grafana 等監控工具。

👉 **[查看更多問題](docs/operations/troubleshooting.md)**

## 相關專案

- [storytelling-cli](../storytelling-cli/) - 內容生產工具（腳本、音訊、字幕）
- [audio-earning-ios](../audio-earning-ios/) - iOS 前端播放器應用

## 許可證

MIT License - 詳見 [LICENSE](LICENSE) 文件

## 貢獻

歡迎貢獻！請閱讀 [貢獻指南](docs/development/contributing.md) 了解如何參與開發。

---

**需要幫助？**

- 📖 [查看完整文檔](docs/README.md)
- 🐛 [報告問題](https://github.com/MaxChen228/podcast-workspace/issues)
- 💬 [討論區](https://github.com/MaxChen228/podcast-workspace/discussions)
