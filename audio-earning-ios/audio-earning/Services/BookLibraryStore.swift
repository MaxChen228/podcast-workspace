//
//  BookLibraryStore.swift
//  audio-earning
//
//  Created by Codex on 2025/11/09.
//

import Foundation

extension Notification.Name {
    static let bookLibraryDidChange = Notification.Name("BookLibraryDidChangeNotification")
}

protocol BookLibraryStoring: AnyObject {
    func allBooks() async -> [LibraryBookRecord]
    func record(for bookID: String) async -> LibraryBookRecord?
    func addOrUpdate(_ record: LibraryBookRecord) async
    func remove(bookID: String) async
    func contains(bookID: String) async -> Bool
}

actor BookLibraryStore: BookLibraryStoring {
    static let shared = BookLibraryStore()

    private let fileManager: FileManager
    private let storeURL: URL
    private var cache: [String: LibraryBookRecord] = [:]

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let supportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        let folder = supportDir.appendingPathComponent("BookLibrary", isDirectory: true)
        if !fileManager.fileExists(atPath: folder.path) {
            try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        self.storeURL = folder.appendingPathComponent("library.json")
        self.cache = Self.loadCache(from: storeURL, fileManager: fileManager)
    }

    func allBooks() async -> [LibraryBookRecord] {
        cache.values.sorted { $0.addedAt > $1.addedAt }
    }

    func record(for bookID: String) async -> LibraryBookRecord? {
        cache[bookID]
    }

    func addOrUpdate(_ record: LibraryBookRecord) async {
        cache[record.id] = record
        persist()
        notifyChange()
    }

    func remove(bookID: String) async {
        cache.removeValue(forKey: bookID)
        persist()
        notifyChange()
    }

    func contains(bookID: String) async -> Bool {
        cache[bookID] != nil
    }

    private func notifyChange() {
        Task { @MainActor in
            NotificationCenter.default.post(name: .bookLibraryDidChange, object: nil)
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(cache)
            try data.write(to: storeURL, options: .atomic)
        } catch {
#if DEBUG
            print("⚠️ Failed to persist library store: \(error.localizedDescription)")
#endif
        }
    }

    private static func loadCache(from url: URL, fileManager: FileManager) -> [String: LibraryBookRecord] {
        guard fileManager.fileExists(atPath: url.path) else { return [:] }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([String: LibraryBookRecord].self, from: data)
        } catch {
            return [:]
        }
    }
}

