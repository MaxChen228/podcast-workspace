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
    var bookLibraryManager: BookLibraryManaging { get }

    @MainActor func makeBookListViewModel() -> BookListViewModel
    @MainActor func makeBookCatalogViewModel() -> BookCatalogViewModel
    @MainActor func makeNewsFeedViewModel() -> NewsFeedViewModel
}

@MainActor
final class AppDependencyContainer: DependencyResolving, ObservableObject {
    let apiService: APIServiceProtocol
    let backendStore: BackendConfigurationStoring
    let cacheManager: CacheManaging
    let newsService: NewsServiceProtocol
    let newsPreferenceStore: NewsPreferenceStoring
    let bookLibraryManager: BookLibraryManaging

    init(
        apiService: APIServiceProtocol = APIService.shared,
        backendStore: BackendConfigurationStoring = BackendConfigurationStore.shared,
        cacheManager: CacheManaging = CacheManager.shared,
        newsService: NewsServiceProtocol = NewsService.shared,
        newsPreferenceStore: NewsPreferenceStoring = NewsPreferenceStore.shared,
        bookLibraryManager: BookLibraryManaging = BookLibraryManager()
    ) {
        self.apiService = apiService
        self.backendStore = backendStore
        self.cacheManager = cacheManager
        self.newsService = newsService
        self.newsPreferenceStore = newsPreferenceStore
        self.bookLibraryManager = bookLibraryManager
    }

    @MainActor
    func makeBookListViewModel() -> BookListViewModel {
        BookListViewModel(
            service: apiService,
            backendStore: backendStore,
            cacheManager: cacheManager,
            libraryManager: bookLibraryManager
        )
    }

    @MainActor
    func makeBookCatalogViewModel() -> BookCatalogViewModel {
        BookCatalogViewModel(
            service: apiService,
            libraryManager: bookLibraryManager
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
