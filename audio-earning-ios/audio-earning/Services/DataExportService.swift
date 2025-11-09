//
//  DataExportService.swift
//  audio-earning
//
//  Created by Claude Code on 2025/11/04.
//

import Foundation

/// 負責收集所有用戶資料並生成 JSON 備份檔案
@MainActor
final class DataExportService {
    static let shared = DataExportService()

    private init() {}

    /// 導出所有資料為 JSON Data
    /// - Returns: 包含所有用戶資料的 JSON Data
    /// - Throws: 編碼錯誤
    func exportAllData() async throws -> Data {
        // 1. 從 ListeningProgressStore 讀取（需要 await，因為是 actor）
        let listeningProgress = await ListeningProgressStore.shared.exportAllProgress()

        // 2. 從 SavedLexiconStore 讀取（已在 MainActor）
        let savedLexiconEntries = SavedLexiconStore.shared.exportEntries()

        // 3. 從 UserDefaults 讀取高亮單詞
        let highlightedWords = UserDefaults.standard.stringArray(forKey: "audioEarning.highlightedWords") ?? []

        // 4. 從 SubtitleAppearanceStore 讀取
        let subtitleAppearance = SubtitleAppearanceStore.shared.load()

        // 5. 從 BackendConfigurationStore 讀取
        let backendConfig = BackendConfigurationStore.shared.exportConfiguration()
        let backendConfiguration = BackupData.BackendConfiguration(
            endpoints: backendConfig.endpoints,
            activeEndpointID: backendConfig.activeID
        )

        // 6. 組裝 BackupData
        let backup = BackupData.create(
            listeningProgress: listeningProgress,
            savedLexiconEntries: savedLexiconEntries,
            highlightedWords: highlightedWords,
            subtitleAppearance: subtitleAppearance,
            backendConfiguration: backendConfiguration
        )

        // 7. 使用 JSONEncoder 生成 JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        return try encoder.encode(backup)
    }

    /// 生成備份檔案名稱
    /// - Returns: 格式化的檔案名稱，例如 "audio-earning-backup-2025-11-04-1430.json"
    func generateFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return "audio-earning-backup-\(formatter.string(from: Date())).json"
    }

    /// 將備份資料寫入臨時檔案並返回 URL
    /// - Parameter data: 備份的 JSON 資料
    /// - Returns: 臨時檔案的 URL
    /// - Throws: 檔案寫入錯誤
    func createTemporaryFile(from data: Data) throws -> URL {
        let fileName = generateFileName()
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(fileName)

        try data.write(to: fileURL, options: [.atomic])

        return fileURL
    }
}
