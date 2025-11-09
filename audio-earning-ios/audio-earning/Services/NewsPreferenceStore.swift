//
//  NewsPreferenceStore.swift
//  audio-earning
//
//  Created by Codex on 2025/11/09.
//

import Foundation

final class NewsPreferenceStore: NewsPreferenceStoring {
    static let shared = NewsPreferenceStore()

    private let defaults: UserDefaults
    private let marketKey = "news.market.preference"
    private let categoryKey = "news.category.preference"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var market: String {
        get { defaults.string(forKey: marketKey) ?? "en-US" }
        set { defaults.set(newValue, forKey: marketKey) }
    }

    var lastCategory: String? {
        get { defaults.string(forKey: categoryKey) }
        set {
            if let value = newValue {
                defaults.set(value, forKey: categoryKey)
            } else {
                defaults.removeObject(forKey: categoryKey)
            }
        }
    }
}
