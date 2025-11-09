//
//  BackupData.swift
//  audio-earning
//
//  Created by Claude Code on 2025/11/04.
//

import Foundation
import UIKit

/// 統一的備份資料結構，用於跨裝置轉移所有用戶資料
struct BackupData: Codable {
    /// 備份格式版本號（目前為 1）
    let version: Int

    /// 備份建立時間
    let createdAt: Date

    /// 裝置資訊
    let deviceInfo: DeviceInfo

    /// 學習進度資料（key 格式：bookID#chapterID）
    let listeningProgress: [String: ListeningProgressRecord]

    /// 收藏的詞彙條目
    let savedLexiconEntries: [SavedLexiconEntry]

    /// 高亮單詞列表
    let highlightedWords: [String]

    /// 字幕外觀設定
    let subtitleAppearance: SubtitleAppearance

    /// 後端配置
    let backendConfiguration: BackendConfiguration

    /// 裝置資訊結構
    struct DeviceInfo: Codable {
        let systemName: String      // iOS 版本，例如 "iOS 17.0"
        let systemVersion: String   // 系統版本號，例如 "17.0"
        let appVersion: String      // 應用版本，例如 "1.0.0"
    }

    /// 後端配置結構
    struct BackendConfiguration: Codable {
        let endpoints: [BackendEndpoint]
        let activeEndpointID: UUID?
    }

    /// 當前備份格式版本
    static let currentVersion = 1

    /// 建立新的備份資料
    static func create(
        listeningProgress: [String: ListeningProgressRecord],
        savedLexiconEntries: [SavedLexiconEntry],
        highlightedWords: [String],
        subtitleAppearance: SubtitleAppearance,
        backendConfiguration: BackendConfiguration
    ) -> BackupData {
        return BackupData(
            version: currentVersion,
            createdAt: Date(),
            deviceInfo: DeviceInfo.current(),
            listeningProgress: listeningProgress,
            savedLexiconEntries: savedLexiconEntries,
            highlightedWords: highlightedWords,
            subtitleAppearance: subtitleAppearance,
            backendConfiguration: backendConfiguration
        )
    }
}

// MARK: - DeviceInfo Extension

extension BackupData.DeviceInfo {
    /// 取得當前裝置資訊
    static func current() -> BackupData.DeviceInfo {
        let systemVersion = UIDevice.current.systemVersion
        let systemName = "\(UIDevice.current.systemName) \(systemVersion)"

        // 取得 App 版本
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"

        return BackupData.DeviceInfo(
            systemName: systemName,
            systemVersion: systemVersion,
            appVersion: appVersion
        )
    }
}
