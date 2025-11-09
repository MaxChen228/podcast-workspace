# Storytelling CLI / FastAPI 拆分計畫

> 目標：在不影響現有內容生產與 API 能力的前提下，將「生產機 CLI」與「FastAPI 服務」拆成兩個可獨立開發、測試、部署的子專案。

## 1. 背景與問題

- 現況：`storytelling-backend/` 同時包含 `run.sh`、`storytelling_cli/`、`generate_*.py` 以及 `server/app/`。文檔 (`storytelling-backend/README.md:129`)、啟動腳本 (`run.sh:5`) 與設定 (`server/app/config.py:15`) 都假定這些模組共同位於單一資料夾。
- 依賴耦合：FastAPI 的 `requirements/server.txt` 透過 `-r base.txt` 引入所有 LLM/TTS 依賴，導致 Docker build 需要安裝 CLI 套件，增加建置時間與攻擊面。
- 路徑耦合：CLI 及 Server 將 `output/`、`podcast_config.yaml` 視為程式根目錄的相對路徑；任何資料夾拆分都會破壞這些假設。
- 測試與自動化：`tests/test_server_api.py` 直接將 `storytelling-backend` 根目錄加入 `sys.path`，如果移動 CLI 檔案會造成導入失敗。

## 2. 拆分目標

1. **職責分離**：CLI 與 FastAPI 各自擁有獨立的 `README`、`requirements`、虛擬環境與部署流程。
2. **共享契約明確**：兩邊透過環境變數與固定的輸出格式交互，而非依賴相對路徑。
3. **部署瘦身**：FastAPI Docker 映像僅包含提供 API 所需的套件與程式碼。
4. **漸進式遷移**：拆分過程中 CLI 與 API 功能持續可用，且 iOS 前端不需改動 API 介面。

## 3. 指導原則

- 任何階段都 **不移除現有功能**，先新增能力（可配置路徑、抽離依賴）再做檔案搬遷。
- **自動化驗證優先**：每一階段結束前必須通過 CLI smoke test（生成單一章節）與 API integration test（運行 `tests/test_server_api.py`）。
- **文檔同步**：所有指令、路徑、部署步驟在主 `README.md` 與相關子專案說明中立即更新。

## 4. 拆分階段

### Phase 1 – 建立共享契約（路徑與設定）

| 任務 | 影響檔案 | 檢查點 |
| --- | --- | --- |
| 1. 以 `OUTPUT_ROOT` / `DATA_ROOT` 環境變數取代硬編碼，並在未設定時 fallback 至 `output/` | `run.sh`, `storytelling_cli/__main__.py:51`, `server/app/config.py:28`, `scripts/import_gemini_dialogue.py`, 其他直接引用 `output/` 的腳本 | CLI 可寫入自訂資料夾；FastAPI 可從自訂路徑讀取 |
| 2. 將 `podcast_config.yaml`、`.env` 等設定路徑抽象為 `CONFIG_ROOT` | `storytelling_cli/__main__.py`, `generate_*.py`, `preprocess_chapters.py`, `server/app/config.py` | 兩邊可透過環境變數或 CLI 參數覆寫設定 |
| 3. 重構依賴清單：新增 `requirements/cli.txt` (或 `content-worker.txt`)，`requirements/server.txt` 不再 `-r base.txt` | `requirements/` 目錄、Dockerfile | Docker build 不再安裝 LLM/TTS 套件 |
| 4. 更新文檔與 `.env.example` 說明新的環境變數 | `storytelling-backend/README.md`, `docs/setup/configuration.md`, `.env.example` | 使用者知道如何設定新的路徑變數 |

### Phase 2 – 建立 CLI 專屬資料夾

1. 建立 `storytelling-cli/`（暫定名稱）：
   - 內容：`run.sh`, `storytelling_cli/`, `generate_*.py`, `alignment/`, `scripts/`, `data/`, `output/`（或指向共享目錄的 symlink/README）。
   - 新增 `storytelling-cli/README.md`、`requirements.txt`、`.venv` 指南。
2. 在 CLI 專案中保留 Phase 1 建立的環境變數接口，將輸出寫到 `../storytelling-output/`（或 `OUTPUT_ROOT`）。
3. 於 `scripts/` 中新增 `bootstrap_output_dir.py` 或 README，說明如何初始化共享輸出資料夾。
4. 在 root `README.md` 更新架構圖與「子專案列表」，指向新 CLI 路徑。

### Phase 3 – 精簡 FastAPI 子專案

1. 將 `storytelling-backend/` 重點改為「FastAPI 服務」：
   - 保留 `server/`, `tests/`, `docs/api`, `render.yaml`, `Dockerfile`, `podcast_config.yaml`（若 API 仍需讀取）。
   - 移除或引用新的 CLI 子專案（以 Git submodule/依賴說明形式呈現）。
2. Dockerfile 更新：
   - 僅複製 `server/` 與必要 config/doc 檔。
   - `pip install -r requirements/server.txt`（已不含 CLI 依賴）。
3. 測試套件 (`tests/test_server_api.py`) 調整 `PROJECT_ROOT` 指向新的 API 根目錄。
4. Render `render.yaml` 改成以新的 API 子專案為根目錄，確保部署腳本無需 CLI 檔案。

### Phase 4 – 驗證與切換

1. **整合測試**：
   - 在 CLI 子專案執行 `./run.sh` → 生成示例章節 → 確認輸出同步至共享資料夾/GCS。
   - 在 API 子專案執行 `pytest tests/test_server_api.py` 與 `uvicorn server.app.main:app` smoke 測試。
2. **部署驗證**：
   - Render deployment 成功，`/books`、`/books/{book}/chapters`、音訊/字幕串流與可選的 `/news/*` 端點正常。
   - CLI 與 API 各自的 README 指示能讓新人獨立啟動對應工作流。
3. **退場機制**：觀察 1–2 次真實內容更新後再刪除舊 `storytelling-backend` 底下遺留的 CLI 檔案，並在 Git 歷史保留備份（或透過 `storytelling-backend-git-backup/`）。

## 5. 檔案與模組映射（拆分後）

| 類別 | 新位置 | 備註 |
| --- | --- | --- |
| CLI Shell / Typer | `storytelling-cli/run.sh`, `storytelling-cli/storytelling_cli/` | 包含 Chapter 管理、批次處理等邏輯 |
| 內容生成腳本 | `storytelling-cli/generate_*.py`, `storytelling-cli/scripts/` | 控制 LLM、TTS、MFA；依賴 `requirements/cli.txt` |
| 設定檔 | `config/podcast_config.yaml`, `config/.env.example` | 以環境變數或 CLI 參數指定 |
| 輸出資料夾 | `storytelling-output/`（repo 根或外部路徑） | CLI 寫入、API/同步腳本讀取 |
| FastAPI 程式 | `storytelling-backend/server/app/` | 僅保留 API 相關模組 |
| FastAPI 測試 | `storytelling-backend/tests/` | 使用新的輸出路徑、fixtures |

## 6. 風險與緩解

| 風險 | 描述 | 緩解方案 |
| --- | --- | --- |
| 路徑/設定錯誤 | 環境變數未設時 CLI 或 API 找不到輸出 | 在 `run.sh`、`server/app/main.py` 加入明確錯誤訊息與 `--check-config` 命令 |
| 依賴版本漂移 | CLI 與 API 各自管理 requirements，可能版本不一致 | 於 root 建 `requirements/common.txt` 或 `constraints.txt`，兩邊透過 `-c` 共享 pinned 版本 |
| 文件混亂 | 使用者不確定該切換到哪個資料夾操作 | 主 README 提供決策表；各子專案 README 在開頭列明負責範圍與快速入口 |
| 部署回溯困難 | 拆分過程中可能需要回到單一目錄 | 在 Git 打 tag/branch（如 `mono-backend-final`），並保留 `storytelling-backend-git-backup/` |

## 7. 驗收標準

1. CLI 與 API 均可在各自資料夾完成「安裝 → 執行 → 測試」的 README 指南。
2. CLI 生成內容並同步後，FastAPI 透過新 `DATA_ROOT` 正常回應 iOS 需求。
3. Render Docker build 不再安裝 CLI 依賴，映像大小與建置時間顯著下降。
4. 相關文檔（主 README、CLI README、API README、`docs/usage/workflow.md`, `docs/setup/configuration.md`）已更新並通過內部審閱。
5. 拆分計畫在 issue tracker / 變更紀錄張貼完成訊息，並附上回溯方式。

---
