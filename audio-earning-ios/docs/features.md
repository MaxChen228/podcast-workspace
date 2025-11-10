# 功能速覽

| 功能 | 使用者流程 | 主要 View / ViewModel | 相關服務 / 儲存 | 提示 |
| --- | --- | --- | --- | --- |
| 書籍 / 章節瀏覽 | 啟動 App → 「書籍」分頁 → 選書、拉下刷新 | `BookListView` + `BookListViewModel`; `ChapterListView` + `ChapterListViewModel` | `APIService.fetchBooks/Chapters`; `BackendConfigurationStore`; `ChapterListCacheStore`; `ListeningProgressStore` | 支援伺服器切換、快取 TTL 6h、離線快照提示 (`showingCachedSnapshot`)。 |
| 播放器與進度 | 章節詳情 → `ChapterPlayerView` 播放、跳轉、查看指標 | `ChapterPlayerViewModel`, `AudioPlayerViewModel`, `PlayerControlsView`, `WaveformView` | `APIService.fetchChapterDetail`; `ChapterCacheStore`; `AudioPlaybackController`; `PlaybackProgressTracker`; `ListeningProgressStore` | `AVPlayer` 以 0.1s observer 更新字幕、進度；波形預產生 500 sample；進度自動儲存，完成章節會標記 completed。 |
| 字幕 / 翻譯 / 解釋 | 播放中查看字幕、點翻譯或開啟句子解說 | `SubtitleView`, `SubtitleSettingsSheet`, `SentenceDetailView`, `HighlightedWordsListView` | `APIService.translateSentence`, `explainSentence`, `explainPhrase`; `SubtitleAppearanceStore`; `HighlightLexiconStore`; `SavedLexiconStore` | 支援詞級高亮、字幕樣式設定、逐句翻譯快取；可收藏詞彙與匯出。 |
| 批次下載與離線 | `ChapterListView` → Bulk download 按鈕 → 背景序列處理 | `ChapterListViewModel` (`bulkDownload*` 狀態), `ChapterDownloadState` | `APIService.downloadAudio/Subtitles`; `ChapterCacheStore`; `ChapterListCacheStore`; `CacheManager` | 會跳過已完成/已快取章節，結束後顯示 summary；若音訊缺失回傳 `BulkDownloadError.audioUnavailable`。 |
| 備份 / 匯入 | 設定頁面下方 → 匯出 JSON 或載入備份 | `SettingsView`, `LexiconListView` (儲存預覽) | `DataExportService`, `DataImportService`, `BackupData`, `BackendConfigurationStore` | 匯出包含進度、字幕外觀、伺服器列表、詞彙；匯入前會驗證版本並覆蓋現有資料。 |
| 新聞牆 / 搜尋 | 「新聞」分頁 → 選分類或輸入關鍵字 | `NewsFeedView`, `NewsArticleRow`, `NewsFeedViewModel` | `NewsService`, `NewsPreferenceStore`; 後端 `/news/*` | 借力 NewsData.io API，支援分類快取、搜尋，以及 `NewsService.log` 上報 `open/share/save/impression`；市場/分類透過 `NewsPreferenceStore` 記憶並預填。 |

> 新功能請在此表加一列：說明使用場景、對應 ViewModel 與服務，並註記任何限制。
