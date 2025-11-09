//
//  HighlightLexiconStoreTests.swift
//  audio-earningTests
//
//  Created by ChatGPT on 2025/11/04.
//

import Foundation
import Testing
@testable import audio_earning

struct HighlightLexiconStoreTests {

    @Test func normalizationStripsNonAlphanumerics() async throws {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { tearDown(defaults, suiteName: suiteName) }

        let store = HighlightLexiconStore(defaults: defaults)
        let normalized = store.normalized("Hello, World!")

        #expect(normalized == "helloworld")
    }

    @Test func addAndClearUpdatesPersistence() async throws {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { tearDown(defaults, suiteName: suiteName) }

        let store = HighlightLexiconStore(defaults: defaults)
        store.add("Vocabulary!")

        #expect(store.contains("vocabulary"))

        let reloaded = HighlightLexiconStore(defaults: defaults)
        #expect(reloaded.contains("Vocabulary"))
        #expect(reloaded.sortedWords() == ["vocabulary"])

        reloaded.clear()
        let refreshed = HighlightLexiconStore(defaults: defaults)
        #expect(refreshed.currentWords.isEmpty)
    }

    // MARK: - Helpers

    private func makeIsolatedDefaults() -> (UserDefaults, String) {
        let suiteName = "HighlightLexiconStoreTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Unable to create UserDefaults suite for tests")
        }
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }

    private func tearDown(_ defaults: UserDefaults, suiteName: String) {
        defaults.removePersistentDomain(forName: suiteName)
    }
}
