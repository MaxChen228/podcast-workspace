//
//  NewsFeedViewModel.swift
//  audio-earning
//
//  Created by Codex on 2025/11/09.
//

import Foundation

@MainActor
final class NewsFeedViewModel: ObservableObject {
    @Published private(set) var articles: [NewsArticle] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedFilter: NewsCategoryFilter
    @Published var selectedMarket: String
    @Published var searchText: String = ""
    @Published private(set) var isShowingSearchResults = false
    @Published private(set) var lastUpdatedAt: Date?

    let marketOptions = ["en-US", "en-GB", "zh-TW"]

    private let service: NewsServiceProtocol
    private let preferenceStore: NewsPreferenceStoring
    private var hasLoaded = false

    init(
        service: NewsServiceProtocol = NewsService.shared,
        preferenceStore: NewsPreferenceStoring = NewsPreferenceStore.shared
    ) {
        self.service = service
        self.preferenceStore = preferenceStore
        if let stored = preferenceStore.lastCategory, let filter = NewsCategoryFilter(rawValue: stored) {
            selectedFilter = filter
        } else {
            selectedFilter = .headlines
        }
        selectedMarket = preferenceStore.market
    }

    func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        Task { await fetchHeadlines(forceRefresh: false) }
    }

    func refresh() {
        Task { await fetchHeadlines(forceRefresh: true) }
    }

    func select(filter: NewsCategoryFilter) {
        guard selectedFilter != filter else { return }
        selectedFilter = filter
        preferenceStore.lastCategory = filter.rawValue
        searchText = ""
        isShowingSearchResults = false
        refresh()
    }

    func updateMarket(_ market: String) {
        guard market != selectedMarket else { return }
        selectedMarket = market
        preferenceStore.market = market
        refresh()
    }

    func submitSearch() {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            isShowingSearchResults = false
            Task { await fetchHeadlines(forceRefresh: true) }
            return
        }

        Task { await performSearch(query: trimmed) }
    }

    func clearSearch() {
        searchText = ""
        isShowingSearchResults = false
        Task { await fetchHeadlines(forceRefresh: false) }
    }

    func recordAction(_ action: NewsUserAction, for article: NewsArticle) {
        let payload = NewsEventPayload(
            articleID: article.id,
            articleURL: article.url,
            action: action,
            category: article.category ?? selectedFilter.backendValue,
            clientTimestamp: Date(),
            deviceLocale: Locale.current.identifier,
            market: selectedMarket
        )
        Task.detached { [service] in
            await service.log(event: payload)
        }
    }

    private func fetchHeadlines(forceRefresh: Bool) async {
        isLoading = true
        errorMessage = nil
        do {
            let feed = try await service.fetchHeadlines(
                category: selectedFilter.backendValue,
                market: selectedMarket,
                count: 10,
                forceRefresh: forceRefresh
            )
            articles = feed.articles
            isShowingSearchResults = false
            lastUpdatedAt = Date()
        } catch {
            errorMessage = error.localizedDescription
            articles = []
        }
        isLoading = false
    }

    private func performSearch(query: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let feed = try await service.searchNews(
                query: query,
                market: selectedMarket,
                count: 15,
                forceRefresh: false
            )
            articles = feed.articles
            isShowingSearchResults = true
            lastUpdatedAt = Date()
        } catch {
            errorMessage = error.localizedDescription
            isShowingSearchResults = false
            articles = []
        }
        isLoading = false
    }
}
