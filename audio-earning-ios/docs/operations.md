# 開發與營運作業

## 環境設定
- **必備**：Xcode 15+, iOS 16 模擬器，Swift 5.9。
- **後端 URL**：僅能透過 `BookListView` 左上角的「Server Settings」管理，資料由 `BackendConfigurationStore` 存於 UserDefaults，支援新增 / 編輯 / 刪除 / 健康檢測。專案中不再使用 `Info.plist` 或硬編碼常數注入 URL。
- **依賴注入**：如需注入 stub 服務，可在 Preview 或單元測試中自建 `AppDependencyContainer`，再設置 `environment(\.dependencies, stub)`。

## 快取與儲存
- **清除快取**：在書籍列表點右上角「Clear Cache」，會呼叫 `CacheManager.clearAllCaches()` → 刪除媒體檔、章節列表/詳情快取。重整後重新抓取資料。
- **快取 TTL**：
  - 章節列表：6 小時
  - 章節內容：12 小時
  - 媒體：24 小時
  調整請修改 `Utilities/CachePolicy.swift` 並更新本文件。
- **離線提示**：`ChapterListViewModel` 會在使用舊快取時顯示 `showingCachedSnapshot`／`showingStaleCache`，方便 QA 驗證。

## 備份 / 匯入
1. 從設定頁啟動匯出 → `DataExportService` 產生 JSON，內容包含 ListeningProgress、SavedLexicon、HighlightedWords、SubtitleAppearance、Backend endpoints。
2. 匯入時 `DataImportService` 會驗證版本與資料完整性，再覆蓋現有資料並發送 `.dataImportDidComplete` 通知；若版本不符會回報 `unsupportedVersion`。
3. 建議在真正覆蓋前先備份舊檔，並提醒使用者匯入會重置伺服器設定。

## 常見排障
- **無法連線伺服器**：使用 Server Settings → Test，實際打 `GET /health`，並確認端點輸入是否為完整的 `https://` URL。
- **字幕不同步**：檢查 SRT 是否含錯誤時間；可在 `SubtitleView` Debug overlay 觀察 `currentSubtitleIndex`（需暫時啟用 debug log）。
- **快取佔用過大**：提醒使用者透過 UI 清除；若需要手動，可刪除 `Library/Caches/audio-cache` 目錄並重新啟動 App。
- **翻譯/解釋 API 回傳 4xx/429**：ViewModel 會顯示錯誤訊息；如需重試，請確認後端速率限制並檢查 `target_language_code` 是否有效。

## 文件維護
- 任何改動 API、緩存策略、設定流程時，同步更新 `docs/api.md`、`docs/operations.md`。
- PR 模板新增勾選項：「本次改動需要更新文件嗎？」若為 Yes，請附連結。
