//
//  ChapterNameParser.swift
//  audio-earning
//
//  Created by Codex on 2025/11/02.
//

import Foundation

enum ChapterNameParser {
    static func chapterIndex(in value: String) -> Int? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lowercased = trimmed.lowercased()

        if lowercased.hasPrefix("chapter") {
            let suffix = lowercased.dropFirst("chapter".count)
            let digits = suffix.compactMap { $0.isNumber ? $0 : nil }
            let hasAlpha = suffix.contains { $0.isLetter && !$0.isNumber }
            if !hasAlpha, !digits.isEmpty {
                return Int(String(digits))
            }
        }

        let letters = lowercased.contains { $0.isLetter }
        if !letters {
            let digits = lowercased.compactMap { $0.isNumber ? $0 : nil }
            if !digits.isEmpty {
                return Int(String(digits))
            }
        }

        return nil
    }

    static func displayTitle(id: String, title: String) -> String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        if let index = chapterIndex(in: trimmedTitle) ?? chapterIndex(in: id) {
            return "Chapter \(index)"
        }

        if !trimmedTitle.isEmpty {
            return trimmedTitle
        }

        return id
    }
}
