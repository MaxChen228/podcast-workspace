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

    init(id: UUID = UUID(), text: String, index: Int, isHighlighted: Bool = false, note: String? = nil) {
        self.id = id
        self.text = text
        self.index = index
        self.isHighlighted = isHighlighted
        self.note = note
    }

    /// Convenience initializer for creating from plain text
    init(text: String, index: Int) {
        self.id = UUID()
        self.text = text
        self.index = index
        self.isHighlighted = false
        self.note = nil
    }

    /// Check if paragraph has a note attached
    var hasNote: Bool {
        note != nil && !(note?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
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
