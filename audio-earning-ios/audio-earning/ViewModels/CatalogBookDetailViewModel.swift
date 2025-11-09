//
//  CatalogBookDetailViewModel.swift
//  audio-earning
//
//  Created by Codex on 2025/11/09.
//

import Foundation

@MainActor
final class CatalogBookDetailViewModel: ObservableObject {
    @Published private(set) var chapters: [ChapterResponse] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var isInLibrary = false
    @Published private(set) var isProcessing = false

    let book: BookResponse

    private let service: APIServiceProtocol
    private let libraryManager: BookLibraryManaging
    private var hasLoaded = false
    private var libraryObserver: NSObjectProtocol?

    init(
        book: BookResponse,
        service: APIServiceProtocol = APIService.shared,
        libraryManager: BookLibraryManaging = BookLibraryManager()
    ) {
        self.book = book
        self.service = service
        self.libraryManager = libraryManager
        Task {
            await refreshLibraryState()
        }
        libraryObserver = NotificationCenter.default.addObserver(forName: .bookLibraryDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { [weak self] in
                await self?.refreshLibraryState()
            }
        }
    }

    deinit {
        if let observer = libraryObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        Task { [weak self] in
            await self?.fetchChapters()
        }
    }

    private func fetchChapters() async {
        isLoading = true
        errorMessage = nil
        do {
            let responses = try await service.fetchChapters(bookID: book.id)
            chapters = responses
        } catch {
            errorMessage = error.localizedDescription
            chapters = []
        }
        isLoading = false
    }

    func addToLibrary() {
        guard !isInLibrary else { return }
        isProcessing = true
        Task {
            do {
                try await libraryManager.addBookToLibrary(book: book)
                await refreshLibraryState()
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
            await MainActor.run {
                self.isProcessing = false
            }
        }
    }

    private func refreshLibraryState() async {
        isInLibrary = await libraryManager.isBookInLibrary(book.id)
    }
}

