//
//  ChapterCacheStore.swift
//  audio-earning
//
//  Created by Claude on 2025/10/28.
//

import Foundation

struct CachedChapter: Codable, Equatable {
    let bookID: String
    let chapterID: String
    let chapterTitle: String
    let audioURLString: String
    let subtitlesURLString: String?
    let resolvedAudioURLString: String?
    let resolvedSubtitlesURLString: String?
    let audioETag: String?
    let subtitlesETag: String?
    let localAudioPath: String
    let localSubtitlePath: String?
    let subtitleContent: String?
    let metrics: ChapterPlaybackMetrics?
    let cachedAt: Date

    var localAudioURL: URL {
        URL(fileURLWithPath: localAudioPath)
    }

    var remoteAudioURL: URL? {
        URL(string: audioURLString)
    }

    var remoteSubtitleURL: URL? {
        guard let subtitlesURLString else { return nil }
        return URL(string: subtitlesURLString)
    }

    var resolvedAudioURL: URL? {
        if let resolvedAudioURLString {
            return URL(string: resolvedAudioURLString)
        }
        return remoteAudioURL
    }

    var resolvedSubtitleURL: URL? {
        if let resolvedSubtitlesURLString {
            return URL(string: resolvedSubtitlesURLString)
        }
        return remoteSubtitleURL
    }
}

actor ChapterCacheStore {
    static let shared = ChapterCacheStore()

    private var cache: [String: CachedChapter] = [:]
    private let storeURL: URL
    private let fileManager: FileManager

    private init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let supportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = supportDir.appendingPathComponent("chapter-cache", isDirectory: true)
        if !fileManager.fileExists(atPath: folder.path) {
            try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        self.storeURL = folder.appendingPathComponent("chapters.json")
        self.cache = Self.readCache(from: storeURL, fileManager: fileManager)
    }

    private func cacheKey(bookID: String, chapterID: String) -> String {
        "\(bookID)#\(chapterID)"
    }

    func cachedChapter(bookID: String, chapterID: String) -> CachedChapter? {
        cache[cacheKey(bookID: bookID, chapterID: chapterID)]
    }

    func freshChapter(bookID: String, chapterID: String, ttl: TimeInterval) -> CachedChapter? {
        guard let cached = cachedChapter(bookID: bookID, chapterID: chapterID) else { return nil }
        guard Date().timeIntervalSince(cached.cachedAt) <= ttl else { return nil }
        return cached
    }

    func saveChapter(_ chapter: CachedChapter) {
        cache[cacheKey(bookID: chapter.bookID, chapterID: chapter.chapterID)] = chapter
        persist()
    }

    func removeChapter(bookID: String, chapterID: String) {
        cache.removeValue(forKey: cacheKey(bookID: bookID, chapterID: chapterID))
        persist()
    }

    func clearAll() {
        cache.removeAll()
        persist()
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(cache)
            try data.write(to: storeURL, options: .atomic)
        } catch {
            // Ignore persisting errors in release; cache will repopulate next time.
#if DEBUG
            print("⚠️ Failed to persist chapter cache: \(error.localizedDescription)")
#endif
        }
    }

    private static func readCache(from url: URL, fileManager: FileManager) -> [String: CachedChapter] {
        guard fileManager.fileExists(atPath: url.path) else { return [:] }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([String: CachedChapter].self, from: data)
        } catch {
            return [:]
        }
    }
}
