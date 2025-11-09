//
//  ChapterListViewModel.swift
//  audio-earning
//
//  Created by Codex on 2025/10/27.
//

import Foundation

struct BulkDownloadProgress: Equatable {
    let completedCount: Int
    let totalCount: Int
    let downloadedCount: Int
    let estimatedRemainingSeconds: TimeInterval?
    let currentTitle: String?

    var fraction: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    var remainingCount: Int {
        max(totalCount - completedCount, 0)
    }

    var percentText: String {
        let percent = Int(fraction * 100)
        return "\(percent)%"
    }
}

struct BulkDownloadSummary: Identifiable, Equatable {
    let id = UUID()
    let downloadedCount: Int
    let skippedAlreadyCachedCount: Int
    let skippedCompletedCount: Int

    var message: String {
        var components: [String] = []

        if downloadedCount > 0 {
            components.append("完成 \(downloadedCount) 個章節下載")
        }

        if skippedAlreadyCachedCount > 0 {
            components.append("跳過 \(skippedAlreadyCachedCount) 個已在本地的章節")
        }

        if skippedCompletedCount > 0 {
            components.append("跳過 \(skippedCompletedCount) 個已完成的章節")
        }

        if components.isEmpty {
            return "目前沒有可下載的章節。"
        }

        return components.joined(separator: "，") + "。"
    }
}

struct BulkDownloadFailure: Identifiable, Equatable {
    let id = UUID()
    let message: String
}

enum BulkDownloadError: LocalizedError {
    case audioUnavailable

    var errorDescription: String? {
        switch self {
        case .audioUnavailable:
            return "伺服器未提供音訊檔案。"
        }
    }
}

@MainActor
final class ChapterListViewModel: ObservableObject {
    let book: Book

    @Published var chapters: [ChapterSummaryModel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var isOffline = false
    @Published private(set) var isBulkDownloading = false
    @Published private(set) var bulkDownloadProgress: BulkDownloadProgress?
    @Published var bulkDownloadSummary: BulkDownloadSummary?
    @Published var bulkDownloadFailure: BulkDownloadFailure?
    @Published private(set) var lastSyncedAt: Date?
    @Published private(set) var showingCachedSnapshot = false
    @Published private(set) var showingStaleCache = false

    private let service: APIServiceProtocol
    private let chapterListCache: ChapterListCaching
    private let chapterCache: ChapterCaching
    private let progressStore: ListeningProgressManaging
    private var hasLoaded = false
    private var bulkDownloadTask: Task<Void, Never>?
    private var downloadTasks: [String: Task<Void, Never>] = [:]
    private var downloadStates: [String: ChapterDownloadState] = [:]
    private let cacheTTL = CachePolicy.chapterListTTL
    private var bulkDownloadStartTime: Date?

    init(
        book: Book,
        service: APIServiceProtocol = APIService.shared,
        chapterListCache: ChapterListCaching = ChapterListCacheStore.shared,
        chapterCache: ChapterCaching = ChapterCacheStore.shared,
        progressStore: ListeningProgressManaging = ListeningProgressStore.shared
    ) {
        self.book = book
        self.service = service
        self.chapterListCache = chapterListCache
        self.chapterCache = chapterCache
        self.progressStore = progressStore
    }

    func loadChapters(force: Bool = false) {
        guard !hasLoaded || force else { return }
        hasLoaded = true

        Task { [weak self] in
            await self?.performInitialLoad(force: force)
        }
    }

    private func performInitialLoad(force: Bool) async {
        errorMessage = nil
        isOffline = false

        let cachedList = await chapterListCache.list(for: book.id)
        if let cachedList {
            let cachedChapters = cachedList.chapters.map { summary in
                ChapterSummaryModel(
                    id: summary.id,
                    title: summary.title,
                    audioAvailable: summary.audioAvailable,
                    subtitlesAvailable: summary.subtitlesAvailable,
                    metrics: summary.metrics,
                    progress: nil,
                    cacheStatus: .empty,
                    downloadState: resolveDownloadState(for: summary.id, cacheStatus: .empty)
                )
            }
            let enriched = await enrichLocalState(for: cachedChapters)
            chapters = sortChapters(enriched)
            lastSyncedAt = cachedList.cachedAt
            showingCachedSnapshot = true
            showingStaleCache = Date().timeIntervalSince(cachedList.cachedAt) > cacheTTL
        }

        let cachedIsFresh = cachedList.flatMap { Date().timeIntervalSince($0.cachedAt) <= cacheTTL } ?? false

        if !force, cachedIsFresh {
            isLoading = false
            // Fire-and-forget background refresh to softly update chapters.
            Task { [weak self] in
                await self?.refreshChapters(silent: true)
            }
            return
        }

        await refreshChapters(silent: cachedList != nil)
    }

    private func refreshChapters(silent: Bool) async {
        if !silent {
            isLoading = true
        }
        errorMessage = nil
        isOffline = false

        do {
            let responses = try await service.fetchChapters(bookID: book.id)
            let fetchedChapters = await buildSummaries(from: responses)
            let sortedChapters = sortChapters(fetchedChapters)
            chapters = sortedChapters

            let cachedChapters = sortedChapters.map { chapter in
                CachedChapterSummary(
                    id: chapter.id,
                    title: chapter.title,
                    audioAvailable: chapter.audioAvailable,
                    subtitlesAvailable: chapter.subtitlesAvailable,
                    metrics: chapter.metrics
                )
            }
            await chapterListCache.save(bookID: book.id, chapters: cachedChapters)
            lastSyncedAt = Date()
            showingCachedSnapshot = false
            showingStaleCache = false
        } catch {
            if chapters.isEmpty {
                errorMessage = error.localizedDescription
                showingCachedSnapshot = false
                showingStaleCache = false
            } else {
                isOffline = true
                showingCachedSnapshot = true
                showingStaleCache = true
            }
        }

        if !silent {
            isLoading = false
        }
    }

    func refreshProgress() {
        Task { [weak self] in
            guard let self else { return }
            guard !chapters.isEmpty else { return }
            let updated = await enrichLocalState(for: chapters)
            let sorted = sortChapters(updated)
            chapters = sorted
        }
    }

    func startBulkDownload() {
        guard bulkDownloadTask == nil else { return }
        bulkDownloadFailure = nil
        bulkDownloadSummary = nil
        bulkDownloadProgress = nil
        bulkDownloadStartTime = nil

        bulkDownloadTask = Task { [weak self] in
            await self?.performBulkDownload()
        }
    }

    func cancelBulkDownload() {
        bulkDownloadTask?.cancel()
        bulkDownloadTask = nil
        isBulkDownloading = false
        bulkDownloadProgress = nil
        bulkDownloadSummary = nil
        bulkDownloadFailure = nil
        bulkDownloadStartTime = nil
    }

    func downloadChapter(chapterID: String) {
        guard downloadTasks[chapterID] == nil else { return }
        guard let chapter = chapters.first(where: { $0.id == chapterID }) else { return }
        guard chapter.audioAvailable else { return }

        if chapter.cacheStatus.isComplete {
            downloadStates[chapterID] = .downloaded
            updateChapterDownloadState(chapterID: chapterID, overrideState: .downloaded)
            return
        }

        updateChapterDownloadState(chapterID: chapterID, overrideState: .enqueued)

        let task = Task { [weak self] in
            guard let self else { return }
            await self.performSingleDownload(chapterID: chapterID)
        }

        downloadTasks[chapterID] = task
    }

    func cancelDownload(chapterID: String) {
        downloadTasks[chapterID]?.cancel()
        downloadTasks[chapterID] = nil
        downloadStates[chapterID] = .idle
        updateChapterDownloadState(chapterID: chapterID, overrideState: .idle)
    }

    func clearDownloadError(chapterID: String) {
        guard case .failed = downloadStates[chapterID] else { return }
        downloadStates[chapterID] = .idle
        updateChapterDownloadState(chapterID: chapterID, overrideState: .idle)
    }

    private func buildSummaries(from responses: [ChapterResponse]) async -> [ChapterSummaryModel] {
        var summaries: [ChapterSummaryModel] = []
        summaries.reserveCapacity(responses.count)

        for response in responses {
            let metrics = Self.makeMetrics(
                wordCount: response.wordCount,
                audioDurationSec: response.audioDurationSec,
                wordsPerMinute: response.wordsPerMinute,
                speakingPaceKey: response.speakingPaceKey
            )
            let progress = await progressStore.progress(bookID: book.id, chapterID: response.id)
            let cacheStatus = await cacheStatus(for: response.id)
            let downloadState = resolveDownloadState(for: response.id, cacheStatus: cacheStatus)
            let summary = ChapterSummaryModel(
                id: response.id,
                title: response.title,
                audioAvailable: response.audioAvailable,
                subtitlesAvailable: response.subtitlesAvailable,
                metrics: metrics,
                progress: progress,
                cacheStatus: cacheStatus,
                downloadState: downloadState
            )
            summaries.append(summary)
        }

        return summaries
    }

    private func enrichLocalState(for summaries: [ChapterSummaryModel]) async -> [ChapterSummaryModel] {
        var enriched: [ChapterSummaryModel] = []
        enriched.reserveCapacity(summaries.count)

        for summary in summaries {
            async let progressTask = progressStore.progress(bookID: book.id, chapterID: summary.id)
            async let cacheTask = cacheStatus(for: summary.id)

            let progress = await progressTask
            let cacheStatus = await cacheTask
            let downloadState = resolveDownloadState(for: summary.id, cacheStatus: cacheStatus)

            let updated = ChapterSummaryModel(
                id: summary.id,
                title: summary.title,
                audioAvailable: summary.audioAvailable,
                subtitlesAvailable: summary.subtitlesAvailable,
                metrics: summary.metrics,
                progress: progress,
                cacheStatus: cacheStatus,
                downloadState: downloadState
            )
            enriched.append(updated)
        }

        return enriched
    }

    private func performBulkDownload() async {
        defer { bulkDownloadTask = nil }

        isBulkDownloading = true
        bulkDownloadProgress = nil
        bulkDownloadStartTime = nil

        let eligible = chapters.filter { $0.audioAvailable && $0.subtitlesAvailable }
        var targets: [ChapterSummaryModel] = []
        var skippedExisting = 0
        var skippedCompleted = 0

        for chapter in eligible {
            if Task.isCancelled {
                finalizeBulkDownload(
                    downloaded: 0,
                    skippedExisting: skippedExisting,
                    skippedCompleted: skippedCompleted,
                    showSummary: false
                )
                return
            }

            if chapter.progress?.isCompleted == true {
                skippedCompleted += 1
                continue
            }

            let status = await cacheStatus(for: chapter.id)
            if status.isComplete {
                downloadStates[chapter.id] = .downloaded
                updateChapterDownloadState(chapterID: chapter.id, overrideState: .downloaded)
                skippedExisting += 1
            } else {
                targets.append(chapter)
            }
        }

        if Task.isCancelled {
            finalizeBulkDownload(
                downloaded: 0,
                skippedExisting: skippedExisting,
                skippedCompleted: skippedCompleted,
                showSummary: false
            )
            return
        }

        guard !targets.isEmpty else {
            finalizeBulkDownload(
                downloaded: 0,
                skippedExisting: skippedExisting,
                skippedCompleted: skippedCompleted
            )
            return
        }

        let totalEligible = skippedExisting + targets.count
        bulkDownloadStartTime = Date()

        var processedTargets = 0
        var downloaded = 0

        updateBulkDownloadProgress(
            completedCount: skippedExisting,
            downloadedCount: 0,
            totalCount: totalEligible,
            currentTitle: targets.first.map { displayTitle(for: $0) }
        )

        for chapter in targets {
            if Task.isCancelled {
                updateChapterDownloadState(chapterID: chapter.id, overrideState: .idle)
                finalizeBulkDownload(
                    downloaded: downloaded,
                    skippedExisting: skippedExisting,
                    skippedCompleted: skippedCompleted,
                    showSummary: false
                )
                return
            }

            updateChapterDownloadState(chapterID: chapter.id, overrideState: .downloading(progress: nil))
            updateBulkDownloadProgress(
                completedCount: skippedExisting + processedTargets,
                downloadedCount: downloaded,
                totalCount: totalEligible,
                currentTitle: displayTitle(for: chapter)
            )

            do {
                try await downloadChapterAssets(for: chapter) { [self] progress in
                    updateChapterDownloadState(chapterID: chapter.id, overrideState: .downloading(progress: progress))
                }
                downloaded += 1
                processedTargets += 1

                let status = await cacheStatus(for: chapter.id)
                applyCacheStatus(status, to: chapter)
            } catch {
                if error is CancellationError {
                    updateChapterDownloadState(chapterID: chapter.id, overrideState: .idle)
                    finalizeBulkDownload(
                        downloaded: downloaded,
                        skippedExisting: skippedExisting,
                        skippedCompleted: skippedCompleted,
                        showSummary: false
                    )
                    return
                }

                let message = error.localizedDescription
                bulkDownloadFailure = BulkDownloadFailure(message: message)
                downloadStates[chapter.id] = .failed(message)
                updateChapterDownloadState(chapterID: chapter.id, overrideState: .failed(message))
                finalizeBulkDownload(
                    downloaded: downloaded,
                    skippedExisting: skippedExisting,
                    skippedCompleted: skippedCompleted,
                    showSummary: downloaded > 0
                )
                return
            }

            downloadStates[chapter.id] = .downloaded
            updateChapterDownloadState(chapterID: chapter.id, overrideState: .downloaded)
            updateBulkDownloadProgress(
                completedCount: skippedExisting + processedTargets,
                downloadedCount: downloaded,
                totalCount: totalEligible,
                currentTitle: nil
            )
        }

        finalizeBulkDownload(
            downloaded: downloaded,
            skippedExisting: skippedExisting,
            skippedCompleted: skippedCompleted
        )
    }

    private func finalizeBulkDownload(
        downloaded: Int,
        skippedExisting: Int,
        skippedCompleted: Int,
        showSummary: Bool = true
    ) {
        isBulkDownloading = false
        bulkDownloadProgress = nil
        bulkDownloadStartTime = nil
        if showSummary {
            bulkDownloadSummary = BulkDownloadSummary(
                downloadedCount: downloaded,
                skippedAlreadyCachedCount: skippedExisting,
                skippedCompletedCount: skippedCompleted
            )
        }
        refreshCacheStatuses()
    }

    private func updateBulkDownloadProgress(
        completedCount: Int,
        downloadedCount: Int,
        totalCount: Int,
        currentTitle: String?
    ) {
        guard totalCount > 0 else {
            bulkDownloadProgress = nil
            return
        }

        let eta: TimeInterval?
        if let start = bulkDownloadStartTime,
           downloadedCount > 0 {
            let elapsed = Date().timeIntervalSince(start)
            let average = elapsed / Double(downloadedCount)
            let remainingDownloads = max(totalCount - completedCount, 0)
            eta = max(0, average * Double(remainingDownloads))
        } else {
            eta = nil
        }

        bulkDownloadProgress = BulkDownloadProgress(
            completedCount: min(completedCount, totalCount),
            totalCount: totalCount,
            downloadedCount: downloadedCount,
            estimatedRemainingSeconds: eta,
            currentTitle: currentTitle
        )
    }

    private func refreshCacheStatuses() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let updated = await enrichLocalState(for: chapters)
            let sorted = sortChapters(updated)
            chapters = sorted
        }
    }

    private func downloadChapterAssets(for chapter: ChapterSummaryModel, progressHandler: ((Double?) -> Void)? = nil) async throws {
        progressHandler?(0.05)

        try Task.checkCancellation()
        let detail = try await service.fetchChapterDetail(bookID: book.id, chapterID: chapter.id)
        progressHandler?(0.1)
        try Task.checkCancellation()

        guard let audioURL = detail.audioURL else {
            throw BulkDownloadError.audioUnavailable
        }

        try Task.checkCancellation()
        let audioDownload = try await service.downloadAudio(from: audioURL)
        progressHandler?(0.6)
        try Task.checkCancellation()

        var subtitlesContent: String?
        var subtitleFilePath: String?
        var resolvedSubtitleURLString: String?
        var subtitleETag: String?
        if let subtitleURL = detail.subtitlesURL {
            try Task.checkCancellation()
            let payload = try await service.downloadSubtitles(from: subtitleURL)
            subtitlesContent = payload.content
            subtitleFilePath = payload.fileURL.path
            resolvedSubtitleURLString = payload.remoteURL.absoluteString
            subtitleETag = payload.eTag
            try Task.checkCancellation()
        }
        progressHandler?(0.8)

        let metrics = ChapterListViewModel.makeMetrics(
            wordCount: detail.wordCount,
            audioDurationSec: detail.audioDurationSec,
            wordsPerMinute: detail.wordsPerMinute,
            speakingPaceKey: detail.speakingPaceKey
        )

        let cachedChapter = CachedChapter(
            bookID: book.id,
            chapterID: chapter.id,
            chapterTitle: detail.title,
            audioURLString: audioURL.absoluteString,
            subtitlesURLString: detail.subtitlesURL?.absoluteString,
            resolvedAudioURLString: audioDownload.remoteURL.absoluteString,
            resolvedSubtitlesURLString: resolvedSubtitleURLString,
            audioETag: audioDownload.eTag,
            subtitlesETag: subtitleETag,
            localAudioPath: audioDownload.localURL.path,
            localSubtitlePath: subtitleFilePath,
            subtitleContent: subtitlesContent,
            metrics: metrics,
            cachedAt: Date()
        )

        await chapterCache.saveChapter(cachedChapter)
        try Task.checkCancellation()
        progressHandler?(1.0)
    }

    private func performSingleDownload(chapterID: String) async {
        guard let chapter = chapters.first(where: { $0.id == chapterID }) else {
            downloadTasks[chapterID] = nil
            return
        }

        updateChapterDownloadState(chapterID: chapterID, overrideState: .downloading(progress: 0))

        do {
            try await downloadChapterAssets(for: chapter) { [self] progress in
                updateChapterDownloadState(chapterID: chapterID, overrideState: .downloading(progress: progress))
            }

            downloadStates[chapterID] = .downloaded
            updateChapterDownloadState(chapterID: chapterID, overrideState: .downloaded)
            refreshCacheStatuses()
        } catch {
            if error is CancellationError {
                downloadStates[chapterID] = .idle
                updateChapterDownloadState(chapterID: chapterID, overrideState: .idle)
            } else {
                let message = error.localizedDescription
                downloadStates[chapterID] = .failed(message)
                updateChapterDownloadState(chapterID: chapterID, overrideState: .failed(message))
            }
        }

        downloadTasks[chapterID] = nil
    }

    private func applyCacheStatus(_ status: ChapterCacheStatus, to chapter: ChapterSummaryModel) {
        guard let index = chapters.firstIndex(where: { $0.id == chapter.id }) else { return }
        let existing = chapters[index]
        let resolvedState = resolveDownloadState(for: existing.id, cacheStatus: status)
        let updated = ChapterSummaryModel(
            id: existing.id,
            title: existing.title,
            audioAvailable: existing.audioAvailable,
            subtitlesAvailable: existing.subtitlesAvailable,
            metrics: existing.metrics,
            progress: existing.progress,
            cacheStatus: status,
            downloadState: resolvedState
        )

        var newChapters = chapters
        newChapters[index] = updated
        chapters = newChapters
    }

    private func displayTitle(for chapter: ChapterSummaryModel) -> String {
        chapter.displayTitle
    }

    private static func makeMetrics(
        wordCount: Int?,
        audioDurationSec: Double?,
        wordsPerMinute: Double?,
        speakingPaceKey: String?
    ) -> ChapterPlaybackMetrics? {
        ChapterPlaybackMetrics(
            wordCount: wordCount,
            audioDurationSec: audioDurationSec,
            wordsPerMinute: wordsPerMinute,
            speakingPaceKey: speakingPaceKey
        ).normalized
    }

    private func updateChapterDownloadState(chapterID: String, overrideState: ChapterDownloadState?) {
        if let overrideState {
            downloadStates[chapterID] = overrideState
        }

        guard let index = chapters.firstIndex(where: { $0.id == chapterID }) else { return }
        let existing = chapters[index]

        let state: ChapterDownloadState
        if let overrideState {
            state = overrideState
        } else {
            state = resolveDownloadState(for: chapterID, cacheStatus: existing.cacheStatus)
        }

        let updated = ChapterSummaryModel(
            id: existing.id,
            title: existing.title,
            audioAvailable: existing.audioAvailable,
            subtitlesAvailable: existing.subtitlesAvailable,
            metrics: existing.metrics,
            progress: existing.progress,
            cacheStatus: existing.cacheStatus,
            downloadState: state
        )

        chapters[index] = updated
    }

    private func sortChapters(_ chapters: [ChapterSummaryModel]) -> [ChapterSummaryModel] {
        chapters.sorted { lhs, rhs in
            let lhsCompleted = isChapterCompleted(lhs)
            let rhsCompleted = isChapterCompleted(rhs)

            if lhsCompleted != rhsCompleted {
                return !lhsCompleted && rhsCompleted
            }

            let leftIndex = lhs.derivedIndex
            let rightIndex = rhs.derivedIndex

            if let leftIndex, let rightIndex, leftIndex != rightIndex {
                return leftIndex < rightIndex
            }

            if leftIndex != nil, rightIndex == nil {
                return true
            }

            if leftIndex == nil, rightIndex != nil {
                return false
            }

            return lhs.id.localizedStandardCompare(rhs.id) == .orderedAscending
        }
    }

    private func isChapterCompleted(_ chapter: ChapterSummaryModel) -> Bool {
        guard let progress = chapter.progress else { return false }
        if progress.isCompleted { return true }
        return progress.fraction >= 0.999
    }

    private func resolveDownloadState(for chapterID: String, cacheStatus: ChapterCacheStatus) -> ChapterDownloadState {
        if cacheStatus.isComplete {
            downloadStates[chapterID] = .downloaded
            return .downloaded
        }

        if let stored = downloadStates[chapterID] {
            if case .downloaded = stored {
                let reset: ChapterDownloadState = .idle
                downloadStates[chapterID] = reset
                return reset
            }
            return stored
        }

        return .idle
    }

    private func cacheStatus(for chapterID: String) async -> ChapterCacheStatus {
        guard let cached = await chapterCache.cachedChapter(bookID: book.id, chapterID: chapterID) else {
            return .empty
        }

        let audioExists = FileManager.default.fileExists(atPath: cached.localAudioPath)
        let subtitlesExists: Bool
        if let subtitlePath = cached.localSubtitlePath {
            subtitlesExists = FileManager.default.fileExists(atPath: subtitlePath)
        } else {
            subtitlesExists = false
        }

        return ChapterCacheStatus(audioCached: audioExists, subtitlesCached: subtitlesExists)
    }
}
