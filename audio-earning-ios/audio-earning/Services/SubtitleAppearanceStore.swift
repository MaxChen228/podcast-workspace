//
//  SubtitleAppearanceStore.swift
//  audio-earning
//
//  Created by ChatGPT on 2025/11/05.
//

import Foundation

/// Manages persistence of `SubtitleAppearance` via `UserDefaults`.
final class SubtitleAppearanceStore {
    static let shared = SubtitleAppearanceStore()

    private let defaults: UserDefaults
    private let storageKey = "subtitleAppearance.settings"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> SubtitleAppearance {
        guard let data = defaults.data(forKey: storageKey) else {
            return .default
        }

        do {
            return try decoder.decode(SubtitleAppearance.self, from: data)
        } catch {
#if DEBUG
            print("⚠️ Failed to decode subtitle appearance: \(error.localizedDescription)")
#endif
            return .default
        }
    }

    func save(_ appearance: SubtitleAppearance) {
        do {
            let data = try encoder.encode(appearance)
            defaults.set(data, forKey: storageKey)
        } catch {
#if DEBUG
            print("⚠️ Failed to persist subtitle appearance: \(error.localizedDescription)")
#endif
        }
    }
}
