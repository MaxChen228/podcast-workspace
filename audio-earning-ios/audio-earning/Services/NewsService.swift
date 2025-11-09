//
//  NewsService.swift
//  audio-earning
//
//  Created by Codex on 2025/11/09.
//

import Foundation

enum NewsServiceError: LocalizedError {
    case invalidResponse
    case backendStatus(Int)
    case decodingFailed
    case featureDisabled

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "新聞服務回傳不合法的資料"
        case .backendStatus(let code):
            return "新聞服務回傳錯誤碼 \(code)"
        case .decodingFailed:
            return "無法解析新聞資料"
        case .featureDisabled:
            return "伺服器尚未啟用新聞功能"
        }
    }
}

final class NewsService: NewsServiceProtocol {
    static let shared = NewsService()

    private let session: URLSession
    private let cache = NewsFeedCache()
    private let jsonDecoder: JSONDecoder
    private let ttl: TimeInterval

    init(session: URLSession = .shared, cacheTTL: TimeInterval = 600) {
        self.session = session
        self.ttl = cacheTTL
        self.jsonDecoder = JSONDecoder()
        self.jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    func fetchHeadlines(category: String?, market: String?, count: Int?, forceRefresh: Bool) async throws -> NewsFeed {
        let endpoint = NewsEndpoint.headlines(category: category, market: market, count: count)
        if !forceRefresh, let cached = await cache.feed(for: endpoint.cacheKey) {
            return cached
        }

        let url = try endpoint.url(baseURL: APIConfiguration.shared.baseURL)
        let feed = try await performRequest(url: url, queryItems: endpoint.queryItems)
        await cache.store(feed, for: endpoint.cacheKey, ttl: ttl)
        return feed
    }

    func searchNews(query: String, market: String?, count: Int?, forceRefresh: Bool) async throws -> NewsFeed {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NewsServiceError.invalidResponse
        }
        let endpoint = NewsEndpoint.search(query: trimmed, market: market, count: count)
        if !forceRefresh, let cached = await cache.feed(for: endpoint.cacheKey) {
            return cached
        }

        let url = try endpoint.url(baseURL: APIConfiguration.shared.baseURL)
        let baseFeed = try await performRequest(url: url, queryItems: endpoint.queryItems)
        let feed = NewsFeed(
            articles: baseFeed.articles,
            category: baseFeed.category,
            market: baseFeed.market,
            count: baseFeed.count,
            cached: baseFeed.cached,
            query: trimmed
        )
        await cache.store(feed, for: endpoint.cacheKey, ttl: ttl)
        return feed
    }

    func log(event: NewsEventPayload) async {
        let url = APIConfiguration.shared.baseURL.appendingPathComponent("news").appendingPathComponent("events")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        guard let body = try? JSONEncoder().encode(event) else { return }
        request.httpBody = body

        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                return
            }
        } catch {
            // best-effort logging, ignore errors
        }
    }

    private func performRequest(url: URL, queryItems: [URLQueryItem]) async throws -> NewsFeed {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw NewsServiceError.invalidResponse
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let requestURL = components.url else {
            throw NewsServiceError.invalidResponse
        }

        let (data, response) = try await session.data(from: requestURL)
        guard let http = response as? HTTPURLResponse else {
            throw NewsServiceError.invalidResponse
        }

        if http.statusCode == 503 {
            throw NewsServiceError.featureDisabled
        }

        guard 200..<300 ~= http.statusCode else {
            throw NewsServiceError.backendStatus(http.statusCode)
        }

        do {
            let payload = try jsonDecoder.decode(NewsFeedResponsePayload.self, from: data)
            return payload.toDomain()
        } catch {
            throw NewsServiceError.decodingFailed
        }
    }
}

// MARK: - Private helpers

private enum NewsEndpoint {
    case headlines(category: String?, market: String?, count: Int?)
    case search(query: String, market: String?, count: Int?)

    func url(baseURL: URL) throws -> URL {
        switch self {
        case .headlines:
            return baseURL.appendingPathComponent("news").appendingPathComponent("headlines")
        case .search:
            return baseURL.appendingPathComponent("news").appendingPathComponent("search")
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .headlines(let category, let market, let count):
            var items: [URLQueryItem] = []
            if let category {
                items.append(URLQueryItem(name: "category", value: category))
            }
            if let market {
                items.append(URLQueryItem(name: "market", value: market))
            }
            if let count {
                items.append(URLQueryItem(name: "count", value: String(count)))
            }
            return items
        case .search(let query, let market, let count):
            var items: [URLQueryItem] = [URLQueryItem(name: "q", value: query)]
            if let market {
                items.append(URLQueryItem(name: "market", value: market))
            }
            if let count {
                items.append(URLQueryItem(name: "count", value: String(count)))
            }
            return items
        }
    }

    var cacheKey: String {
        switch self {
        case .headlines(let category, let market, let count):
            return "headlines-\(category ?? "top")-\(market ?? "default")-\(count ?? 0)"
        case .search(let query, let market, let count):
            return "search-\(query.lowercased())-\(market ?? "default")-\(count ?? 0)"
        }
    }
}

private actor NewsFeedCache {
    private struct Entry {
        let feed: NewsFeed
        let expiresAt: Date
    }

    private var storage: [String: Entry] = [:]

    func feed(for key: String) -> NewsFeed? {
        guard let entry = storage[key] else { return nil }
        if entry.expiresAt < Date() {
            storage.removeValue(forKey: key)
            return nil
        }
        return entry.feed
    }

    func store(_ feed: NewsFeed, for key: String, ttl: TimeInterval) {
        storage[key] = Entry(feed: feed, expiresAt: Date().addingTimeInterval(ttl))
    }
}

private struct NewsFeedResponsePayload: Decodable {
    struct Article: Decodable {
        let id: String
        let title: String
        let summary: String?
        let url: URL
        let imageUrl: URL?
        let category: String?
        let providerName: String?
        let publishedAt: String?
        let source: String?
    }

    let articles: [Article]
    let category: String?
    let market: String
    let count: Int
    let cached: Bool
    let query: String?

    func toDomain() -> NewsFeed {
        NewsFeed(
            articles: articles.map { $0.toDomain() },
            category: category,
            market: market,
            count: count,
            cached: cached,
            query: query
        )
    }
}

private extension NewsFeedResponsePayload.Article {
    func toDomain() -> NewsArticle {
        NewsArticle(
            id: id,
            title: title,
            summary: summary,
            url: url,
            imageURL: imageUrl,
            providerName: providerName,
            publishedAt: publishedAt.flatMap { ISO8601DateFormatter.withFractional.date(from: $0) },
            category: category,
            source: source ?? "bing-news"
        )
    }
}

private extension ISO8601DateFormatter {
    static let withFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
