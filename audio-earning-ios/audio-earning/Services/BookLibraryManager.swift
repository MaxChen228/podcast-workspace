//
//  BookLibraryManager.swift
//  audio-earning
//
//  Created by Codex on 2025/11/09.
//

import Foundation

protocol BookLibraryManaging: AnyObject {
    func loadLibraryBooks() async -> [LibraryBookRecord]
    func addBookToLibrary(book: BookResponse) async throws
    func removeBookFromLibrary(bookID: String) async
    func isBookInLibrary(_ bookID: String) async -> Bool
    func refreshBookMetadata(bookID: String) async
}

final class BookLibraryManager: BookLibraryManaging {
    private let libraryStore: BookLibraryStoring
    private let apiService: APIServiceProtocol

    init(
        libraryStore: BookLibraryStoring = BookLibraryStore.shared,
        apiService: APIServiceProtocol = APIService.shared
    ) {
        self.libraryStore = libraryStore
        self.apiService = apiService
    }

    func loadLibraryBooks() async -> [LibraryBookRecord] {
        await libraryStore.allBooks()
    }

    func addBookToLibrary(book: BookResponse) async throws {
        let chapters = try await apiService.fetchChapters(bookID: book.id)
        let existing = await libraryStore.record(for: book.id)
        let addedAt = existing?.addedAt ?? Date()
        let records = chapters.map { response in
            LibraryChapterRecord(
                id: response.id,
                title: response.title,
                audioAvailable: response.audioAvailable,
                subtitlesAvailable: response.subtitlesAvailable,
                metrics: ChapterPlaybackMetrics(
                    wordCount: response.wordCount,
                    audioDurationSec: response.audioDurationSec,
                    wordsPerMinute: response.wordsPerMinute,
                    speakingPaceKey: response.speakingPaceKey
                ).normalized
            )
        }

        let record = LibraryBookRecord(
            id: book.id,
            title: book.title,
            coverURLString: book.coverURL?.absoluteString,
            addedAt: addedAt,
            lastSyncedAt: Date(),
            chapters: records
        )
        await libraryStore.addOrUpdate(record)
    }

    func removeBookFromLibrary(bookID: String) async {
        await libraryStore.remove(bookID: bookID)
    }

    func isBookInLibrary(_ bookID: String) async -> Bool {
        await libraryStore.contains(bookID: bookID)
    }

    func refreshBookMetadata(bookID: String) async {
        guard let book = await libraryStore.record(for: bookID) else { return }
        do {
            let chapters = try await apiService.fetchChapters(bookID: bookID)
            let records = chapters.map { response in
                LibraryChapterRecord(
                    id: response.id,
                    title: response.title,
                    audioAvailable: response.audioAvailable,
                    subtitlesAvailable: response.subtitlesAvailable,
                    metrics: ChapterPlaybackMetrics(
                        wordCount: response.wordCount,
                        audioDurationSec: response.audioDurationSec,
                        wordsPerMinute: response.wordsPerMinute,
                        speakingPaceKey: response.speakingPaceKey
                    ).normalized
                )
            }
            var updatedBook = book
            updatedBook.lastSyncedAt = Date()
            updatedBook.chapters = records
            await libraryStore.addOrUpdate(updatedBook)
        } catch {
            // Ignore refresh errors.
        }
    }
}

