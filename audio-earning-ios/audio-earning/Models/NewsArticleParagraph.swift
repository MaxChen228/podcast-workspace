//
//  NewsArticleParagraph.swift
//  audio-earning
//
//  Model for structured paragraph representation in news articles
//

import Foundation

struct NewsArticleParagraph: Identifiable, Equatable {
    let id: UUID
    let text: String
    let index: Int  // Position in article (0-based)
    var isHighlighted: Bool = false
    var note: String? = nil
    var explanationState: ParagraphExplanationState = .collapsed

    init(id: UUID = UUID(), text: String, index: Int, isHighlighted: Bool = false, note: String? = nil, explanationState: ParagraphExplanationState = .collapsed) {
        self.id = id
        self.text = text
        self.index = index
        self.isHighlighted = isHighlighted
        self.note = note
        self.explanationState = explanationState
    }

    /// Convenience initializer for creating from plain text
    init(text: String, index: Int) {
        self.id = UUID()
        self.text = text
        self.index = index
        self.isHighlighted = false
        self.note = nil
        self.explanationState = .collapsed
    }

    /// Check if paragraph has a note attached
    var hasNote: Bool {
        note != nil && !(note?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    /// Check if explanation is expanded
    var isExplanationExpanded: Bool {
        if case .expanded = explanationState {
            return true
        }
        return false
    }
}

// MARK: - Explanation State

enum ParagraphExplanationState: Equatable {
    case collapsed
    case loading
    case expanded(data: ParagraphExplanationData)
    case error(message: String)

    static func == (lhs: ParagraphExplanationState, rhs: ParagraphExplanationState) -> Bool {
        switch (lhs, rhs) {
        case (.collapsed, .collapsed):
            return true
        case (.loading, .loading):
            return true
        case let (.expanded(lData), .expanded(rData)):
            return lData == rData
        case let (.error(lMsg), .error(rMsg)):
            return lMsg == rMsg
        default:
            return false
        }
    }
}

// MARK: - Explanation Data

struct ParagraphExplanationData: Equatable, Identifiable {
    let id: UUID
    let overview: String
    let keyPoints: [String]
    let vocabulary: [ParagraphVocabularyItem]
    let chineseSummary: String?
    let cached: Bool

    init(id: UUID = UUID(), overview: String, keyPoints: [String], vocabulary: [ParagraphVocabularyItem], chineseSummary: String?, cached: Bool = false) {
        self.id = id
        self.overview = overview
        self.keyPoints = keyPoints
        self.vocabulary = vocabulary
        self.chineseSummary = chineseSummary
        self.cached = cached
    }
}

struct ParagraphVocabularyItem: Equatable, Identifiable {
    let id: UUID
    let word: String
    let meaning: String
    let note: String?

    init(id: UUID = UUID(), word: String, meaning: String, note: String? = nil) {
        self.id = id
        self.word = word
        self.meaning = meaning
        self.note = note
    }
}

// MARK: - Parsing Helper

extension NewsArticleParagraph {
    /// Parse article content into structured paragraphs
    /// - Parameter content: Raw article text content
    /// - Returns: Array of paragraph objects
    static func parse(content: String) -> [NewsArticleParagraph] {
        let paragraphs = content
            .split(separator: "\n\n", omittingEmptySubsequences: true)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return paragraphs.enumerated().map { index, text in
            NewsArticleParagraph(text: text, index: index)
        }
    }
}

// MARK: - Saved Highlight Model

/// Persistent storage for highlighted paragraphs and notes
struct SavedHighlight: Identifiable, Codable {
    let id: UUID
    let articleURL: URL
    let paragraphIndex: Int
    let highlightedText: String
    let note: String?
    let createdAt: Date

    init(id: UUID = UUID(), articleURL: URL, paragraphIndex: Int, highlightedText: String, note: String?, createdAt: Date = Date()) {
        self.id = id
        self.articleURL = articleURL
        self.paragraphIndex = paragraphIndex
        self.highlightedText = highlightedText
        self.note = note
        self.createdAt = createdAt
    }
}
