//
//  BookListViewModel.swift
//  audio-earning
//
//  Created by Codex on 2025/10/27.
//

import Foundation

@MainActor
final class BookListViewModel: ObservableObject {
    @Published var books: [Book] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var libraryRecords: [LibraryBookRecord] = []

    private let cacheManager: CacheManaging
    private let libraryManager: BookLibraryManaging
    private var hasLoaded = false
    private var backendObserver: NSObjectProtocol?
    private var libraryObserver: NSObjectProtocol?

    init(
        cacheManager: CacheManaging = CacheManager.shared,
        libraryManager: BookLibraryManaging = BookLibraryManager()
    ) {
        self.cacheManager = cacheManager
        self.libraryManager = libraryManager

        backendObserver = NotificationCenter.default.addObserver(forName: .backendConfigurationDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleBackendChange()
            }
        }

        libraryObserver = NotificationCenter.default.addObserver(forName: .bookLibraryDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.handleLibraryChange()
        }
    }

    deinit {
        if let observer = backendObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = libraryObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func loadBooks(force: Bool = false) {
        guard !hasLoaded || force else { return }
        hasLoaded = true

        Task { [weak self] in
            await self?.fetchLibraryBooks()
        }
    }

    private func fetchLibraryBooks() async {
        isLoading = true
        errorMessage = nil

        let records = await libraryManager.loadLibraryBooks()
        libraryRecords = records
        books = records.map { record in
            Book(id: record.id, title: record.title, coverURL: record.coverURL)
        }

        isLoading = false
    }

    func clearCaches() async throws -> CacheClearSummary {
        let summary = try await cacheManager.clearAllCaches()
        hasLoaded = false
        return summary
    }

    private func handleBackendChange() {
        reloadAfterBackendChange()
    }

    private func handleLibraryChange() {
        hasLoaded = false
        loadBooks(force: true)
    }

    private func reloadAfterBackendChange() {
        hasLoaded = false
        loadBooks(force: true)
    }

    func deleteBooks(at offsets: IndexSet) {
        let ids = offsets.map { books[$0].id }
        Task {
            for id in ids {
                await libraryManager.removeBookFromLibrary(bookID: id)
            }
        }
    }

    func record(for bookID: String) -> LibraryBookRecord? {
        libraryRecords.first { $0.id == bookID }
    }
}

@MainActor
final class BackendConfigurationViewModel: ObservableObject {
    @Published private(set) var endpoints: [BackendEndpoint] = []
    @Published private(set) var selectedEndpointID: UUID?

    private let service: APIServiceProtocol
    private let backendStore: BackendConfigurationStoring
    private var backendObserver: NSObjectProtocol?

    init(
        service: APIServiceProtocol = APIService.shared,
        backendStore: BackendConfigurationStoring = BackendConfigurationStore.shared
    ) {
        self.service = service
        self.backendStore = backendStore
        refreshEndpoints()

        backendObserver = NotificationCenter.default.addObserver(forName: .backendConfigurationDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshEndpoints()
            }
        }
    }

    deinit {
        if let observer = backendObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func selectEndpoint(_ endpoint: BackendEndpoint) {
        backendStore.selectEndpoint(id: endpoint.id)
        refreshEndpoints()
    }

    func addEndpoint(name: String, urlString: String) -> String? {
        guard let url = validateURL(from: urlString) else {
            return "請輸入合法的 http 或 https 網址"
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        backendStore.addOrUpdateEndpoint(name: trimmedName, url: url)
        refreshEndpoints()
        return nil
    }

    func deleteEndpoint(_ endpoint: BackendEndpoint) {
        guard backendStore.canDeleteEndpoint(endpoint) else { return }
        backendStore.deleteEndpoint(id: endpoint.id)
        refreshEndpoints()
    }

    func canDeleteEndpoint(_ endpoint: BackendEndpoint) -> Bool {
        backendStore.canDeleteEndpoint(endpoint)
    }

    func updateEndpoint(_ endpoint: BackendEndpoint, name: String, urlString: String) -> String? {
        guard let url = validateURL(from: urlString) else {
            return "請輸入合法的 http 或 https 網址"
        }

        let normalizedTarget = normalizedURLString(url.absoluteString)
        if endpoints.contains(where: { $0.id != endpoint.id && normalizedURLString($0.url.absoluteString) == normalizedTarget }) {
            return "此網址已存在於列表中"
        }

        guard backendStore.updateEndpoint(id: endpoint.id, name: name, url: url) != nil else {
            return "更新失敗，請稍後再試"
        }

        refreshEndpoints()
        return nil
    }

    func testEndpoint(_ endpoint: BackendEndpoint) async -> Result<Void, Error> {
        do {
            try await service.checkHealth(at: endpoint.url)
            return .success(())
        } catch {
            return .failure(error)
        }
    }

<<<<<<< HEAD
    private func handleBackendChange() {
        refreshEndpoints()
        reloadAfterBackendChange()
    }

    private func handleLibraryChange() {
        hasLoaded = false
        loadBooks(force: true)
    }

    private func reloadAfterBackendChange() {
        hasLoaded = false
        loadBooks(force: true)
    }

=======
>>>>>>> 2c4360b (feat: 設定頁提供伺服器設定入口)
    private func refreshEndpoints() {
        endpoints = backendStore.endpoints
        selectedEndpointID = backendStore.currentEndpoint.id
    }

    private func validateURL(from string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !trimmed.isEmpty,
            let url = URL(string: trimmed),
            let scheme = url.scheme?.lowercased(),
            ["http", "https"].contains(scheme)
        else {
            return nil
        }
        return url
    }

    private func normalizedURLString(_ string: String) -> String {
        string
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .lowercased()
    }

    func deleteBooks(at offsets: IndexSet) {
        let ids = offsets.map { books[$0].id }
        Task {
            for id in ids {
                await libraryManager.removeBookFromLibrary(bookID: id)
            }
        }
    }

    func record(for bookID: String) -> LibraryBookRecord? {
        libraryRecords.first { $0.id == bookID }
    }
}
