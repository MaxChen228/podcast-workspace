//
//  SentenceDetailCoordinator.swift
//  audio-earning
//
//  Created by ChatGPT on 2025/11/05.
//

import Foundation
import Combine

protocol SentenceDetailCoordinating: AnyObject {
    var sentenceDetailPublisher: AnyPublisher<SentenceDetailState?, Never> { get }
    var lexiconFeedbackPublisher: AnyPublisher<LexiconSaveFeedback, Never> { get }

    @MainActor var currentDetail: SentenceDetailState? { get }

    @MainActor func reset()
    @MainActor func presentDetail(at index: Int)
    @MainActor func dismissDetail()
    @MainActor func refreshDetail(for index: Int)
    @MainActor func toggleWordSelection(_ word: String)
    @MainActor func clearSelectedWords()
    @MainActor func requestExplanation(language: String?)
    @MainActor func saveCurrentExplanation()
}

final class SentenceDetailCoordinator: SentenceDetailCoordinating {

    // MARK: - Dependencies

    private let subtitlePresenter: SubtitlePresenting
    private let explanationService: SentenceExplaining
    private let lexiconStore: SavedLexiconStoring
    private let defaultLanguage: String
    private let bookID: String?
    private let chapterID: String?

    // MARK: - State

    private var detail: SentenceDetailState? {
        didSet {
            sentenceDetailSubject.send(detail)
        }
    }

    private let sentenceDetailSubject = CurrentValueSubject<SentenceDetailState?, Never>(nil)
    private let feedbackSubject = PassthroughSubject<LexiconSaveFeedback, Never>()

    private var explanationTask: Task<Void, Never>?

    init(
        subtitlePresenter: SubtitlePresenting,
        explanationService: SentenceExplaining,
        lexiconStore: SavedLexiconStoring,
        defaultLanguage: String,
        bookID: String?,
        chapterID: String?
    ) {
        self.subtitlePresenter = subtitlePresenter
        self.explanationService = explanationService
        self.lexiconStore = lexiconStore
        self.defaultLanguage = defaultLanguage
        self.bookID = bookID
        self.chapterID = chapterID
    }

    deinit {
        explanationTask?.cancel()
    }

    // MARK: - Outputs

    var sentenceDetailPublisher: AnyPublisher<SentenceDetailState?, Never> {
        sentenceDetailSubject.eraseToAnyPublisher()
    }

    var lexiconFeedbackPublisher: AnyPublisher<LexiconSaveFeedback, Never> {
        feedbackSubject.eraseToAnyPublisher()
    }

    @MainActor
    var currentDetail: SentenceDetailState? {
        detail
    }

    // MARK: - Lifecycle

    @MainActor
    func reset() {
        explanationTask?.cancel()
        explanationTask = nil
        detail = nil
    }

    @MainActor
    func presentDetail(at index: Int) {
        guard let context = subtitlePresenter.context(around: index, mode: .sentenceLevel) else {
            detail = nil
            return
        }

        var newDetail = SentenceDetailState(context: context)
        if let cached = explanationService.cachedExplanation(
            subtitleID: context.current.id,
            language: defaultLanguage.lowercased(),
            phrase: nil
        ) {
            newDetail.explanationState = .loaded(data: cached, cached: true)
        }
        detail = newDetail
    }

    @MainActor
    func dismissDetail() {
        detail = nil
    }

    @MainActor
    func refreshDetail(for index: Int) {
        guard var current = detail else { return }
        guard let context = subtitlePresenter.context(around: index, mode: .sentenceLevel) else { return }

        current.context = context
        current.selectedWords.removeAll()

        if let cached = explanationService.cachedExplanation(
            subtitleID: context.current.id,
            language: defaultLanguage.lowercased(),
            phrase: nil
        ) {
            current.explanationState = .loaded(data: cached, cached: true)
        } else {
            current.explanationState = .idle
        }

        detail = current
    }

    @MainActor
    func toggleWordSelection(_ word: String) {
        guard var current = detail else { return }
        let normalized = word
            .trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.symbols))
            .lowercased()

        guard !normalized.isEmpty else { return }

        if current.selectedWords.contains(normalized) {
            current.selectedWords.remove(normalized)
        } else {
            current.selectedWords.insert(normalized)
        }

        detail = current
    }

    @MainActor
    func clearSelectedWords() {
        guard var current = detail else { return }
        if current.selectedWords.isEmpty { return }
        current.selectedWords.removeAll()
        detail = current
    }

    @MainActor
    func requestExplanation(language: String?) {
        guard let current = detail else { return }
        let preferredLanguage = (language ?? defaultLanguage)

        if let phrase = current.selectedPhrase {
            requestPhraseExplanation(phrase: phrase, language: preferredLanguage)
        } else {
            requestFullSentenceExplanation(language: preferredLanguage)
        }
    }

    @MainActor
    func saveCurrentExplanation() {
        guard let current = detail else {
            feedbackSubject.send(LexiconSaveFeedback(kind: .failure, message: "目前沒有可儲存的內容"))
            return
        }

        guard case let .loaded(data, _) = current.explanationState else {
            feedbackSubject.send(LexiconSaveFeedback(kind: .failure, message: "請先產生 AI 解釋"))
            return
        }

        let entry = buildLexiconEntry(detail: current, data: data)
        lexiconStore.add(entry)
        feedbackSubject.send(LexiconSaveFeedback(kind: .success, message: "已儲存「\(entry.title)」"))
    }

    // MARK: - Explanation Requests

    private func requestFullSentenceExplanation(language: String) {
        guard var current = detail else { return }

        if let cached = explanationService.cachedExplanation(
            subtitleID: current.context.current.id,
            language: language,
            phrase: nil
        ) {
            current.explanationState = .loaded(data: cached, cached: true)
            detail = current
            return
        }

        current.explanationState = .loading
        detail = current

        let targetID = current.context.current.id
        let targetContext = current.context

        explanationTask?.cancel()
        explanationTask = Task { [weak explanationService, weak self] in
            guard let self else { return }
            guard let explanationService else { return }
            do {
                let result = try await explanationService.fetchSentenceExplanation(
                    context: targetContext,
                    language: language
                )

                await MainActor.run { [weak self] in
                    guard let self else { return }
                    guard var latest = self.detail, latest.context.current.id == targetID else { return }
                    latest.explanationState = .loaded(data: result.data, cached: result.cached)
                    self.detail = latest
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    guard var latest = self.detail, latest.context.current.id == targetID else { return }
                    latest.explanationState = .failure(message: error.localizedDescription)
                    self.detail = latest
                }
            }
        }
    }

    private func requestPhraseExplanation(phrase: String, language: String) {
        guard var current = detail else { return }

        if let cached = explanationService.cachedExplanation(
            subtitleID: current.context.current.id,
            language: language,
            phrase: phrase
        ) {
            current.explanationState = .loaded(data: cached, cached: true)
            detail = current
            return
        }

        current.explanationState = .loading
        detail = current

        let targetID = current.context.current.id
        let targetContext = current.context

        explanationTask?.cancel()
        explanationTask = Task { [weak explanationService, weak self] in
            guard let self else { return }
            guard let explanationService else { return }
            do {
                let result = try await explanationService.fetchPhraseExplanation(
                    phrase,
                    context: targetContext,
                    language: language
                )

                await MainActor.run { [weak self] in
                    guard let self else { return }
                    guard var latest = self.detail, latest.context.current.id == targetID else { return }
                    latest.explanationState = .loaded(data: result.data, cached: result.cached)
                    self.detail = latest
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    guard var latest = self.detail, latest.context.current.id == targetID else { return }
                    latest.explanationState = .failure(message: error.localizedDescription)
                    self.detail = latest
                }
            }
        }
    }

    // MARK: - Helpers

    private func buildLexiconEntry(detail: SentenceDetailState, data: SentenceExplanationViewData) -> SavedLexiconEntry {
        let firstSentence = extractFirstSentence(from: data.overview)
        let parsed = parseTitleSubtitle(from: firstSentence)

        let selection = detail.selectedPhrase?.trimmingCharacters(in: .whitespacesAndNewlines)
        let titleCandidate = selection?.isEmpty == false ? selection : parsed.title
        let title = (titleCandidate?.isEmpty == false ? titleCandidate : detail.context.current.text) ?? detail.context.current.text
        let chineseMeaning = data.chineseMeaning?.trimmingCharacters(in: .whitespacesAndNewlines)
        let subtitleSource = chineseMeaning?.isEmpty == false ? chineseMeaning : (parsed.subtitle ?? data.overview)
        let subtitle = subtitleSource ?? detail.context.current.text

        let vocab = data.vocabulary.map { item in
            SavedLexiconEntry.Vocabulary(word: item.word, meaning: item.meaning, note: item.note)
        }

        return SavedLexiconEntry(
            id: UUID(),
            createdAt: Date(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            subtitle: subtitle.trimmingCharacters(in: .whitespacesAndNewlines),
            chineseMeaning: chineseMeaning,
            overview: data.overview,
            keyPoints: data.keyPoints,
            vocabulary: vocab,
            sourceSentence: detail.context.current.text,
            sourceBookID: bookID,
            sourceChapterID: chapterID,
            sourceSubtitleID: detail.context.current.id
        )
    }

    private func extractFirstSentence(from overview: String) -> String? {
        let trimmed = overview.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let newlineIndex = trimmed.firstIndex(of: "\n") {
            let firstLine = String(trimmed[..<newlineIndex])
            return clipSentence(firstLine)
        }
        return clipSentence(trimmed)
    }

    private func clipSentence(_ text: String) -> String {
        let sentenceTerminators: Set<Character> = ["。", "！", "？", ".", "!", "?"]
        if let terminator = text.firstIndex(where: { sentenceTerminators.contains($0) }) {
            return String(text[..<text.index(after: terminator)]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseTitleSubtitle(from sentence: String?) -> (title: String?, subtitle: String?) {
        guard let sentence, !sentence.isEmpty else { return (nil, nil) }
        let range = NSRange(sentence.startIndex..<sentence.endIndex, in: sentence)
        if let match = Self.lexiconTitleRegex.firstMatch(in: sentence, options: [], range: range), match.numberOfRanges >= 3 {
            let nsSentence = sentence as NSString
            let title = nsSentence.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            let subtitle = nsSentence.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
            return (title.isEmpty ? nil : title, subtitle.isEmpty ? nil : subtitle)
        }
        return (sentence, sentence)
    }

    private static let lexiconTitleRegex = try! NSRegularExpression(pattern: "「(.+?)」\\s*(.+)", options: [])
}
