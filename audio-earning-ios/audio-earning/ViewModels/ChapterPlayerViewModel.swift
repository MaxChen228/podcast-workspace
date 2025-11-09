//
//  ChapterPlayerViewModel.swift
//  audio-earning
//
//  Created by Codex on 2025/10/27.
//

import Foundation

@MainActor
final class ChapterPlayerViewModel: ObservableObject {
    struct ChapterPlaybackPayload: Equatable {
        let localAudioURL: URL
        let subtitleContent: String?
        let metrics: ChapterPlaybackMetrics?
        let progress: ChapterProgress?
    }

    private struct CachedChapterResult {
        let payload: ChapterPlaybackPayload
        let title: String
    }

    enum State: Equatable {
        case idle
        case loading(cached: ChapterPlaybackPayload?, message: String)
        case ready(payload: ChapterPlaybackPayload, offlineNotice: String?)
        case noAudio
        case error(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var resolvedTitle: String

    let book: Book
    let chapter: ChapterSummaryModel

    private let service: APIServiceProtocol
    private let fileManager: FileManager
    private let chapterCache: ChapterCaching
    private let progressStore: ListeningProgressManaging
    private var hasLoaded = false
    private var networkTask: Task<Void, Never>?
    private var hasCommittedToCached = false
    private let cacheTTL = CachePolicy.chapterPayloadTTL

    init(
        book: Book,
        chapter: ChapterSummaryModel,
        service: APIServiceProtocol = APIService.shared,
        chapterCache: ChapterCaching = ChapterCacheStore.shared,
        progressStore: ListeningProgressManaging = ListeningProgressStore.shared,
        fileManager: FileManager = .default
    ) {
        self.book = book
        self.chapter = chapter
        self.service = service
        self.chapterCache = chapterCache
        self.progressStore = progressStore
        self.fileManager = fileManager
        self.resolvedTitle = chapter.displayTitle
    }

    deinit {
        networkTask?.cancel()
    }

    func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        hasCommittedToCached = false
        networkTask?.cancel()
        networkTask = nil

        Task { [weak self] in
            await self?.prepareAndStartLoading(skipCache: false)
        }
    }

    func retry() {
        networkTask?.cancel()
        networkTask = nil
        hasCommittedToCached = false
        hasLoaded = false
        loadIfNeeded()
    }

    func useCachedChapter() {
        guard case .loading(let cached?, _) = state else { return }
        hasCommittedToCached = true
        networkTask?.cancel()
        networkTask = nil
        state = .ready(payload: cached, offlineNotice: "已切換至本地快取")
    }

    func reloadChapter() {
        networkTask?.cancel()
        networkTask = nil
        hasLoaded = false
        hasCommittedToCached = false
        state = .loading(cached: nil, message: "重新下載中…")

        Task { [weak self] in
            guard let self else { return }
            await self.clearLocalChapterData()
            await self.prepareAndStartLoading(skipCache: true, overrideMessage: "重新下載中…")
        }
    }

    private func prepareAndStartLoading(skipCache: Bool, overrideMessage: String? = nil) async {
        hasCommittedToCached = false

        let freshCache = skipCache ? nil : await cachedChapterPayload(maxAge: cacheTTL)
        let staleCache: CachedChapterResult?
        if skipCache {
            staleCache = nil
        } else if let freshCache {
            staleCache = freshCache
        } else {
            staleCache = await cachedChapterPayload(maxAge: nil)
        }

        if let freshCache {
            resolvedTitle = freshCache.title
            state = .ready(payload: freshCache.payload, offlineNotice: nil)
            startNetworkTask(forceRemote: false)
            return
        }

        if let staleCache {
            resolvedTitle = staleCache.title
        } else {
            resolvedTitle = chapter.displayTitle
        }

        let message = overrideMessage ?? (staleCache == nil ? "尚未有本地快取，正在連線…" : "正在嘗試更新最新內容…")
        state = .loading(cached: staleCache?.payload, message: message)

        startNetworkTask(forceRemote: true)
    }

    private func startNetworkTask(forceRemote: Bool) {
        networkTask?.cancel()
        networkTask = Task { [weak self] in
            await self?.loadChapter(forceRemote: forceRemote)
        }
    }

    private func loadChapter(forceRemote: Bool) async {
        defer { networkTask = nil }

        if !forceRemote {
            let hasFreshCache = (await chapterCache.freshChapter(bookID: book.id, chapterID: chapter.id, ttl: cacheTTL)) != nil
            if hasFreshCache {
                return
            }
        }

        do {
            let detail = try await service.fetchChapterDetail(bookID: book.id, chapterID: chapter.id)
            if Task.isCancelled { return }

            resolvedTitle = ChapterNameParser.displayTitle(id: detail.id, title: detail.title)

            guard let audioURL = detail.audioURL else {
                state = .noAudio
                await chapterCache.removeChapter(bookID: book.id, chapterID: chapter.id)
                return
            }

            let audioDownload = try await service.downloadAudio(from: audioURL)
            if Task.isCancelled { return }

            var subtitlesContent: String?
            var subtitleFilePath: String?
            var resolvedSubtitleURLString: String?
            var subtitleETag: String?
            if let subtitleURL = detail.subtitlesURL {
                if let payload = try? await service.downloadSubtitles(from: subtitleURL), !Task.isCancelled {
                    subtitlesContent = payload.content
                    subtitleFilePath = payload.fileURL.path
                    resolvedSubtitleURLString = payload.remoteURL.absoluteString
                    subtitleETag = payload.eTag
                }
            }

            let metrics = ChapterPlaybackMetrics(
                wordCount: detail.wordCount,
                audioDurationSec: detail.audioDurationSec,
                wordsPerMinute: detail.wordsPerMinute,
                speakingPaceKey: detail.speakingPaceKey
            ).normalized

            let progress = await progressStore.progress(bookID: book.id, chapterID: chapter.id)
            if Task.isCancelled { return }

            let payload = ChapterPlaybackPayload(
                localAudioURL: audioDownload.localURL,
                subtitleContent: subtitlesContent,
                metrics: metrics,
                progress: progress
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

            guard !hasCommittedToCached else { return }

            state = .ready(payload: payload, offlineNotice: nil)
        } catch {
            if error is CancellationError {
                return
            }

            if let cached = await cachedChapterPayload(maxAge: nil) {
                if hasCommittedToCached {
                    if case .ready(let payload, _) = state {
                        state = .ready(payload: payload, offlineNotice: "無法連線，已使用本地快取。")
                    }
                    return
                }

                resolvedTitle = cached.title
                hasCommittedToCached = true
                state = .ready(payload: cached.payload, offlineNotice: "無法連線，已使用本地快取。")
                return
            }

            state = .error(error.localizedDescription)
        }
    }

    private func cachedChapterPayload(maxAge: TimeInterval?) async -> CachedChapterResult? {
        let cachedChapter: CachedChapter?
        if let maxAge {
        cachedChapter = await chapterCache.freshChapter(bookID: book.id, chapterID: chapter.id, ttl: maxAge)
        } else {
        cachedChapter = await chapterCache.cachedChapter(bookID: book.id, chapterID: chapter.id)
        }

        guard let cached = cachedChapter else {
            return nil
        }

        guard FileManager.default.fileExists(atPath: cached.localAudioPath) else {
            return nil
        }

        var subtitleContent = cached.subtitleContent
        if let subtitlePath = cached.localSubtitlePath,
           FileManager.default.fileExists(atPath: subtitlePath),
           let cachedText = try? String(contentsOf: URL(fileURLWithPath: subtitlePath), encoding: .utf8) {
            subtitleContent = cachedText
        }

        let normalizedMetrics = cached.metrics.flatMap { $0.normalized } ?? chapter.metrics
        let progress = await progressStore.progress(bookID: book.id, chapterID: chapter.id)

        let payload = ChapterPlaybackPayload(
            localAudioURL: cached.localAudioURL,
            subtitleContent: subtitleContent,
            metrics: normalizedMetrics,
            progress: progress
        )

        let displayTitle = ChapterNameParser.displayTitle(id: cached.chapterID, title: cached.chapterTitle)

        return CachedChapterResult(payload: payload, title: displayTitle)
    }

    private func clearLocalChapterData() async {
        if let cached = await chapterCache.cachedChapter(bookID: book.id, chapterID: chapter.id) {
            let audioURL = cached.localAudioURL
            if fileManager.fileExists(atPath: audioURL.path) {
                try? fileManager.removeItem(at: audioURL)
            }

            let audioMetaURL = audioURL.appendingPathExtension("etag")
            if fileManager.fileExists(atPath: audioMetaURL.path) {
                try? fileManager.removeItem(at: audioMetaURL)
            }

            if let subtitlePath = cached.localSubtitlePath {
                let subtitleURL = URL(fileURLWithPath: subtitlePath)
                if fileManager.fileExists(atPath: subtitleURL.path) {
                    try? fileManager.removeItem(at: subtitleURL)
                }

                let subtitleMetaURL = subtitleURL.appendingPathExtension("etag")
                if fileManager.fileExists(atPath: subtitleMetaURL.path) {
                    try? fileManager.removeItem(at: subtitleMetaURL)
                }
            }
        }

        await chapterCache.removeChapter(bookID: book.id, chapterID: chapter.id)
        await progressStore.clear(bookID: book.id, chapterID: chapter.id)
    }

    var isWorking: Bool {
        if case .loading = state {
            return true
        }
        return false
    }
}
