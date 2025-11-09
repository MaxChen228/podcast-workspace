//
//  APIService.swift
//  audio-earning
//
//  Created by Codex on 2025/10/27.
//

import Foundation

/// Backend API configuration.
struct APIConfiguration {
    static var shared = APIConfiguration()

    private let store: BackendConfigurationStore

    init(store: BackendConfigurationStore = .shared) {
        self.store = store
    }

    var baseURL: URL {
        store.currentEndpoint.url
    }
}

/// Backend book response model.
struct BookResponse: Decodable, Identifiable {
    let id: String
    let title: String
    let coverURL: URL?

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case coverURL = "cover_url"
    }
}

/// Backend chapter summary response model.
struct ChapterResponse: Decodable, Identifiable {
    let id: String
    let title: String
    let audioAvailable: Bool
    let subtitlesAvailable: Bool
    let wordCount: Int?
    let audioDurationSec: Double?
    let wordsPerMinute: Double?
    let speakingPaceKey: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case audioAvailable = "audio_available"
        case subtitlesAvailable = "subtitles_available"
        case wordCount = "word_count"
        case audioDurationSec = "audio_duration_sec"
        case wordsPerMinute = "words_per_minute"
        case speakingPaceKey = "speaking_pace"
    }
}

/// Backend chapter playback response model.
struct ChapterPlaybackResponse: Decodable {
    let id: String
    let title: String
    let audioURL: URL?
    let subtitlesURL: URL?
    let wordCount: Int?
    let audioDurationSec: Double?
    let wordsPerMinute: Double?
    let speakingPaceKey: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case audioURL = "audio_url"
        case subtitlesURL = "subtitles_url"
        case wordCount = "word_count"
        case audioDurationSec = "audio_duration_sec"
        case wordsPerMinute = "words_per_minute"
        case speakingPaceKey = "speaking_pace"
    }
}

private struct TranslationRequestPayload: Encodable {
    let text: String
    let targetLanguageCode: String
    let sourceLanguageCode: String?
    let bookID: String
    let chapterID: String
    let subtitleID: Int?

    private enum CodingKeys: String, CodingKey {
        case text
        case targetLanguageCode = "target_language_code"
        case sourceLanguageCode = "source_language_code"
        case bookID = "book_id"
        case chapterID = "chapter_id"
        case subtitleID = "subtitle_id"
    }
}

struct TranslationResponsePayload: Decodable {
    let translatedText: String
    let detectedSourceLanguage: String?
    let cached: Bool

    private enum CodingKeys: String, CodingKey {
        case translatedText = "translated_text"
        case detectedSourceLanguage = "detected_source_language"
        case cached
    }
}

private struct SentenceExplanationRequestPayload: Encodable {
    let sentence: String
    let previousSentence: String
    let nextSentence: String
    let language: String

    private enum CodingKeys: String, CodingKey {
        case sentence
        case previousSentence = "previous_sentence"
        case nextSentence = "next_sentence"
        case language
    }
}

private struct PhraseExplanationRequestPayload: Encodable {
    let phrase: String
    let sentence: String
    let previousSentence: String?
    let nextSentence: String?
    let language: String

    private enum CodingKeys: String, CodingKey {
        case phrase
        case sentence
        case previousSentence = "previous_sentence"
        case nextSentence = "next_sentence"
        case language
    }
}

struct SentenceExplanationVocabularyPayload: Decodable, Identifiable, Equatable {
    let id = UUID()
    let word: String
    let meaning: String
    let note: String?

    private enum CodingKeys: String, CodingKey {
        case word
        case meaning
        case note
    }
}

struct SentenceExplanationResponsePayload: Decodable, Equatable {
    let overview: String
    let keyPoints: [String]
    let vocabulary: [SentenceExplanationVocabularyPayload]
    let chineseMeaning: String?
    let cached: Bool

    private enum CodingKeys: String, CodingKey {
        case overview
        case keyPoints = "key_points"
        case vocabulary
        case chineseMeaning = "chinese_meaning"
        case cached
    }
}

enum APIServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingFailed
    case fileWriteFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Malformed server response"
        case .httpError(let code):
            return "Server returned status code: \(code)"
        case .decodingFailed:
            return "Failed to decode server response"
        case .fileWriteFailed:
            return "Failed to write file"
        }
    }
}

struct AudioDownload: Equatable {
    let localURL: URL
    let remoteURL: URL
    let eTag: String?
}

struct SubtitleDownload: Equatable {
    let content: String
    let fileURL: URL
    let remoteURL: URL
    let eTag: String?
}

private struct RemoteFileMetadata {
    let resolvedURL: URL
    let eTag: String?
}

/// Service responsible for talking to the FastAPI backend.
final class APIService {
    static let shared = APIService()

    private let session: URLSession
    private let fileManager: FileManager
    private let cacheDirectory: URL

    init(session: URLSession = .shared, fileManager: FileManager = .default) {
        self.session = session
        self.fileManager = fileManager
        self.cacheDirectory = fileManager.temporaryDirectory.appendingPathComponent("audio-cache", isDirectory: true)

        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }

    // MARK: - Public APIs

    static func normalizedMediaURL(from url: URL) -> URL {
        guard let scheme = url.scheme?.lowercased() else {
            return url
        }

        if scheme == "gs" {
            let bucket = url.host ?? ""
            let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            var components = URLComponents()
            components.scheme = "https"
            components.host = "storage.googleapis.com"
            components.path = "/" + [bucket, path].filter { !$0.isEmpty }.joined(separator: "/")
            return components.url ?? url
        }

        return url
    }

    func checkHealth(at baseURL: URL) async throws {
        let url = baseURL.appendingPathComponent("health")
        let (_, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        guard 200..<300 ~= http.statusCode else {
            throw APIServiceError.httpError(http.statusCode)
        }
    }

    func fetchBooks() async throws -> [BookResponse] {
        let url = APIConfiguration.shared.baseURL.appendingPathComponent("books")
        return try await request(url)
    }

    func fetchChapters(bookID: String) async throws -> [ChapterResponse] {
        let url = APIConfiguration.shared.baseURL
            .appendingPathComponent("books")
            .appendingPathComponent(bookID)
            .appendingPathComponent("chapters")
        return try await request(url)
    }

    func fetchChapterDetail(bookID: String, chapterID: String) async throws -> ChapterPlaybackResponse {
        let url = APIConfiguration.shared.baseURL
            .appendingPathComponent("books")
            .appendingPathComponent(bookID)
            .appendingPathComponent("chapters")
            .appendingPathComponent(chapterID)
        return try await request(url)
    }

    func translateSentence(
        bookID: String,
        chapterID: String,
        subtitleID: Int?,
        text: String,
        targetLanguageCode: String,
        sourceLanguageCode: String? = nil
    ) async throws -> TranslationResponsePayload {
        let url = APIConfiguration.shared.baseURL.appendingPathComponent("translations")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let payload = TranslationRequestPayload(
            text: text,
            targetLanguageCode: targetLanguageCode,
            sourceLanguageCode: sourceLanguageCode,
            bookID: bookID,
            chapterID: chapterID,
            subtitleID: subtitleID
        )

        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        guard 200..<300 ~= http.statusCode else {
            throw APIServiceError.httpError(http.statusCode)
        }

        do {
            return try JSONDecoder().decode(TranslationResponsePayload.self, from: data)
        } catch {
            throw APIServiceError.decodingFailed
        }
    }

    func explainSentence(
        sentence: String,
        previousSentence: String,
        nextSentence: String,
        language: String
    ) async throws -> SentenceExplanationResponsePayload {
        let url = APIConfiguration.shared.baseURL
            .appendingPathComponent("explain")
            .appendingPathComponent("sentence")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let payload = SentenceExplanationRequestPayload(
            sentence: sentence,
            previousSentence: previousSentence,
            nextSentence: nextSentence,
            language: language
        )

        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        guard 200..<300 ~= http.statusCode else {
            throw APIServiceError.httpError(http.statusCode)
        }

        do {
            return try JSONDecoder().decode(SentenceExplanationResponsePayload.self, from: data)
        } catch {
            throw APIServiceError.decodingFailed
        }
    }

    func explainPhrase(
        phrase: String,
        sentence: String,
        previousSentence: String?,
        nextSentence: String?,
        language: String
    ) async throws -> SentenceExplanationResponsePayload {
        let url = APIConfiguration.shared.baseURL
            .appendingPathComponent("explain")
            .appendingPathComponent("phrase")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let payload = PhraseExplanationRequestPayload(
            phrase: phrase,
            sentence: sentence,
            previousSentence: previousSentence,
            nextSentence: nextSentence,
            language: language
        )

        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        guard 200..<300 ~= http.statusCode else {
            throw APIServiceError.httpError(http.statusCode)
        }

        do {
            return try JSONDecoder().decode(SentenceExplanationResponsePayload.self, from: data)
        } catch {
            throw APIServiceError.decodingFailed
        }
    }

    /// Remove all locally cached audio and subtitle files.
    @discardableResult
    func clearMediaCache() throws -> Int {
        var removedItems = 0

        if fileManager.fileExists(atPath: cacheDirectory.path) {
            let existing = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            removedItems = existing.count
            try fileManager.removeItem(at: cacheDirectory)
        }

        try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        return removedItems
    }

    /// Download audio and return the cached local URL plus metadata.
    func downloadAudio(from originalURL: URL) async throws -> AudioDownload {
        let normalizedURL = Self.normalizedMediaURL(from: originalURL)
        let legacyDestination = cachedFileURL(for: normalizedURL)

        let metadata = await fetchRemoteMetadata(for: normalizedURL)
        let resolvedURL = metadata?.resolvedURL ?? normalizedURL

        var destination = cachedFileURL(for: resolvedURL)
        if destination != legacyDestination,
           fileManager.fileExists(atPath: legacyDestination.path),
           !fileManager.fileExists(atPath: destination.path) {
            destination = legacyDestination
        }

        var metaURL = destination.appendingPathExtension("etag")
        let hasLocalFile = fileManager.fileExists(atPath: destination.path)
        let storedETag = (try? String(contentsOf: metaURL, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines)
        let remoteETag = metadata?.eTag

        if hasLocalFile {
            if let remoteETag, let storedETag, storedETag == remoteETag {
                return AudioDownload(localURL: destination, remoteURL: resolvedURL, eTag: remoteETag)
            }

            if remoteETag == nil, isFileFresh(at: destination, ttl: CachePolicy.mediaTTL) {
                return AudioDownload(localURL: destination, remoteURL: resolvedURL, eTag: nil)
            }
        }

#if DEBUG
        print("⬇️ Downloading audio again: \(resolvedURL.lastPathComponent)")
#endif

        let (tempURL, response) = try await session.download(from: normalizedURL)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw APIServiceError.invalidResponse
        }

        let finalURL = http.url ?? resolvedURL
        var finalDestination = cachedFileURL(for: finalURL)
        if finalDestination != destination {
            if fileManager.fileExists(atPath: finalDestination.path) {
                try? fileManager.removeItem(at: finalDestination)
            }
        } else {
            finalDestination = destination
        }

        do {
            if fileManager.fileExists(atPath: finalDestination.path) {
                try fileManager.removeItem(at: finalDestination)
            }
            try fileManager.moveItem(at: tempURL, to: finalDestination)
        } catch {
            throw APIServiceError.fileWriteFailed
        }

        let finalETag = http.value(forHTTPHeaderField: "ETag") ?? metadata?.eTag
        metaURL = finalDestination.appendingPathExtension("etag")
        if let finalETag {
            try finalETag.write(to: metaURL, atomically: true, encoding: .utf8)
        } else {
            try? fileManager.removeItem(at: metaURL)
        }

        if destination != finalDestination,
           destination != legacyDestination {
            try? fileManager.removeItem(at: destination)
            try? fileManager.removeItem(at: destination.appendingPathExtension("etag"))
        }

        return AudioDownload(localURL: finalDestination, remoteURL: finalURL, eTag: finalETag)
    }

    /// Download SRT subtitles and return both text and cached file URL.
    func downloadSubtitles(from originalURL: URL) async throws -> SubtitleDownload {
        let normalizedURL = Self.normalizedMediaURL(from: originalURL)
        let legacyDestination = cachedTextURL(for: normalizedURL)

        let metadata = await fetchRemoteMetadata(for: normalizedURL)
        let resolvedURL = metadata?.resolvedURL ?? normalizedURL

        var destination = cachedTextURL(for: resolvedURL)
        if destination != legacyDestination,
           fileManager.fileExists(atPath: legacyDestination.path),
           !fileManager.fileExists(atPath: destination.path) {
            destination = legacyDestination
        }

        var metaURL = destination.appendingPathExtension("etag")
        let hasCachedSubtitle = fileManager.fileExists(atPath: destination.path)
        let storedETag = (try? String(contentsOf: metaURL, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines)
        let remoteETag = metadata?.eTag

        if hasCachedSubtitle,
           let cached = try? String(contentsOf: destination, encoding: .utf8) {
            if let remoteETag, let storedETag, storedETag == remoteETag {
#if DEBUG
                print("🔁 Using cached subtitles: \(resolvedURL.lastPathComponent)")
#endif
                return SubtitleDownload(content: cached, fileURL: destination, remoteURL: resolvedURL, eTag: remoteETag)
            }

            if remoteETag == nil, isFileFresh(at: destination, ttl: CachePolicy.mediaTTL) {
#if DEBUG
                print("[cache] Using TTL-fresh subtitles: \(resolvedURL.lastPathComponent)")
#endif
                return SubtitleDownload(content: cached, fileURL: destination, remoteURL: resolvedURL, eTag: nil)
            }
        }

#if DEBUG
        print("⬇️ Downloading subtitles again: \(resolvedURL.lastPathComponent)")
#endif

        var request = URLRequest(url: normalizedURL)
        request.setValue("text/plain", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw APIServiceError.invalidResponse
        }

        guard let content = String(data: data, encoding: .utf8) else {
            throw APIServiceError.decodingFailed
        }

        let finalURL = http.url ?? resolvedURL
        var finalDestination = cachedTextURL(for: finalURL)
        if finalDestination != destination,
           fileManager.fileExists(atPath: destination.path) {
            try? fileManager.removeItem(at: finalDestination)
        } else {
            finalDestination = destination
        }

        do {
            try content.write(to: finalDestination, atomically: true, encoding: .utf8)
        } catch {
            throw APIServiceError.fileWriteFailed
        }

        let finalETag = http.value(forHTTPHeaderField: "ETag") ?? metadata?.eTag
        metaURL = finalDestination.appendingPathExtension("etag")
        if let finalETag {
            try finalETag.write(to: metaURL, atomically: true, encoding: .utf8)
        } else {
            try? fileManager.removeItem(at: metaURL)
        }

        if destination != finalDestination,
           destination != legacyDestination {
            try? fileManager.removeItem(at: destination)
            try? fileManager.removeItem(at: destination.appendingPathExtension("etag"))
        }

        return SubtitleDownload(content: content, fileURL: finalDestination, remoteURL: finalURL, eTag: finalETag)
    }

    // MARK: - Private helpers

    private func request<T: Decodable>(_ url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        guard 200..<300 ~= http.statusCode else {
            throw APIServiceError.httpError(http.statusCode)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIServiceError.decodingFailed
        }
    }

    private func cachedFileURL(for remoteURL: URL) -> URL {
        let forbiddenCharacters: CharacterSet = {
            var set = CharacterSet.alphanumerics.inverted
            set.remove(charactersIn: "._-")
            return set
        }()

        let sanitized = remoteURL.absoluteString
            .components(separatedBy: forbiddenCharacters)
            .filter { !$0.isEmpty }
            .joined(separator: "_")

        return cacheDirectory.appendingPathComponent(sanitized)
    }

    private func cachedTextURL(for remoteURL: URL) -> URL {
        cachedFileURL(for: remoteURL).appendingPathExtension("srt")
    }

    private func fetchRemoteMetadata(for url: URL) async -> RemoteFileMetadata? {
        if let head = await performMetadataRequest(url: url, method: "HEAD", headers: [:]) {
            return head
        }

        let headers = [
            "Range": "bytes=0-0",
            "Accept-Encoding": "identity"
        ]
        return await performMetadataRequest(url: url, method: "GET", headers: headers)
    }

    private func performMetadataRequest(url: URL, method: String, headers: [String: String]) async -> RemoteFileMetadata? {
        var request = URLRequest(url: url)
        request.httpMethod = method
        headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return nil
            }

            guard (200..<400).contains(http.statusCode) else {
                return nil
            }

            let finalURL = http.url ?? url
            if let etag = http.value(forHTTPHeaderField: "ETag")?.trimmingCharacters(in: .whitespacesAndNewlines), !etag.isEmpty {
                return RemoteFileMetadata(resolvedURL: finalURL, eTag: etag)
            }

            if let generation = http.value(forHTTPHeaderField: "x-goog-generation")?.trimmingCharacters(in: .whitespacesAndNewlines), !generation.isEmpty {
                return RemoteFileMetadata(resolvedURL: finalURL, eTag: generation)
            }

            return RemoteFileMetadata(resolvedURL: finalURL, eTag: nil)
        } catch {
            return nil
        }
    }

    func isFileFresh(at url: URL, ttl: TimeInterval) -> Bool {
        guard ttl > 0 else { return false }
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let modified = attributes[.modificationDate] as? Date else {
            return false
        }
        return Date().timeIntervalSince(modified) <= ttl
    }
}
