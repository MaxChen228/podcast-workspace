# Podcast Workspace

整合後端內容生成與 iOS 播放體驗的單一工作區。此專案同時包含 **Storytelling Backend**（Python+FastAPI）與 **Audio Earning iOS**（SwiftUI 播客播放器），讓你能從書籍章節生成腳本/音頻/字幕，再在行動端提供沉浸式學習體驗。

## 專案總覽
| 子專案 | 技術棧 | 角色 | 快速入口 |
| --- | --- | --- | --- |
| `storytelling-backend/` | Python 3.12+, FastAPI, Gemini TTS, Montreal Forced Aligner | 章節腳本、音頻、字幕生成與 REST API | [後端 README](storytelling-backend/README.md) |
| `audio-earning-ios/` | Swift 5.9+, SwiftUI, AVFoundation | 使用者端書籍/章節瀏覽、逐句字幕與翻譯、批次下載 | [前端 README](audio-earning-ios/README.md) |

其他目錄：
- `podcast_cli/`：封裝 CLI 腳本與自動化流程的共用模組。
- `requirements/`：後端依賴鎖定檔案（分 base/dev/serve）。
- `scripts/`：部署或批次處理腳本。
- `output.log`：最近一次 CLI 執行輸出。

```
podcast-workspace/
├── storytelling-backend/      # FastAPI + 內容生成流水線
├── audio-earning-ios/         # SwiftUI iOS App
├── podcast_cli/               # 共用 CLI 函式庫
├── scripts/                   # 自動化腳本
├── requirements/              # pip requirements
└── README.md                  # 本文件
```

## 快速開始

### 1. 後端（內容生成 + API）
```bash
cd storytelling-backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements/base.txt
cp .env.example .env   # 設定 GEMINI_API_KEY 等機密

# 互動式 CLI：生成腳本 / 音頻 / 字幕
./run.sh

# 或啟動 FastAPI 服務（供前端連線）
uvicorn server.app.main:app --reload --host 0.0.0.0 --port 8000
```
- 產出會寫入 `storytelling-backend/output/<book>/<chapter>/`（含腳本、WAV/MP3、SRT）。
- API 端點包含 `/books`, `/books/{id}/chapters`, `/books/{id}/chapters/{chapterId}` 等；詳見後端 README 及 `docs/api/reference.md`。

### 2. 前端（iOS 播放器）
```bash
cd audio-earning-ios
open audio-earning.xcodeproj  # Xcode 15+
```
1. 在書籍分頁左上角 **Server Settings** 設定 API 基底網址，指向正在運行的後端 (預設讀 Info.plist `API_BASE_URL*`).
2. 選擇模擬器或裝置並執行，於 App 內即可瀏覽書籍、下載章節、使用逐句字幕與翻譯。

## 工作流程建議
1. **內容準備**：在 `storytelling-backend` 透過 CLI 依序生成腳本、音頻、字幕；確認輸出與 API 能提供對應章節。
2. **啟動 API**：以 `uvicorn` 或部署腳本啟動 FastAPI，確保 `/health` 正常。
3. **前端串接**：在 iOS App 選擇同一個 API 端點，使用章節列表與播放器驗證音訊、字幕、翻譯/解釋功能。
4. **備份／匯入**：如需同步使用者資料，利用 App 設定頁的匯出/匯入（對應 `DataExportService` / `DataImportService`）。

## 文檔導航
- 後端深入文件：`storytelling-backend/docs/`（安裝、配置、API、部署、排障）。
- Demo 想快速引入 Gemini 雙人對話，可在 `gemini-2-podcast/` 生成音檔後執行 `python storytelling-backend/scripts/import_gemini_dialogue.py --book <book> --chapter <chapter>` 匯入。
- 前端新文檔：`audio-earning-ios/docs/`（架構、功能、API 對應、操作指南）。
- 若要理解 CLI 腳本，請查看 `podcast_cli/` 或 `scripts/` 內說明。

## 常用命令速查
| 情境 | 命令 |
| --- | --- |
| 更新後端依賴 | `pip install -r requirements/dev.txt` |
| 執行整批章節生成 | `./run.sh` → 輸入 `1-3` 代表生成 1~3 章 |
| 啟動 API（生產模式建議透過 gunicorn/uvicorn workers） | `uvicorn server.app.main:app --host 0.0.0.0 --port 8000` |
| 清除 iOS App 快取 | App 書籍分頁右上角「Clear Cache」，或 `CacheManager.clearAllCaches()` |
| 匯出 iOS 使用者資料 | App 設定頁 → Export Backup → 取得 JSON |

## 協作建議
1. 兩邊倉庫各自使用 `git`，建議在根目錄以 `direnv` 或 shell script 切換虛擬環境 / Xcode 設定。
2. 修改後端 API 契約時，請同步更新：
   - `storytelling-backend/docs/api/reference.md`
   - `audio-earning-ios/docs/api.md`
   - iOS `APIService` 與相關 ViewModel。
3. 新增 iOS 功能時，記得在 `audio-earning-ios/docs/features.md` 加上條目，並視需要更新此根 README 的摘要。

## 授權
整體採 MIT License；各子專案可參考其目錄下的 LICENSE 說明。
