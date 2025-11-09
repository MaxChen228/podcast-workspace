//
//  SentenceExplanationService.swift
//  audio-earning
//
//  Created by Codex on 2025/11/04.
//

import Foundation

protocol SentenceExplaining: AnyObject {
    func cachedExplanation(subtitleID: Int, language: String, phrase: String?) -> SentenceExplanationViewData?
    func fetchSentenceExplanation(context: SentenceContext, language: String) async throws -> SentenceExplanationResult
    func fetchPhraseExplanation(_ phrase: String, context: SentenceContext, language: String) async throws -> SentenceExplanationResult
    func clearCache()
}

struct SentenceExplanationResult {
    let data: SentenceExplanationViewData
    let cached: Bool
}

final class SentenceExplanationService: SentenceExplaining {
    private let apiService: APIServiceProtocol
    private var cache: [CacheKey: SentenceExplanationViewData] = [:]

    init(apiService: APIServiceProtocol = APIService.shared) {
        self.apiService = apiService
    }

    func cachedExplanation(subtitleID: Int, language: String, phrase: String?) -> SentenceExplanationViewData? {
        cache[CacheKey(subtitleID: subtitleID, language: language.lowercased(), phrase: phrase?.lowercased())]
    }

    func clearCache() {
        cache.removeAll()
    }

    func fetchSentenceExplanation(context: SentenceContext, language: String) async throws -> SentenceExplanationResult {
        let key = CacheKey(subtitleID: context.current.id, language: language.lowercased(), phrase: nil)

        if let cached = cache[key] {
            return SentenceExplanationResult(data: cached, cached: true)
        }

        let response = try await apiService.explainSentence(
            sentence: context.current.text,
            previousSentence: context.previous?.text ?? "",
            nextSentence: context.next?.text ?? "",
            language: language
        )

        let viewData = SentenceExplanationViewData(
            overview: response.overview,
            keyPoints: response.keyPoints,
            vocabulary: response.vocabulary.map { SentenceVocabularyItem(word: $0.word, meaning: $0.meaning, note: $0.note) },
            chineseMeaning: response.chineseMeaning?.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        cache[key] = viewData
        return SentenceExplanationResult(data: viewData, cached: response.cached)
    }

    func fetchPhraseExplanation(_ phrase: String, context: SentenceContext, language: String) async throws -> SentenceExplanationResult {
        let normalizedPhrase = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = CacheKey(subtitleID: context.current.id, language: language.lowercased(), phrase: normalizedPhrase.lowercased())

        if let cached = cache[key] {
            return SentenceExplanationResult(data: cached, cached: true)
        }

        let response = try await apiService.explainPhrase(
            phrase: normalizedPhrase,
            sentence: context.current.text,
            previousSentence: context.previous?.text,
            nextSentence: context.next?.text,
            language: language
        )

        let viewData = SentenceExplanationViewData(
            overview: response.overview,
            keyPoints: response.keyPoints,
            vocabulary: response.vocabulary.map { SentenceVocabularyItem(word: $0.word, meaning: $0.meaning, note: $0.note) },
            chineseMeaning: response.chineseMeaning?.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        cache[key] = viewData
        return SentenceExplanationResult(data: viewData, cached: response.cached)
    }

    private struct CacheKey: Hashable {
        let subtitleID: Int
        let language: String
        let phrase: String?
    }
}
