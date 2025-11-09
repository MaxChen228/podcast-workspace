//
//  DataImportService.swift
//  audio-earning
//
//  Created by Claude Code on 2025/11/04.
//

import Foundation

/// 負責驗證和導入備份資料
@MainActor
final class DataImportService {
    static let shared = DataImportService()

    private init() {}

    /// 導入錯誤類型
    enum ImportError: LocalizedError {
        case invalidFormat
        case unsupportedVersion(Int)
        case corruptedData(String)

        var errorDescription: String? {
            switch self {
            case .invalidFormat:
                return "檔案格式不正確，請選擇有效的備份檔案"
            case .unsupportedVersion(let version):
                return "此備份檔案版本（v\(version)）不相容，請使用最新版本的應用程式"
            case .corruptedData(let detail):
                return "備份檔案已損壞：\(detail)"
            }
        }
    }

    /// 驗證備份資料格式
    /// - Parameter data: 備份的 JSON 資料
    /// - Returns: 驗證通過的 BackupData
    /// - Throws: ImportError
    func validateBackupData(_ data: Data) throws -> BackupData {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // 嘗試解碼
        let backup: BackupData
        do {
            backup = try decoder.decode(BackupData.self, from: data)
        } catch {
            throw ImportError.invalidFormat
        }

        // 驗證版本號
        guard backup.version == BackupData.currentVersion else {
            throw ImportError.unsupportedVersion(backup.version)
        }

        // 基本資料驗證
        if backup.listeningProgress.isEmpty &&
           backup.savedLexiconEntries.isEmpty &&
           backup.highlightedWords.isEmpty &&
           backup.backendConfiguration.endpoints.isEmpty {
            throw ImportError.corruptedData("備份檔案中沒有任何資料")
        }

        return backup
    }

    /// 導入資料（完全覆蓋模式）
    /// - Parameter backup: 已驗證的備份資料
    /// - Throws: 導入過程中的錯誤
    func importData(_ backup: BackupData) async throws {
        // 1. 導入學習進度到 ListeningProgressStore（需要 await）
        await ListeningProgressStore.shared.importProgress(backup.listeningProgress)

        // 2. 導入詞彙收藏到 SavedLexiconStore（MainActor）
        SavedLexiconStore.shared.importEntries(backup.savedLexiconEntries)

        // 3. 導入高亮單詞到 UserDefaults
        UserDefaults.standard.set(backup.highlightedWords, forKey: "audioEarning.highlightedWords")

        // 4. 導入字幕設定到 SubtitleAppearanceStore
        SubtitleAppearanceStore.shared.save(backup.subtitleAppearance)

        // 5. 導入後端配置到 BackendConfigurationStore
        BackendConfigurationStore.shared.importConfiguration(
            endpoints: backup.backendConfiguration.endpoints,
            activeID: backup.backendConfiguration.activeEndpointID
        )

        // 6. 發送通知刷新 UI（可選）
        NotificationCenter.default.post(name: .dataImportDidComplete, object: nil)
    }

    /// 從 URL 讀取並導入資料
    /// - Parameter url: 備份檔案的 URL
    /// - Throws: 檔案讀取或導入錯誤
    func importFromFile(at url: URL) async throws {
        // 讀取檔案
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ImportError.corruptedData("無法讀取檔案")
        }

        // 驗證並導入
        let backup = try validateBackupData(data)
        try await importData(backup)
    }
}

// MARK: - Notification

extension Notification.Name {
    static let dataImportDidComplete = Notification.Name("dataImportDidComplete")
}
