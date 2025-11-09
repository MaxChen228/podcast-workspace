//
//  HighlightLexiconStore.swift
//  audio-earning
//
//  Created by ChatGPT on 2025/11/04.
//

import Foundation
import Combine

protocol HighlightLexiconManaging: AnyObject {
    var wordsPublisher: AnyPublisher<Set<String>, Never> { get }
    var currentWords: Set<String> { get }

    func add(_ word: String)
    func remove(_ word: String)
    func clear()
    func contains(_ word: String) -> Bool
    func normalized(_ word: String) -> String
    func sortedWords() -> [String]
}

final class HighlightLexiconStore: HighlightLexiconManaging {
    static let shared = HighlightLexiconStore()

    private let storageKey = "audioEarning.highlightedWords"
    private let defaults: UserDefaults
    private let subject: CurrentValueSubject<Set<String>, Never>

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let initial = Set(defaults.stringArray(forKey: storageKey) ?? [])
        self.subject = CurrentValueSubject(initial)
    }

    var wordsPublisher: AnyPublisher<Set<String>, Never> {
        subject.eraseToAnyPublisher()
    }

    var currentWords: Set<String> {
        subject.value
    }

    func add(_ word: String) {
        let normalizedWord = normalized(word)
        guard !normalizedWord.isEmpty else { return }
        updateWords { words in words.insert(normalizedWord).inserted }
    }

    func remove(_ word: String) {
        let normalizedWord = normalized(word)
        guard !normalizedWord.isEmpty else { return }
        updateWords { words in words.remove(normalizedWord) != nil }
    }

    func clear() {
        updateWords { words in
            guard !words.isEmpty else { return false }
            words.removeAll(keepingCapacity: false)
            return true
        }
    }

    func contains(_ word: String) -> Bool {
        let normalizedWord = normalized(word)
        guard !normalizedWord.isEmpty else { return false }
        return subject.value.contains(normalizedWord)
    }

    func normalized(_ word: String) -> String {
        let lowered = word.lowercased()
        let allowed = CharacterSet.alphanumerics
        let filteredScalars = lowered.unicodeScalars.filter { allowed.contains($0) }
        return String(String.UnicodeScalarView(filteredScalars))
    }

    func sortedWords() -> [String] {
        subject.value.sorted()
    }

    private func updateWords(_ mutation: (inout Set<String>) -> Bool) {
        var words = subject.value
        let changed = mutation(&words)
        guard changed else { return }
        subject.send(words)
        persist(words)
    }

    private func persist(_ words: Set<String>) {
        defaults.set(Array(words), forKey: storageKey)
    }
}
