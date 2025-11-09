//
//  ListeningProgressStore.swift
//  audio-earning
//
//  Created by Codex on 2025/10/29.
//

import Foundation

public struct ListeningProgressRecord: Codable, Equatable {
    let bookID: String
    let chapterID: String
    var lastPositionSec: Double
    var totalDurationSec: Double?
    var updatedAt: Date
    var isCompleted: Bool

    var chapterProgress: ChapterProgress {
        ChapterProgress(
            lastPositionSec: lastPositionSec,
            totalDurationSec: totalDurationSec,
            updatedAt: updatedAt,
            isCompleted: isCompleted
        )
    }
}

/// Persists listening progress locally for chapter resume and UI indicators.
actor ListeningProgressStore {
    static let shared = ListeningProgressStore()

    private let fileManager: FileManager
    private let storeURL: URL
    private var cache: [String: ListeningProgressRecord] = [:]

    private init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let supportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let folder = supportDir.appendingPathComponent("listening-progress", isDirectory: true)

        if !fileManager.fileExists(atPath: folder.path) {
            try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        }

        self.storeURL = folder.appendingPathComponent("progress.json")
        self.cache = Self.readCache(from: storeURL, fileManager: fileManager)
    }

    private func key(bookID: String, chapterID: String) -> String {
        "\(bookID)#\(chapterID)"
    }

    func progress(bookID: String, chapterID: String) -> ChapterProgress? {
        cache[key(bookID: bookID, chapterID: chapterID)]?.chapterProgress
    }

    func saveProgress(bookID: String, chapterID: String, position: Double, duration: Double?, completed: Bool) {
        let sanitizedPosition = max(0, position)
        let sanitizedDuration = duration ?? cache[key(bookID: bookID, chapterID: chapterID)]?.totalDurationSec

        guard sanitizedPosition > 0 || sanitizedDuration != nil || completed else {
            // Nothing meaningful to persist yet.
            return
        }

        let now = Date()
        let existingKey = key(bookID: bookID, chapterID: chapterID)
        let existing = cache[existingKey]

        var record = ListeningProgressRecord(
            bookID: bookID,
            chapterID: chapterID,
            lastPositionSec: sanitizedPosition,
            totalDurationSec: sanitizedDuration,
            updatedAt: now,
            isCompleted: completed
        )

        if var current = existing {
            let mergedDuration = sanitizedDuration ?? current.totalDurationSec
            let clampedPosition: Double
            if let duration = mergedDuration {
                clampedPosition = min(max(sanitizedPosition, 0), max(duration, 0))
            } else {
                clampedPosition = sanitizedPosition
            }

            current.lastPositionSec = clampedPosition
            current.totalDurationSec = mergedDuration
            current.updatedAt = now

            if completed {
                current.isCompleted = true
                if let duration = mergedDuration {
                    current.lastPositionSec = max(duration, clampedPosition)
                }
            } else if current.isCompleted {
                current.isCompleted = false
            }

            record = current
        }

        cache[existingKey] = record
        persist()

        NotificationCenter.default.post(
            name: .listeningProgressDidChange,
            object: nil,
            userInfo: [
                "bookID": bookID,
                "chapterID": chapterID,
                "progress": record.chapterProgress
            ]
        )
    }

    func clear(bookID: String, chapterID: String) {
        cache.removeValue(forKey: key(bookID: bookID, chapterID: chapterID))
        persist()
    }

    func clearAll() {
        cache.removeAll()
        persist()
    }

    // MARK: - Backup & Restore

    /// 導出所有學習進度（用於備份）
    func exportAllProgress() -> [String: ListeningProgressRecord] {
        return cache
    }

    /// 導入學習進度（完全覆蓋現有資料）
    func importProgress(_ records: [String: ListeningProgressRecord]) {
        cache = records
        persist()

        // 發送通知刷新 UI
        NotificationCenter.default.post(
            name: .listeningProgressDidChange,
            object: nil,
            userInfo: nil
        )
    }

    // MARK: - Persistence

    private func persist() {
        do {
            let data = try JSONEncoder().encode(cache)
            try data.write(to: storeURL, options: [.atomic])
        } catch {
#if DEBUG
            print("⚠️ Failed to persist listening progress: \(error.localizedDescription)")
#endif
        }
    }

    private static func readCache(from url: URL, fileManager: FileManager) -> [String: ListeningProgressRecord] {
        guard fileManager.fileExists(atPath: url.path) else { return [:] }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([String: ListeningProgressRecord].self, from: data)
        } catch {
            return [:]
        }
    }
}

extension Notification.Name {
    static let listeningProgressDidChange = Notification.Name("listeningProgressDidChange")
}
