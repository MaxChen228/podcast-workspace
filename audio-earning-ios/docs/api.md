# API 速覽

所有請求以 `APIConfiguration.shared.baseURL` 為前綴，值完全來自 `BackendConfigurationStore`（也就是 App 內的「後端設定」頁面）。沒有任何 `Info.plist` 或硬編碼 URL 會在背景自動覆蓋這個設定。下表列出 App 目前用到的 HTTP 介面。

| 功能 | Method & Path | 相關程式 | 請求 / 回應要點 |
| --- | --- | --- | --- |
| 健康檢查 | `GET /health` | `APIService.checkHealth` | 用於 Server 設定畫面測試端點，只檢查 2xx。 |
| 書籍列表 | `GET /books` | `APIService.fetchBooks`, `BookListViewModel` | 回傳 `BookResponse` 陣列；ViewModel 會正規化封面 URL (`APIService.normalizedMediaURL`)。 |
| 章節列表 | `GET /books/{bookId}/chapters` | `APIService.fetchChapters`, `ChapterListViewModel` | 回傳 `ChapterResponse`；被寫入 `ChapterListCacheStore`，TTL 6h。 |
| 章節詳情/播放 | `GET /books/{bookId}/chapters/{chapterId}` | `APIService.fetchChapterDetail`, `ChapterPlayerViewModel` | 取得實際音訊/字幕 URL、播放指標，配合 `ChapterCacheStore` 緩存。 |
| 翻譯句子 | `POST /translations` | `APIService.translateSentence`, `ChapterPlayerViewModel` | JSON payload 包含 text、語言代碼與上下文 (book/chapter/subtitleId)；回應 `TranslationResponsePayload`，含 `cached` 標記。 |
| 句子解釋 | `POST /explain/sentence` | `APIService.explainSentence`, `SentenceDetailView` | 需要前後句上下文；回傳重點/詞彙/中譯。 |
| 片語解釋 | `POST /explain/phrase` | `APIService.explainPhrase` | 類似句子解釋，但 payload 为 phrase + sentence context。 |
| 下載音訊 | 原始 URL（可能為 `/audio/...` 或 `gs://`) | `APIService.downloadAudio` | 先解析 307/`gs://` 轉成 HTTPS，再下載到 `temporary/audio-cache`，儲存 ETag 供 `clearMediaCache()` 計數。 |
| 下載字幕 | 原始 URL | `APIService.downloadSubtitles` | 讀取內容字串與檔案 URL，供 `SRTParser` 解析；同時保存 ETag。 |

> **備註**：若後端新增欄位/端點，請同步更新本表與 `ServiceProtocols.swift`，並在 PR 模板勾選「已更新 docs」。
