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
    var newsService: NewsServiceProtocol { get }
    var newsPreferenceStore: NewsPreferenceStoring { get }

    @MainActor func makeBookListViewModel() -> BookListViewModel
    @MainActor func makeNewsFeedViewModel() -> NewsFeedViewModel
}

@MainActor
final class AppDependencyContainer: DependencyResolving, ObservableObject {
    let apiService: APIServiceProtocol
    let backendStore: BackendConfigurationStoring
    let cacheManager: CacheManaging
    let newsService: NewsServiceProtocol
    let newsPreferenceStore: NewsPreferenceStoring

    init(
        apiService: APIServiceProtocol = APIService.shared,
        backendStore: BackendConfigurationStoring = BackendConfigurationStore.shared,
        cacheManager: CacheManaging = CacheManager.shared,
        newsService: NewsServiceProtocol = NewsService.shared,
        newsPreferenceStore: NewsPreferenceStoring = NewsPreferenceStore.shared
    ) {
        self.apiService = apiService
        self.backendStore = backendStore
        self.cacheManager = cacheManager
        self.newsService = newsService
        self.newsPreferenceStore = newsPreferenceStore
    }

    @MainActor
    func makeBookListViewModel() -> BookListViewModel {
        BookListViewModel(
            service: apiService,
            backendStore: backendStore,
            cacheManager: cacheManager
        )
    }

    @MainActor
    func makeNewsFeedViewModel() -> NewsFeedViewModel {
        NewsFeedViewModel(
            service: newsService,
            preferenceStore: newsPreferenceStore
        )
    }
}
