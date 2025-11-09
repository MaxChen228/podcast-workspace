# Storytelling CLI

> 內容生產工具：將書籍章節轉換為播客腳本、音訊與字幕

這是 Storytelling 專案的 CLI 子專案，負責內容生產流程（腳本生成、音訊合成、字幕對齊）。

## 快速開始

### 1. 安裝依賴

```bash
# 創建虛擬環境
python3 -m venv .venv
source .venv/bin/activate  # macOS/Linux
# .venv\Scripts\activate  # Windows

# 安裝依賴
pip install -r requirements.txt
```

### 2. 配置 API 金鑰

複製 `.env.example` 為 `.env` 並填入實際值：

```bash
cp .env.example .env
# 編輯 .env，至少需要設定 GEMINI_API_KEY
```

### 2.1 放置 Google 服務帳號檔案

1. 將服務帳號 JSON 下載後置於 `storytelling-cli/secrets/google-translate-service-account.json`（此資料夾已被 `.gitignore` 排除，不會誤傳到 Git）。
2. 在 `.env` 中設定

   ```bash
   GOOGLE_APPLICATION_CREDENTIALS=storytelling-cli/secrets/google-translate-service-account.json
   ```

   或在命令列輸入同樣的路徑，即可讓 CLI / gsutil / Render 等流程引用這份金鑰。

### 3. 準備資料

CLI 使用以下目錄結構（可透過環境變數覆寫）：

- **DATA_ROOT** (預設: `../data/`) - 書籍源文件
- **OUTPUT_ROOT** (預設: `../output/`) - 生成結果
- **CONFIG_ROOT** (預設: 當前目錄) - podcast_config.yaml 所在位置

**首次使用時創建資料目錄：**

```bash
# 創建共享資料目錄
mkdir -p ../data/foundation
mkdir -p ../output

# 將書籍章節放入 data 目錄
cp your_book_chapters.txt ../data/foundation/
```

### 4. 執行 CLI

```bash
# 啟動互動式 CLI
./run.sh

# 或直接執行特定命令
./run.sh generate-script --book foundation --chapter chapter0
```

## 工作流程

```
1. 生成腳本 → generate_script.py
2. 生成音訊 → generate_audio.py
3. 生成字幕 → generate_subtitles.py
```

每個步驟可獨立執行，支援批次處理多個章節。

### 離線測試 / Mock Pipeline

需要在沒有 LLM / TTS API 的情況下驗證 CLI UI 或資料夾結構時，可使用 `scripts/mock_pipeline.py` 一次產生假腳本、音訊（靜音 wav）與字幕：

```bash
cd storytelling-cli
./scripts/mock_pipeline.py --book-id gemini-demo --chapters 0-5
```

- 章節範圍語法與互動式 CLI 相同（例如 `0-3,7` 或 `all`）。
- 輸出會寫入 `OUTPUT_ROOT/<book>/<chapter>/`，並在 `data/transcripts/` 生成對應 transcript，方便後續 CLI 模組掃描。
- 產物為 mock 內容（靜音音檔、簡易字幕），僅用於流程測試，正式發布前仍需改跑真實生成腳本。

## 環境變數

| 變數 | 用途 | 預設值 |
|------|------|--------|
| `OUTPUT_ROOT` | 輸出目錄 | `../output/` |
| `DATA_ROOT` | 資料目錄 | `../data/` |
| `CONFIG_ROOT` | 配置目錄 | `.` (當前目錄) |
| `GEMINI_API_KEY` | Gemini API 金鑰 | (必需) |
| `GOOGLE_APPLICATION_CREDENTIALS` | GCS 服務帳號 JSON 路徑（預設建議放 `storytelling-cli/secrets/...`） | (選填) |
| `STORYTELLING_SYNC_BUCKET` | GCS 同步目標 | (選填) |

**使用自訂路徑範例：**

```bash
export OUTPUT_ROOT=/mnt/shared/output
export DATA_ROOT=/mnt/shared/data
./run.sh
```

## 目錄結構

```
storytelling-cli/
├── run.sh                    # 主入口 CLI
├── generate_script.py        # 腳本生成器
├── generate_audio.py         # 音訊生成器
├── generate_subtitles.py     # 字幕生成器
├── preprocess_chapters.py    # 摘要預處理
├── podcast_config.yaml       # 主配置文件
├── storytelling_cli/         # CLI 實現
├── alignment/                # MFA 對齊工具
├── scripts/                  # 輔助腳本
└── requirements/             # 依賴管理
    ├── cli.txt              # CLI 專屬依賴
    ├── base.txt             # 基礎依賴
    └── core.txt             # 核心依賴
```

## 配置說明

編輯 `podcast_config.yaml` 來調整：

- **語言等級** (beginner/intermediate/advanced)
- **長度模式** (short/medium/long)
- **旁白聲音** (Aoede/Puck/Kore 或 random)
- **語速** (slow/normal/fast)

詳細配置選項請參考主專案文檔。

## 常見問題

### Q: 如何批次處理多個章節？

A: 使用範圍選擇，例如：

```bash
./run.sh
# 選擇「生成腳本」
# 輸入章節範圍：0-5,7-9
```

### Q: 生成的檔案在哪裡？

A: 預設在 `../output/<book>/<chapter>/` 目錄：

```
../output/
└── foundation/
    └── chapter0/
        ├── podcast_script.txt
        ├── podcast.wav
        ├── podcast.mp3
        └── subtitles.srt
```

### Q: 如何同步到 GCS？

A: 設定環境變數後，CLI 會在成功生成後自動同步：

```bash
export STORYTELLING_SYNC_BUCKET=gs://your-bucket/output
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
./run.sh
```

## 相關專案

- [backend](../backend/) - FastAPI 服務（提供 API 供前端使用）
- [audio-earning-ios](../audio-earning-ios/) - iOS 播放器應用

## 許可證

MIT License
