//
//  ServiceProtocols.swift
//  audio-earning
//
//  Created by Codex on 2025/11/05.
//

import Foundation

/// Abstracts the network layer for dependency injection and testing.
protocol APIServiceProtocol: AnyObject {
    func checkHealth(at baseURL: URL) async throws
    func fetchBooks() async throws -> [BookResponse]
    func fetchChapters(bookID: String) async throws -> [ChapterResponse]
    func fetchChapterDetail(bookID: String, chapterID: String) async throws -> ChapterPlaybackResponse
    func translateSentence(
        bookID: String,
        chapterID: String,
        subtitleID: Int?,
        text: String,
        targetLanguageCode: String,
        sourceLanguageCode: String?
    ) async throws -> TranslationResponsePayload
    func explainSentence(
        sentence: String,
        previousSentence: String,
        nextSentence: String,
        language: String
    ) async throws -> SentenceExplanationResponsePayload
    func explainPhrase(
        phrase: String,
        sentence: String,
        previousSentence: String?,
        nextSentence: String?,
        language: String
    ) async throws -> SentenceExplanationResponsePayload
    func downloadAudio(from originalURL: URL) async throws -> AudioDownload
    func downloadSubtitles(from originalURL: URL) async throws -> SubtitleDownload
    @discardableResult
    func clearMediaCache() throws -> Int

    func submitPodcastJob(_ payload: PodcastJobCreatePayload) async throws -> PodcastJob
    func fetchPodcastJobs(statuses: [PodcastJobStatus]?) async throws -> PodcastJobListResponse
}

protocol NewsServiceProtocol: AnyObject {
    func fetchHeadlines(category: String?, market: String?, count: Int?, forceRefresh: Bool) async throws -> NewsFeed
    func searchNews(query: String, market: String?, count: Int?, forceRefresh: Bool) async throws -> NewsFeed
    func log(event: NewsEventPayload) async
}

protocol NewsPreferenceStoring: AnyObject {
    var market: String { get set }
    var lastCategory: String? { get set }
}

/// Persists and retrieves backend endpoint configurations.
protocol BackendConfigurationStoring: AnyObject {
    var endpoints: [BackendEndpoint] { get }
    var currentEndpoint: BackendEndpoint { get }

    @discardableResult
    func addOrUpdateEndpoint(name: String, url: URL, select: Bool) -> BackendEndpoint
    func updateEndpoint(id: UUID, name: String, url: URL) -> BackendEndpoint?
    func selectEndpoint(id: UUID)
    func deleteEndpoint(id: UUID)
    func canDeleteEndpoint(_ endpoint: BackendEndpoint) -> Bool
    func exportConfiguration() -> (endpoints: [BackendEndpoint], activeID: UUID?)
    func importConfiguration(endpoints: [BackendEndpoint], activeID: UUID?)
}

/// Coordinates cache maintenance tasks.
protocol CacheManaging: AnyObject {
    @discardableResult
    func clearAllCaches() async throws -> CacheClearSummary
}

protocol ChapterListCaching: AnyObject {
    func save(bookID: String, chapters: [CachedChapterSummary]) async
    func list(for bookID: String) async -> CachedChapterList?
    func freshList(for bookID: String, ttl: TimeInterval) async -> CachedChapterList?
    func clear(bookID: String) async
    func clearAll() async
}

protocol ChapterCaching: AnyObject {
    func cachedChapter(bookID: String, chapterID: String) async -> CachedChapter?
    func freshChapter(bookID: String, chapterID: String, ttl: TimeInterval) async -> CachedChapter?
    func saveChapter(_ chapter: CachedChapter) async
    func removeChapter(bookID: String, chapterID: String) async
    func clearAll() async
}

protocol ListeningProgressManaging: AnyObject {
    func progress(bookID: String, chapterID: String) async -> ChapterProgress?
    func saveProgress(bookID: String, chapterID: String, position: Double, duration: Double?, completed: Bool) async
    func clear(bookID: String, chapterID: String) async
    func clearAll() async
}

@MainActor
protocol SavedLexiconStoring: AnyObject {
    var entries: [SavedLexiconEntry] { get }
    func add(_ entry: SavedLexiconEntry)
    func remove(_ id: UUID)
    func clearAll()
    func exportEntries() -> [SavedLexiconEntry]
    func importEntries(_ newEntries: [SavedLexiconEntry])
}

protocol SubtitleAppearancePersisting: AnyObject {
    func load() -> SubtitleAppearance
    func save(_ appearance: SubtitleAppearance)
}

extension BackendConfigurationStoring {
    @discardableResult
    func addOrUpdateEndpoint(name: String, url: URL) -> BackendEndpoint {
        addOrUpdateEndpoint(name: name, url: url, select: true)
    }
}

extension APIService: APIServiceProtocol {}
extension BackendConfigurationStore: BackendConfigurationStoring {}
extension CacheManager: CacheManaging {}
extension ChapterListCacheStore: ChapterListCaching {}
extension ChapterCacheStore: ChapterCaching {}
extension ListeningProgressStore: ListeningProgressManaging {}
extension SavedLexiconStore: SavedLexiconStoring {}
extension SubtitleAppearanceStore: SubtitleAppearancePersisting {}
