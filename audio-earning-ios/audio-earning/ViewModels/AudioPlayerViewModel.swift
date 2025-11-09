//
//  AudioPlayerViewModel.swift
//  audio-earning
//
//  Created by Claude on 2025/10/27.
//

import Foundation
import AVFoundation
import Combine

/// Audio player view model using MVVM.
/// Relies on AVAudioEngine for playback and real-time analysis.
enum PlaybackRateAdjustmentResult {
    case applied
    case reachedMinimum
    case reachedMaximum
}

@MainActor
class AudioPlayerViewModel: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published var playerState: AudioPlayerState = .idle
    @Published var currentTime: TimeInterval = 0
    @Published var totalDuration: TimeInterval = 0
    @Published var currentSubtitle: SubtitleItem?
    @Published var currentSubtitleText: String = ""
    @Published var progress: Double = 0 // 0.0 ~ 1.0
    @Published private(set) var displayedSubtitles: [SubtitleItem] = []
    @Published private(set) var initialSubtitleID: Int?
    @Published private(set) var currentSubtitleIndex: Int = 0
    @Published var sentenceDetail: SentenceDetailState?
    @Published private(set) var wordCount: Int?
    @Published private(set) var audioDurationSec: Double?
    @Published private(set) var wordsPerMinute: Double? {
        didSet {
            isUsingEstimatedWordsPerMinute = wordsPerMinute == nil
            synchronizeDeltaWithPlaybackRate()
        }
    }
    @Published private(set) var speakingPaceKey: String?
    @Published private(set) var playbackRate: Double = 1.0
    @Published private(set) var wordsPerMinuteDelta: Int = 0
    @Published private(set) var isUsingEstimatedWordsPerMinute: Bool = false
    @Published var subtitleAppearance: SubtitleAppearance
    @Published var lexiconSaveFeedback: LexiconSaveFeedback?

    // Highlighted word storage
    @Published private(set) var highlightedWords: Set<String> = []

    // Subtitle display mode
    @Published private(set) var displayMode: SubtitleDisplayMode = .wordLevel

    // MARK: - Private Properties

    private let playbackController: AudioPlaybackControlling
    private let playbackSession: PlaybackSessionCoordinating
    private let bookID: String?
    private let chapterID: String?
    private let appearanceStore: SubtitleAppearancePersisting
    private let appearanceController: SubtitleAppearanceManaging
    private let apiService: APIServiceProtocol
    private let lexiconStore: SavedLexiconStoring
    private let subtitleRepository: SubtitleProviding
    private let subtitlePresenter: SubtitlePresenting
    private let highlightStore: HighlightLexiconManaging
    private let explanationService: SentenceExplaining
    private lazy var sentenceDetailCoordinator: SentenceDetailCoordinating = {
        SentenceDetailCoordinator(
            subtitlePresenter: self.subtitlePresenter,
            explanationService: self.explanationService,
            lexiconStore: self.lexiconStore,
            defaultLanguage: self.defaultExplanationLanguage,
            bookID: self.bookID,
            chapterID: self.chapterID
        )
    }()
    private var savedProgress: ChapterProgress?
    private var audioSessionConfigured = false

    private var cancellables: Set<AnyCancellable> = []
    private let defaultExplanationLanguage = "zh-TW"
    private let defaultWordsPerMinute: Double = 200
    private let wordsPerMinuteStep: Int = 5
    private let minimumPlaybackRate: Double = 0.5
    private let maximumPlaybackRate: Double = 2.0

    // MARK: - Initialization

    init(
        bookID: String? = nil,
        chapterID: String? = nil,
        initialMetrics: ChapterPlaybackMetrics? = nil,
        initialProgress: ChapterProgress? = nil,
        appearanceStore: SubtitleAppearancePersisting? = nil,
        appearanceController: SubtitleAppearanceManaging? = nil,
        apiService: APIServiceProtocol? = nil,
        lexiconStore: SavedLexiconStoring? = nil,
        highlightStore: HighlightLexiconManaging? = nil,
        playbackController: AudioPlaybackControlling? = nil,
        progressTracker: PlaybackProgressTracking? = nil,
        subtitleRepository: SubtitleProviding? = nil,
        subtitlePresenter: SubtitlePresenting? = nil,
        explanationService: SentenceExplaining? = nil
    ) {
        self.bookID = bookID
        self.chapterID = chapterID
        let resolvedAppearanceStore = appearanceStore ?? SubtitleAppearanceStore.shared
        self.appearanceStore = resolvedAppearanceStore
        if let appearanceController {
            self.appearanceController = appearanceController
        } else {
            self.appearanceController = SubtitleAppearanceController(store: resolvedAppearanceStore)
        }
        self.apiService = apiService ?? APIService.shared
        if let lexiconStore = lexiconStore {
            self.lexiconStore = lexiconStore
        } else {
            self.lexiconStore = SavedLexiconStore.shared
        }
        let resolvedPlaybackController = playbackController ?? AudioPlaybackController()
        self.playbackController = resolvedPlaybackController
        let resolvedProgressTracker = progressTracker ?? PlaybackProgressTracker()
        self.playbackSession = PlaybackSessionCoordinator(
            playbackController: resolvedPlaybackController,
            progressTracker: resolvedProgressTracker
        )
        let resolvedSubtitleRepository = subtitleRepository ?? SubtitleRepository()
        self.subtitleRepository = resolvedSubtitleRepository
        if let subtitlePresenter {
            self.subtitlePresenter = subtitlePresenter
        } else {
            self.subtitlePresenter = SubtitlePresentationController(subtitleRepository: resolvedSubtitleRepository)
        }
        self.highlightStore = highlightStore ?? HighlightLexiconStore.shared
        self.explanationService = explanationService ?? SentenceExplanationService(apiService: self.apiService)
        self.wordCount = initialMetrics?.wordCount
        self.audioDurationSec = initialMetrics?.audioDurationSec
        self.wordsPerMinute = initialMetrics?.wordsPerMinute
        self.speakingPaceKey = initialMetrics?.speakingPaceKey
        self.savedProgress = initialProgress
        self.subtitleAppearance = self.appearanceController.currentAppearance
        super.init()
        playbackSession.setDelegate(self)
        playbackSession.prepareContext(
            bookID: bookID,
            chapterID: chapterID,
            initialProgress: initialProgress
        )
        isUsingEstimatedWordsPerMinute = wordsPerMinute == nil
        synchronizeDeltaWithPlaybackRate()
        setupAudioSession()
        highlightedWords = self.highlightStore.currentWords
        bindHighlightStore()
        bindAppearanceController()
        bindSubtitlePresenter()
        bindSentenceDetailCoordinator()
        displayMode = self.subtitlePresenter.displayMode
    }

    override convenience init() {
        self.init(bookID: nil, chapterID: nil, initialMetrics: nil, initialProgress: nil)
    }

    // MARK: - Setup

    private func setupAudioSession() {
#if os(iOS)
        guard !audioSessionConfigured else { return }
        do {
            let audioSession = AVAudioSession.sharedInstance()
            if audioSession.category != .playback {
                try audioSession.setCategory(.playback, mode: .default)
            }
            try audioSession.setActive(true, options: [.notifyOthersOnDeactivation])
            audioSessionConfigured = true
        } catch {
            audioSessionConfigured = false
#if DEBUG
            print("❌ Failed to configure audio session: \(error.localizedDescription)")
#endif
        }
#endif
    }

    private func bindHighlightStore() {
        highlightStore.wordsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] words in
                self?.highlightedWords = words
            }
            .store(in: &cancellables)
    }

    private func bindAppearanceController() {
        appearanceController.appearancePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] appearance in
                self?.subtitleAppearance = appearance
            }
            .store(in: &cancellables)
    }

    private func bindSubtitlePresenter() {
        subtitlePresenter.displayModePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mode in
                guard let self else { return }
                self.displayMode = mode
                if mode == .wordLevel {
                    Task { @MainActor [weak self] in
                        self?.resetSentenceDetail()
                    }
                }
            }
            .store(in: &cancellables)

        subtitlePresenter.displayedSubtitlesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] subtitles in
                self?.displayedSubtitles = subtitles
            }
            .store(in: &cancellables)

        subtitlePresenter.currentSubtitlePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] subtitle in
                self?.currentSubtitle = subtitle
            }
            .store(in: &cancellables)

        subtitlePresenter.currentSubtitleTextPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.currentSubtitleText = text
            }
            .store(in: &cancellables)

        subtitlePresenter.currentSubtitleIndexPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] index in
                guard let self else { return }
                self.currentSubtitleIndex = index
                if self.displayMode == .sentenceLevel, self.sentenceDetail != nil {
                    Task { @MainActor [weak self] in
                        self?.sentenceDetailCoordinator.refreshDetail(for: index)
                    }
                }
            }
            .store(in: &cancellables)

        subtitlePresenter.initialSubtitleIDPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] initialID in
                self?.initialSubtitleID = initialID
            }
            .store(in: &cancellables)
    }

    private func bindSentenceDetailCoordinator() {
        sentenceDetailCoordinator.sentenceDetailPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] detail in
                self?.sentenceDetail = detail
            }
            .store(in: &cancellables)

        sentenceDetailCoordinator.lexiconFeedbackPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] feedback in
                self?.lexiconSaveFeedback = feedback
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    /// Load audio and optional subtitles.
    /// - Parameters:
    ///   - audioURL: Local audio file URL
    ///   - subtitleURL: Optional SRT subtitle URL
    @MainActor
    func loadAudio(audioURL: URL, subtitleURL: URL? = nil, subtitleContent: String? = nil) {
        playerState = .loading
        playbackSession.stop()
        resetSentenceDetail()

        do {
            try playbackSession.loadAudio(url: audioURL)
            playbackSession.setPlaybackRate(playbackRate)

            totalDuration = playbackController.duration
            updateMetricsWithAudioDuration(totalDuration)

            currentTime = 0
            progress = 0
            subtitlePresenter.clear()
            explanationService.clearCache()

            // Load and preprocess subtitles
            let initialProgress = savedProgress
            loadSubtitlesIfNeeded(url: subtitleURL, content: subtitleContent)

            playbackSession.prepareContext(
                bookID: bookID,
                chapterID: chapterID,
                initialProgress: initialProgress
            )

            playbackSession.configureSession(
                totalDuration: totalDuration,
                audioDuration: audioDurationSec,
                savedProgress: initialProgress,
                subtitlePresenter: subtitlePresenter
            )

            savedProgress = nil
        } catch {
            playerState = .error(error.localizedDescription)
            print("❌ Failed to load audio: \(error.localizedDescription)")
        }
    }

    /// Returns true if the word is currently highlighted.
    func isWordHighlighted(_ word: String) -> Bool {
        highlightStore.contains(word)
    }

    /// Highlight the specified word.
    func highlightWord(_ word: String) {
        highlightStore.add(word)
    }

    /// Remove highlight from the specified word.
    func removeHighlight(_ word: String) {
        highlightStore.remove(word)
    }

    /// Returns the normalized version of the word.
    func normalizedWord(_ word: String) -> String {
        return highlightStore.normalized(word)
    }

    /// Clear all highlighted words.
    func clearAllHighlightedWords() {
        highlightStore.clear()
    }

    /// Sorted highlighted words for display.
    var highlightedWordsSorted: [String] {
        highlightStore.sortedWords()
    }

    /// Count of highlighted words.
    var highlightedWordsCount: Int {
        highlightedWords.count
    }

    // MARK: - Appearance

    func updateSubtitleAppearance(_ appearance: SubtitleAppearance) {
        appearanceController.updateAppearance(appearance)
    }

    func setSubtitleFont(_ option: SubtitleFontOption) {
        appearanceController.setFont(option)
    }

    func setSubtitleTextSize(_ size: SubtitleTextSize) {
        appearanceController.setTextSize(size)
    }

    func setSubtitleTheme(_ theme: SubtitleTheme) {
        appearanceController.setTheme(theme)
    }

    func setPlaybackRate(_ rate: Double) {
        let clamped = max(minimumPlaybackRate, min(rate, maximumPlaybackRate))
        guard abs(playbackRate - clamped) > 0.0001 else { return }
        playbackRate = clamped
        playbackSession.setPlaybackRate(clamped)
        synchronizeDeltaWithPlaybackRate()
    }

    /// Start playback.
    @MainActor
    func play() {
        playbackSession.play()
    }

    /// Pause playback.
    @MainActor
    func pause() {
        playbackSession.pause()
    }

    private func loadSubtitlesIfNeeded(url: URL?, content: String?) {
        try? subtitlePresenter.loadSubtitles(url: url, content: content)
        updateMetricsFromSubtitles()
    }

    /// Toggle between play and pause.
    @MainActor
    func togglePlayPause() {
        switch playerState {
        case .playing:
            pause()
        case .finished:
            play()
        default:
            play()
        }
    }

    /// Seek to a specific time.
    /// - Parameter time: Target time in seconds
    @MainActor
    func seek(to time: TimeInterval, autoResume: Bool = true) {
        let clampedTime = max(0, min(totalDuration, time))
        let shouldResume = autoResume && (playerState == .playing || playbackController.isPlaying)
        playbackSession.seek(to: clampedTime, autoResume: shouldResume)
    }

    /// Skip forward or backward.
    /// - Parameter seconds: Positive to fast-forward, negative to rewind
    @MainActor
    func skip(seconds: Double) {
        playbackSession.skip(seconds: seconds)
    }

    /// Persist the current listening position immediately.
    func persistListeningPosition() {
        let shouldMarkCompleted = playerState == .finished || currentTime >= totalDuration - 0.01
        playbackSession.persistProgress(force: true, completed: shouldMarkCompleted)
    }

    /// Change the subtitle display mode.
    /// - Parameter mode: New mode to activate
    @MainActor
    func setDisplayMode(_ mode: SubtitleDisplayMode) {
        guard displayMode != mode else { return }
        subtitlePresenter.setDisplayMode(mode)
        subtitlePresenter.sync(to: currentTime)
    }

    // MARK: - Playback Speed

    private var effectiveBaseWordsPerMinute: Double {
        let base = wordsPerMinute
        if let base, base.isFinite, base > 0 {
            return base
        }
        return defaultWordsPerMinute
    }

    private func minDeltaAllowed(for base: Double) -> Int {
        let minimumTarget = base * minimumPlaybackRate
        let steps = Int(ceil((minimumTarget - base) / Double(wordsPerMinuteStep)))
        return steps * wordsPerMinuteStep
    }

    private func maxDeltaAllowed(for base: Double) -> Int {
        let maximumTarget = base * maximumPlaybackRate
        let steps = Int(floor((maximumTarget - base) / Double(wordsPerMinuteStep)))
        return steps * wordsPerMinuteStep
    }

    private func synchronizeDeltaWithPlaybackRate() {
        let base = effectiveBaseWordsPerMinute
        let minDelta = minDeltaAllowed(for: base)
        let maxDelta = maxDeltaAllowed(for: base)
        let target = base * playbackRate
        let rawDelta = target - base
        let snappedSteps = Int(round(rawDelta / Double(wordsPerMinuteStep)))
        let snappedDelta = snappedSteps * wordsPerMinuteStep
        let clampedDelta = max(minDelta, min(maxDelta, snappedDelta))
        if wordsPerMinuteDelta != clampedDelta {
            wordsPerMinuteDelta = clampedDelta
        }
    }

    private func applyPlaybackRateForCurrentDelta(base: Double? = nil) {
        let resolvedBase = base ?? effectiveBaseWordsPerMinute
        guard resolvedBase > 0 else { return }
        let target = resolvedBase + Double(wordsPerMinuteDelta)
        let rate = target / resolvedBase
        setPlaybackRate(rate)
    }

    @discardableResult
    func adjustWordsPerMinute(by step: Int) -> PlaybackRateAdjustmentResult {
        guard step != 0 else {
            applyPlaybackRateForCurrentDelta()
            return .applied
        }

        let base = effectiveBaseWordsPerMinute
        let minDelta = minDeltaAllowed(for: base)
        let maxDelta = maxDeltaAllowed(for: base)

        var newDelta = wordsPerMinuteDelta + step
        if newDelta > maxDelta {
            newDelta = maxDelta
        } else if newDelta < minDelta {
            newDelta = minDelta
        }

        let reachedUpper = newDelta == maxDelta && step > 0
        let reachedLower = newDelta == minDelta && step < 0

        wordsPerMinuteDelta = newDelta
        applyPlaybackRateForCurrentDelta(base: base)

        if reachedUpper {
            return .reachedMaximum
        }
        if reachedLower {
            return .reachedMinimum
        }
        return .applied
    }

    var metricsBadgeTitle: String? {
        let base = effectiveBaseWordsPerMinute
        let rounded = Int(round(base))
        return "\(rounded)"
    }

    var metricsBadgeDeltaText: String? {
        guard wordsPerMinuteDelta != 0 else { return nil }
        let sign = wordsPerMinuteDelta > 0 ? "+" : ""
        return "(\(sign)\(wordsPerMinuteDelta))"
    }

    var currentWordsPerMinuteDisplay: Int {
        let base = effectiveBaseWordsPerMinute
        return Int(round(base + Double(wordsPerMinuteDelta)))
    }

    var playbackMultiplierText: String {
        let base = effectiveBaseWordsPerMinute
        guard base > 0 else { return "×1.00" }
        let multiplier = max(minimumPlaybackRate, min(maximumPlaybackRate, (base + Double(wordsPerMinuteDelta)) / base))
        return String(format: "×%.2f", multiplier)
    }

    // MARK: - Metrics

    private func updateMetricsWithAudioDuration(_ duration: TimeInterval) {
        guard duration.isFinite, duration > 0 else { return }
        let roundedDuration = (duration * 1000).rounded() / 1000
        if audioDurationSec == nil {
            audioDurationSec = roundedDuration
        }
        if let wordCount, wordsPerMinute == nil {
            wordsPerMinute = round((Double(wordCount) / (roundedDuration / 60.0)) * 10) / 10
        }
    }

    private func updateMetricsFromSubtitles() {
        if audioDurationSec == nil,
           let duration = subtitleRepository.inferredDuration {
            audioDurationSec = duration
        }

        if wordCount == nil,
           let count = subtitleRepository.inferredWordCount {
            wordCount = count
        }

        if wordsPerMinute == nil,
           let wc = wordCount,
           let duration = audioDurationSec,
           duration > 0 {
            wordsPerMinute = round((Double(wc) / (duration / 60.0)) * 10) / 10
        }
    }

    private func paceDescription(for key: String) -> String {
        switch key.lowercased() {
        case "slow":
            return "Profile: Slow"
        case "fast":
            return "Profile: Fast"
        case "neutral":
            return "Profile: Neutral"
        default:
            return "Profile: \(key.capitalized)"
        }
    }

    private func formatDuration(seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "" }
        let totalSeconds = Int(round(seconds))
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    // MARK: - Sentence Detail

    var canShowSentenceDetail: Bool {
        displayMode == .sentenceLevel && currentSubtitle != nil
    }

    @MainActor
    func presentSentenceDetail() {
        guard displayMode == .sentenceLevel else { return }
        sentenceDetailCoordinator.presentDetail(at: currentSubtitleIndex)
    }

    @MainActor
    func dismissSentenceDetail() {
        sentenceDetailCoordinator.dismissDetail()
    }

    @MainActor
    private func resetSentenceDetail() {
        sentenceDetailCoordinator.reset()
    }

    @MainActor
    func jumpToSentence(offset: Int) {
        guard displayMode == .sentenceLevel else { return }
        let targetIndex = currentSubtitleIndex + offset
        let sentenceSubtitles = subtitlePresenter.subtitles(for: .sentenceLevel)
        guard sentenceSubtitles.indices.contains(targetIndex) else { return }

        let isPresentingDetail = sentenceDetail != nil
        let target = sentenceSubtitles[targetIndex]
        seek(to: target.startTime, autoResume: false)
        if isPresentingDetail {
            sentenceDetailCoordinator.refreshDetail(for: targetIndex)
        } else {
            sentenceDetailCoordinator.presentDetail(at: targetIndex)
        }
    }

    @MainActor
    func requestSentenceExplanation(language: String? = nil) {
        sentenceDetailCoordinator.requestExplanation(language: language)
    }

    @MainActor
    func saveCurrentExplanation() {
        sentenceDetailCoordinator.saveCurrentExplanation()
    }

    @MainActor
    func toggleWordSelection(_ word: String) {
        sentenceDetailCoordinator.toggleWordSelection(word)
    }

    @MainActor
    func clearSelectedWords() {
        sentenceDetailCoordinator.clearSelectedWords()
    }

    func isWordSelected(_ word: String, in detail: SentenceDetailState) -> Bool {
        let normalized = word
            .trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.symbols))
            .lowercased()
        return detail.selectedWords.contains(normalized)
    }
    /// Pause playback when the user interacts (scrub/tap) and wait for manual resume.
    @MainActor
    func pauseForUserInteraction() {
        playbackSession.pauseForUserInteraction()
    }
}

struct SentenceContext: Equatable {
    let index: Int
    let previous: SubtitleItem?
    let current: SubtitleItem
    let next: SubtitleItem?
}

struct SentenceVocabularyItem: Identifiable, Equatable {
    let id = UUID()
    let word: String
    let meaning: String
    let note: String?

    static func == (lhs: SentenceVocabularyItem, rhs: SentenceVocabularyItem) -> Bool {
        lhs.word.caseInsensitiveCompare(rhs.word) == .orderedSame
            && lhs.meaning == rhs.meaning
            && lhs.note == rhs.note
    }
}

struct SentenceExplanationViewData: Equatable {
    let overview: String
    let keyPoints: [String]
    let vocabulary: [SentenceVocabularyItem]
    let chineseMeaning: String?
}

enum SentenceExplanationState: Equatable {
    case idle
    case loading
    case loaded(data: SentenceExplanationViewData, cached: Bool)
    case failure(message: String)

    static func == (lhs: SentenceExplanationState, rhs: SentenceExplanationState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading):
            return true
        case let (.loaded(lhsData, lhsCached), .loaded(rhsData, rhsCached)):
            return lhsData == rhsData && lhsCached == rhsCached
        case let (.failure(lhsMessage), .failure(rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}

struct SentenceDetailState: Identifiable, Equatable {
    var context: SentenceContext
    var explanationState: SentenceExplanationState = .idle
    var selectedWords: Set<String> = []

    var id: Int { context.current.id }
    var subtitle: SubtitleItem { context.current }

    /// 選中的詞組（按原句順序連接）
    var selectedPhrase: String? {
        guard !selectedWords.isEmpty else { return nil }
        // 從原句中提取選中單字的順序
        let tokens = context.current.text.split(whereSeparator: { $0.isWhitespace })
        let selected = tokens.compactMap { word -> String? in
            let display = String(word)
            let normalized = display
                .trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.symbols))
                .lowercased()
            return selectedWords.contains(normalized) ? display : nil
        }
        return selected.isEmpty ? nil : selected.joined(separator: " ")
    }

    static func == (lhs: SentenceDetailState, rhs: SentenceDetailState) -> Bool {
        lhs.id == rhs.id
            && lhs.context == rhs.context
            && lhs.explanationState == rhs.explanationState
            && lhs.selectedWords == rhs.selectedWords
    }
}

struct LexiconSaveFeedback: Identifiable {
    enum Kind { case success, failure }
    let id = UUID()
    let kind: Kind
    let message: String
}

@MainActor
extension AudioPlayerViewModel: PlaybackSessionCoordinatorDelegate {
    func playbackSession(_ coordinator: PlaybackSessionCoordinating, didProduce snapshot: PlaybackSnapshot) {
        totalDuration = snapshot.totalDuration
        currentTime = snapshot.currentTime
        progress = snapshot.progress
        if playerState != snapshot.state {
            playerState = snapshot.state
        }
    }

    func playbackSessionDidFinish(_ coordinator: PlaybackSessionCoordinating) {
        // Additional handling can be added if needed. Snapshot updates already set state to .finished.
    }
}
