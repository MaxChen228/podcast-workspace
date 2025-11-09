//
//  DependencyContainer.swift
//  audio-earning
//
//  Created by Codex on 2025/11/05.
//

import Foundation

@MainActor
protocol DependencyResolving: AnyObject {
    var apiService: APIServiceProtocol { get }
    var backendStore: BackendConfigurationStoring { get }
    var cacheManager: CacheManaging { get }

    @MainActor func makeBookListViewModel() -> BookListViewModel
}

@MainActor
final class AppDependencyContainer: DependencyResolving, ObservableObject {
    let apiService: APIServiceProtocol
    let backendStore: BackendConfigurationStoring
    let cacheManager: CacheManaging

    init(
        apiService: APIServiceProtocol = APIService.shared,
        backendStore: BackendConfigurationStoring = BackendConfigurationStore.shared,
        cacheManager: CacheManaging = CacheManager.shared
    ) {
        self.apiService = apiService
        self.backendStore = backendStore
        self.cacheManager = cacheManager
    }

    @MainActor
    func makeBookListViewModel() -> BookListViewModel {
        BookListViewModel(
            service: apiService,
            backendStore: backendStore,
            cacheManager: cacheManager
        )
    }
}
