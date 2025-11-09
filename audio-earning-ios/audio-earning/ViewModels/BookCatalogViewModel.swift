//
//  BookCatalogViewModel.swift
//  audio-earning
//
//  Created by Codex on 2025/11/09.
//

import Foundation

@MainActor
final class BookCatalogViewModel: ObservableObject {
    @Published var books: [BookResponse] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var libraryBookIDs: Set<String> = []
    @Published private(set) var isProcessingBookID: String?

    private let service: APIServiceProtocol
    private let libraryManager: BookLibraryManaging
    private var hasLoaded = false
    private var libraryObserver: NSObjectProtocol?

    init(
        service: APIServiceProtocol = APIService.shared,
        libraryManager: BookLibraryManaging = BookLibraryManager()
    ) {
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

    func loadBooks(force: Bool = false) {
        guard !hasLoaded || force else { return }
        hasLoaded = true
        Task { [weak self] in
            await self?.fetchBooks()
        }
    }

    private func fetchBooks() async {
        isLoading = true
        errorMessage = nil
        do {
            let responses = try await service.fetchBooks()
            books = responses
        } catch {
            errorMessage = error.localizedDescription
            books = []
        }
        isLoading = false
    }

    func addToLibrary(_ book: BookResponse) {
        guard !libraryBookIDs.contains(book.id) else { return }
        isProcessingBookID = book.id
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
                self.isProcessingBookID = nil
            }
        }
    }

    func isBookInLibrary(_ bookID: String) -> Bool {
        libraryBookIDs.contains(bookID)
    }

    private func refreshLibraryState() async {
        let records = await libraryManager.loadLibraryBooks()
        libraryBookIDs = Set(records.map(\.id))
    }
}

