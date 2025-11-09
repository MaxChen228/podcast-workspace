//
//  SubtitlePresentationController.swift
//  audio-earning
//
//  Created by ChatGPT on 2025/11/04.
//

import Foundation
import Combine

protocol SubtitlePresenting: AnyObject {
    var displayModePublisher: AnyPublisher<SubtitleDisplayMode, Never> { get }
    var displayedSubtitlesPublisher: AnyPublisher<[SubtitleItem], Never> { get }
    var currentSubtitlePublisher: AnyPublisher<SubtitleItem?, Never> { get }
    var currentSubtitleTextPublisher: AnyPublisher<String, Never> { get }
    var currentSubtitleIndexPublisher: AnyPublisher<Int, Never> { get }
    var initialSubtitleIDPublisher: AnyPublisher<Int?, Never> { get }

    var displayMode: SubtitleDisplayMode { get }
    var currentSubtitleIndex: Int { get }

    func loadSubtitles(url: URL?, content: String?) throws
    func setDisplayMode(_ mode: SubtitleDisplayMode)
    func sync(to time: TimeInterval)
    func clear()
    func subtitles(for mode: SubtitleDisplayMode) -> [SubtitleItem]
    func context(around index: Int, mode: SubtitleDisplayMode) -> SentenceContext?
    func initialResumePosition(progress: ChapterProgress?, totalDuration: TimeInterval) -> TimeInterval?
}

final class SubtitlePresentationController: SubtitlePresenting {

    // TODO: Add unit tests covering mode switching, sync offsets, and empty subtitle handling.

    // MARK: - Published State

    @Published private(set) var displayMode: SubtitleDisplayMode
    @Published private var displayedSubtitles: [SubtitleItem]
    @Published private var currentSubtitle: SubtitleItem?
    @Published private var currentSubtitleText: String
    @Published private var currentSubtitleIndexValue: Int
    @Published private var initialSubtitleID: Int?

    // MARK: - Dependencies

    private let subtitleRepository: SubtitleProviding

    // MARK: - Init

    init(
        subtitleRepository: SubtitleProviding = SubtitleRepository(),
        initialDisplayMode: SubtitleDisplayMode = .wordLevel
    ) {
        self.subtitleRepository = subtitleRepository
        self.displayMode = initialDisplayMode
        self.displayedSubtitles = []
        self.currentSubtitle = nil
        self.currentSubtitleText = ""
        self.currentSubtitleIndexValue = 0
        self.initialSubtitleID = nil
    }

    // MARK: - Outputs

    var displayModePublisher: AnyPublisher<SubtitleDisplayMode, Never> {
        $displayMode.eraseToAnyPublisher()
    }

    var displayedSubtitlesPublisher: AnyPublisher<[SubtitleItem], Never> {
        $displayedSubtitles.eraseToAnyPublisher()
    }

    var currentSubtitlePublisher: AnyPublisher<SubtitleItem?, Never> {
        $currentSubtitle.eraseToAnyPublisher()
    }

    var currentSubtitleTextPublisher: AnyPublisher<String, Never> {
        $currentSubtitleText.eraseToAnyPublisher()
    }

    var currentSubtitleIndexPublisher: AnyPublisher<Int, Never> {
        $currentSubtitleIndexValue.eraseToAnyPublisher()
    }

    var initialSubtitleIDPublisher: AnyPublisher<Int?, Never> {
        $initialSubtitleID.eraseToAnyPublisher()
    }

    var currentSubtitleIndex: Int {
        currentSubtitleIndexValue
    }

    // MARK: - Public API

    func loadSubtitles(url: URL?, content: String?) throws {
        do {
            if let content {
                try subtitleRepository.load(from: content)
            } else if let url {
                try subtitleRepository.load(from: url)
            } else {
                try subtitleRepository.load(from: nil)
            }
        } catch {
#if DEBUG
            print("❌ Failed to load subtitles: \(error.localizedDescription)")
#endif
            try? subtitleRepository.load(from: nil)
        }

        updateSubtitleDataSource()
        currentSubtitleIndexValue = 0
        clearCurrentSubtitleMetadata()
#if DEBUG
        print("✅ Loaded \(subtitleRepository.wordSubtitles.count) subtitle entries")
#endif
    }

    func setDisplayMode(_ mode: SubtitleDisplayMode) {
        guard displayMode != mode else { return }
        displayMode = mode
        updateSubtitleDataSource()
        currentSubtitleIndexValue = 0
        clearCurrentSubtitleMetadata()
    }

    func sync(to time: TimeInterval) {
        let subtitles = subtitleRepository.subtitles(for: displayMode)

        guard !subtitles.isEmpty else {
            currentSubtitleIndexValue = 0
            clearCurrentSubtitleMetadata()
            return
        }

        guard let index = subtitleRepository.index(for: time, mode: displayMode),
              let subtitle = subtitleRepository.subtitle(at: index, mode: displayMode) else {
            currentSubtitleIndexValue = 0
            clearCurrentSubtitleMetadata()
            return
        }

        currentSubtitleIndexValue = index
        updateCurrentSubtitle(subtitle)
    }

    func clear() {
        displayedSubtitles = []
        currentSubtitleIndexValue = 0
        clearCurrentSubtitleMetadata()
    }

    func subtitles(for mode: SubtitleDisplayMode) -> [SubtitleItem] {
        subtitleRepository.subtitles(for: mode)
    }

    func context(around index: Int, mode: SubtitleDisplayMode) -> SentenceContext? {
        subtitleRepository.context(around: index, mode: mode)
    }

    func initialResumePosition(progress: ChapterProgress?, totalDuration: TimeInterval) -> TimeInterval? {
        guard let progress else { return nil }
        let duration = totalDuration > 0 ? totalDuration : (progress.totalDurationSec ?? 0)
        guard duration > 0 else { return nil }

        var targetPosition = progress.lastPositionSec
        if progress.isCompleted {
            targetPosition = max(targetPosition, duration)
        }

        let clamped = max(0, min(targetPosition, duration))
        return clamped > 0.5 ? clamped : nil
    }

    // MARK: - Internal helpers

    private func updateSubtitleDataSource() {
        let subtitles = subtitleRepository.subtitles(for: displayMode)
#if DEBUG
        switch displayMode {
        case .wordLevel:
            print("🔄 Switched to word mode: \(subtitles.count) tokens")
        case .sentenceLevel:
            print("🔄 Switched to sentence mode: \(subtitles.count) sentences")
        }
#endif
        displayedSubtitles = subtitles
    }

    private func updateCurrentSubtitle(_ subtitle: SubtitleItem) {
        currentSubtitle = subtitle
        currentSubtitleText = subtitle.text
        if initialSubtitleID == nil {
            initialSubtitleID = subtitle.id
        }
    }

    private func clearCurrentSubtitleMetadata() {
        currentSubtitle = nil
        currentSubtitleText = ""
        initialSubtitleID = nil
    }
}
