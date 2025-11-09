//
//  BookModels.swift
//  audio-earning
//
//  Created by Codex on 2025/10/27.
//

import Foundation

/// Book model used by SwiftUI views.
struct Book: Identifiable, Hashable {
    let id: String
    let title: String
    let coverURL: URL?
}

/// Chapter playback metrics.
struct ChapterPlaybackMetrics: Codable, Hashable {
    let wordCount: Int?
    let audioDurationSec: Double?
    let wordsPerMinute: Double?
    let speakingPaceKey: String?

    static let empty = ChapterPlaybackMetrics(wordCount: nil, audioDurationSec: nil, wordsPerMinute: nil, speakingPaceKey: nil)

    var isEmpty: Bool {
        wordCount == nil && audioDurationSec == nil && wordsPerMinute == nil && (speakingPaceKey?.isEmpty ?? true)
    }

    var normalized: ChapterPlaybackMetrics? {
        let trimmedPace = speakingPaceKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        let metrics = ChapterPlaybackMetrics(
            wordCount: wordCount,
            audioDurationSec: audioDurationSec,
            wordsPerMinute: wordsPerMinute,
            speakingPaceKey: trimmedPace?.isEmpty == true ? nil : trimmedPace
        )
        return metrics.isEmpty ? nil : metrics
    }
}

/// Chapter listening progress persisted locally.
struct ChapterProgress: Codable, Hashable {
    let lastPositionSec: Double
    let totalDurationSec: Double?
    let updatedAt: Date
    let isCompleted: Bool

    var fraction: Double {
        guard let duration = totalDurationSec, duration > 0 else { return 0 }
        return max(0, min(lastPositionSec / duration, 1))
    }
}

/// Cached asset status for a chapter.
struct ChapterCacheStatus: Hashable {
    let audioCached: Bool
    let subtitlesCached: Bool

    static let empty = ChapterCacheStatus(audioCached: false, subtitlesCached: false)

    var hasCachedContent: Bool {
        audioCached || subtitlesCached
    }

    var isComplete: Bool {
        audioCached && subtitlesCached
    }
}

/// Chapter summary model.
struct ChapterSummaryModel: Identifiable, Hashable {
    let id: String
    let title: String
    let audioAvailable: Bool
    let subtitlesAvailable: Bool
    let metrics: ChapterPlaybackMetrics?
    let progress: ChapterProgress?
    let cacheStatus: ChapterCacheStatus
    let downloadState: ChapterDownloadState
}

/// Chapter playback model.
struct ChapterPlaybackModel: Identifiable, Hashable {
    let id: String
    let title: String
    let audioURL: URL?
    let subtitlesURL: URL?
    let metrics: ChapterPlaybackMetrics?
    let progress: ChapterProgress?
}

extension ChapterSummaryModel {
    var derivedIndex: Int? {
        ChapterNameParser.chapterIndex(in: title) ?? ChapterNameParser.chapterIndex(in: id)
    }

    var displayTitle: String {
        ChapterNameParser.displayTitle(id: id, title: title)
    }
}

enum ChapterDownloadState: Hashable {
    case idle
    case enqueued
    case downloading(progress: Double?)
    case downloaded
    case failed(String)

    var isActive: Bool {
        switch self {
        case .downloading, .enqueued:
            return true
        default:
            return false
        }
    }

    var isDownloaded: Bool {
        if case .downloaded = self { return true }
        return false
    }
}

extension ChapterPlaybackModel {
    var derivedIndex: Int? {
        ChapterNameParser.chapterIndex(in: title) ?? ChapterNameParser.chapterIndex(in: id)
    }

    var displayTitle: String {
        ChapterNameParser.displayTitle(id: id, title: title)
    }
}
