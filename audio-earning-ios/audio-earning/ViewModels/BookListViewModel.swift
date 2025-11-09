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
    @Published private(set) var endpoints: [BackendEndpoint] = []
    @Published private(set) var selectedEndpointID: UUID?

    private let service: APIServiceProtocol
    private let backendStore: BackendConfigurationStoring
    private let cacheManager: CacheManaging
    private var hasLoaded = false
    private var backendObserver: NSObjectProtocol?

    init(
        service: APIServiceProtocol = APIService.shared,
        backendStore: BackendConfigurationStoring = BackendConfigurationStore.shared,
        cacheManager: CacheManaging = CacheManager.shared
    ) {
        self.service = service
        self.backendStore = backendStore
        self.cacheManager = cacheManager
        refreshEndpoints()

        backendObserver = NotificationCenter.default.addObserver(forName: .backendConfigurationDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleBackendChange()
            }
        }
    }

    deinit {
        if let observer = backendObserver {
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
            books = responses.map { response in
                let normalizedCover = response.coverURL.map { APIService.normalizedMediaURL(from: $0) }
                return Book(id: response.id, title: response.title, coverURL: normalizedCover)
            }
        } catch {
            errorMessage = error.localizedDescription
            books = []
        }

        isLoading = false
    }

    func clearCaches() async throws -> CacheClearSummary {
        let summary = try await cacheManager.clearAllCaches()
        hasLoaded = false
        return summary
    }

    func selectEndpoint(_ endpoint: BackendEndpoint) {
        backendStore.selectEndpoint(id: endpoint.id)
        refreshEndpoints()
    }

    func addEndpoint(name: String, urlString: String) -> String? {
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else {
            return "請輸入網址"
        }

        guard let url = URL(string: trimmedURL), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
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
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else {
            return "請輸入網址"
        }

        guard let url = URL(string: trimmedURL), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
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

    private func handleBackendChange() {
        refreshEndpoints()
        reloadAfterBackendChange()
    }

    private func reloadAfterBackendChange() {
        hasLoaded = false
        loadBooks(force: true)
    }

    private func refreshEndpoints() {
        endpoints = backendStore.endpoints
        selectedEndpointID = backendStore.currentEndpoint.id
    }

    private func normalizedURLString(_ string: String) -> String {
        string
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .lowercased()
    }
}
