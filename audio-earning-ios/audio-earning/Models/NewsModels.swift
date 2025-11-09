//
//  NewsModels.swift
//  audio-earning
//
//  Created by Codex on 2025/11/09.
//

import Foundation

struct NewsFeed: Equatable {
    let articles: [NewsArticle]
    let category: String?
    let market: String
    let count: Int
    let cached: Bool
    let query: String?
}

struct NewsArticle: Identifiable, Equatable {
    let id: String
    let title: String
    let summary: String?
    let url: URL
    let imageURL: URL?
    let providerName: String?
    let publishedAt: Date?
    let category: String?
    let source: String

    var relativePublishedText: String {
        guard let publishedAt else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: publishedAt, relativeTo: Date())
    }
}

enum NewsUserAction: String, Codable {
    case open
    case share
    case save
    case impression
}

struct NewsEventPayload: Encodable {
    let articleID: String
    let articleURL: URL
    let action: NewsUserAction
    let category: String?
    let clientTimestamp: Date
    let deviceLocale: String
    let market: String?

    enum CodingKeys: String, CodingKey {
        case articleID = "article_id"
        case articleURL = "article_url"
        case action
        case category
        case clientTimestamp = "client_ts"
        case deviceLocale = "device_locale"
        case market
    }
}

enum NewsCategoryFilter: String, CaseIterable, Identifiable {
    case headlines
    case technology
    case business
    case science
    case entertainment
    case sports

    var id: String { rawValue }

    var title: String {
        switch self {
        case .headlines:
            return "熱門"
        case .technology:
            return "科技"
        case .business:
            return "商業"
        case .science:
            return "科學"
        case .entertainment:
            return "娛樂"
        case .sports:
            return "運動"
        }
    }

    var backendValue: String? {
        switch self {
        case .headlines:
            return nil
        default:
            return rawValue
        }
    }
}
