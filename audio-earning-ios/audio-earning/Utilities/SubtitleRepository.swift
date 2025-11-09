//
//  SubtitleRepository.swift
//  audio-earning
//
//  Created by Codex on 2025/11/04.
//

import Foundation

protocol SubtitleProviding: AnyObject {
    var wordSubtitles: [SubtitleItem] { get }
    var sentenceSubtitles: [SubtitleItem] { get }

    func load(from content: String?) throws
    func load(from url: URL) throws

    func subtitles(for mode: SubtitleDisplayMode) -> [SubtitleItem]
    func index(for time: TimeInterval, mode: SubtitleDisplayMode) -> Int?
    func subtitle(at index: Int, mode: SubtitleDisplayMode) -> SubtitleItem?
    func context(around index: Int, mode: SubtitleDisplayMode) -> SentenceContext?

    var inferredDuration: TimeInterval? { get }
    var inferredWordCount: Int? { get }
}

final class SubtitleRepository: SubtitleProviding {
    private(set) var wordSubtitles: [SubtitleItem] = []
    private(set) var sentenceSubtitles: [SubtitleItem] = []

    private(set) var inferredDuration: TimeInterval?
    private(set) var inferredWordCount: Int?

    func load(from content: String?) throws {
        guard let content else {
            wordSubtitles = []
            sentenceSubtitles = []
            inferredDuration = nil
            inferredWordCount = nil
            return
        }

        let items = try SRTParser.parse(content: content)
        assign(subtitles: items)
    }

    func load(from url: URL) throws {
        let items = try SRTParser.parse(url: url)
        assign(subtitles: items)
    }

    func subtitles(for mode: SubtitleDisplayMode) -> [SubtitleItem] {
        switch mode {
        case .wordLevel: return wordSubtitles
        case .sentenceLevel: return sentenceSubtitles
        }
    }

    func index(for time: TimeInterval, mode: SubtitleDisplayMode) -> Int? {
        let target = subtitles(for: mode)
        guard !target.isEmpty else { return nil }

        var low = 0
        var high = target.count - 1
        var candidate: Int?

        while low <= high {
            let mid = (low + high) / 2
            let item = target[mid]

            if item.contains(time: time) {
                return mid
            }

            if time < item.startTime {
                high = mid - 1
            } else {
                candidate = mid
                low = mid + 1
            }
        }

        return candidate
    }

    func subtitle(at index: Int, mode: SubtitleDisplayMode) -> SubtitleItem? {
        let list = subtitles(for: mode)
        guard list.indices.contains(index) else { return nil }
        return list[index]
    }

    func context(around index: Int, mode: SubtitleDisplayMode) -> SentenceContext? {
        let list = subtitles(for: mode)
        guard list.indices.contains(index) else { return nil }

        let previous = index > 0 ? list[index - 1] : nil
        let next = index + 1 < list.count ? list[index + 1] : nil
        return SentenceContext(index: index, previous: previous, current: list[index], next: next)
    }

    private func assign(subtitles: [SubtitleItem]) {
        wordSubtitles = subtitles
        sentenceSubtitles = mergeSentences(from: subtitles, anticipation: 0.3)

        inferredDuration = calculateDuration(from: subtitles)
        inferredWordCount = calculateWordCount(from: subtitles)
    }

    private func mergeSentences(from wordSubtitles: [SubtitleItem], anticipation: TimeInterval) -> [SubtitleItem] {
        guard !wordSubtitles.isEmpty else { return [] }

        var sentences: [SubtitleItem] = []
        var currentWords: [SubtitleItem] = []
        var sentenceID = wordSubtitles.first?.id ?? 1

        for subtitle in wordSubtitles.sorted(by: { $0.startTime < $1.startTime }) {
            currentWords.append(subtitle)

            if endsSentence(with: subtitle.text) {
                let (createdSentences, nextID) = makeSentenceSegments(
                    from: currentWords,
                    startingID: sentenceID,
                    anticipation: anticipation
                )
                sentences.append(contentsOf: createdSentences)
                sentenceID = nextID
                currentWords.removeAll(keepingCapacity: true)
            }
        }

        let (remainingSentences, _) = makeSentenceSegments(
            from: currentWords,
            startingID: sentenceID,
            anticipation: anticipation
        )
        sentences.append(contentsOf: remainingSentences)

        return sentences
    }

    private func makeSentenceSegments(
        from words: [SubtitleItem],
        startingID: Int,
        anticipation: TimeInterval
    ) -> ([SubtitleItem], Int) {
        guard !words.isEmpty else {
            return ([], startingID)
        }

        let segments = splitWordsIfNeeded(words)
        var results: [SubtitleItem] = []
        var nextID = startingID

        for (index, segment) in segments.enumerated() {
            let leadIn = index == 0 ? anticipation : 0
            if let sentence = makeSentence(from: segment, id: nextID, anticipation: leadIn) {
                results.append(sentence)
                nextID += 1
            }
        }

        return (results, nextID)
    }

    private func makeSentence(
        from words: [SubtitleItem],
        id: Int,
        anticipation: TimeInterval
    ) -> SubtitleItem? {
        guard let first = words.first, let last = words.last else { return nil }

        let sentenceText = words
            .map { $0.text }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !sentenceText.isEmpty else { return nil }

        let sentenceStart = max(0, first.startTime - anticipation)
        let sentenceEnd = max(sentenceStart, last.endTime)

        return SubtitleItem(
            id: id,
            startTime: sentenceStart,
            endTime: sentenceEnd,
            text: sentenceText
        )
    }

    private func endsSentence(with text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        for character in trimmed.reversed() {
            if sentenceTerminators.contains(character) {
                return true
            }

            if character.isLetter || character.isNumber {
                return false
            }
        }

        return false
    }

    private let sentenceTerminators: Set<Character> = [".", "?", "!", ":", ";", "。", "？", "！", "：", "；"]

    private enum SentenceSplitParameters {
        static let maxWords = 18
        static let maxCharacters = 50
    }

    private func splitWordsIfNeeded(_ words: [SubtitleItem]) -> [[SubtitleItem]] {
        guard shouldSplit(words) else {
            return [words]
        }

        return splitByLargestGap(words)
    }

    private func shouldSplit(_ words: [SubtitleItem]) -> Bool {
        guard words.count > SentenceSplitParameters.maxWords else {
            let totalCharacters = words.reduce(0) { partialResult, item in
                partialResult + item.text.count
            } + max(words.count - 1, 0)
            return totalCharacters > SentenceSplitParameters.maxCharacters
        }

        return true
    }

    private func splitByLargestGap(_ words: [SubtitleItem]) -> [[SubtitleItem]] {
        guard words.count >= 2 else { return [words] }

        var largestGap: TimeInterval = -1
        var largestGapIndex: Int = 0

        for index in 0..<(words.count - 1) {
            let current = words[index]
            let next = words[index + 1]
            let gap = max(0, next.startTime - current.endTime)
            if gap > largestGap {
                largestGap = gap
                largestGapIndex = index
            }
        }

        let splitIndex: Int
        if largestGap <= 0 {
            splitIndex = max(0, (words.count / 2) - 1)
        } else {
            splitIndex = largestGapIndex
        }

        let left = Array(words[...splitIndex])
        let right = Array(words[(splitIndex + 1)...])

        var segments: [[SubtitleItem]] = []

        if !left.isEmpty {
            if shouldSplit(left) {
                segments.append(contentsOf: splitByLargestGap(left))
            } else {
                segments.append(left)
            }
        }

        if !right.isEmpty {
            if shouldSplit(right) {
                segments.append(contentsOf: splitByLargestGap(right))
            } else {
                segments.append(right)
            }
        }

        return segments
    }

    private func calculateDuration(from subtitles: [SubtitleItem]) -> TimeInterval? {
        guard !subtitles.isEmpty else { return nil }
        let minStart = subtitles.compactMap { $0.startTime }.min() ?? 0
        let maxEnd = subtitles.compactMap { $0.endTime }.max() ?? 0
        let span = maxEnd - minStart
        guard span > 0 else { return nil }
        return (span * 1000).rounded() / 1000
    }

    private func calculateWordCount(from subtitles: [SubtitleItem]) -> Int? {
        guard !subtitles.isEmpty else { return nil }
        let joined = subtitles.map { $0.text }.joined(separator: " ")
        guard !joined.isEmpty else { return nil }

        let regex = try? NSRegularExpression(pattern: "[A-Za-z][A-Za-z'\\-]*", options: [])
        let range = NSRange(joined.startIndex..<joined.endIndex, in: joined)
        guard let regex else { return nil }
        let matches = regex.numberOfMatches(in: joined, options: [], range: range)
        return matches > 0 ? matches : nil
    }
}
