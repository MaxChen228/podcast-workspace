# Audio Earning iOS

沉浸式播客學習 App，提供書籍/章節瀏覽、逐句字幕與翻譯、批次下載與離線體驗。

## 系統需求
- iOS 16.0+
- Xcode 15+ / Swift 5.9+
- 後端 API：Storytelling Backend 或相容實作

## 快速開始
1. `git clone <repo>` 並進入資料夾。
2. `open audio-earning.xcodeproj` 於 Xcode 15 以上開啟。
3. 選擇模擬器或實機，按下 ▶️ 執行。
4. 第一次啟動若找不到後端，請在「書籍」分頁 → 左上角 **Server Settings** 新增或選擇端點；內建值來源為 Info.plist (`API_BASE_URL*`)。

## 核心功能
- 📚 書籍 / 章節瀏覽：支援離線快照、批次下載、快取 TTL 6 小時。
- 🎧 播放器：`AVPlayer` + 波形視覺化、進度追蹤與自動儲存。
- 📝 字幕與翻譯：詞級高亮、字幕樣式設定、逐句翻譯與句子/片語解釋。
- 💾 備份／匯入：一鍵匯出 JSON，還原後包含伺服器列表與字幕設定。

## 文檔索引
- [Architecture Summary](docs/architecture.md)：層級概覽、資料流、緩存策略。
- [Features Overview](docs/features.md)：主要功能對應的 View / ViewModel / 服務。
- [API Quick Reference](docs/api.md)：App 使用的 HTTP 端點與 payload。
- [Operations Guide](docs/operations.md)：環境設定、快取、備份與排障。

## 專案結構
```
audio-earning-ios/
├─ audio-earning/            SwiftUI App source
│  ├─ Views/                 UI 元件
│  ├─ ViewModels/            狀態與流程
│  ├─ Services/              API、快取、備份、設定
│  └─ Utilities/             共用 helper（音訊、字幕、設計系統）
├─ audio-earningTests/       單元測試
├─ audio-earningUITests/     UI 測試
└─ docs/                     文件（本次重構）
```

## 貢獻
1. 建立 issue 或 PR，描述變更與測試方式。
2. 若調整 API / 緩存 / 功能行為，請同步更新 `docs/` 對應檔案並在 PR 說明。

## 授權
MIT License
