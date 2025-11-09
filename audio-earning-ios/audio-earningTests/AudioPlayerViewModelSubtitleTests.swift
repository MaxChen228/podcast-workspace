@testable import audio_earning
import XCTest

final class AudioPlayerViewModelSubtitleTests: XCTestCase {

    @MainActor
    func testInitialSubtitleIDReflectsCurrentTimeOnModeSwitch() async throws {
        let subtitles = [
            SubtitleItem(id: 1, startTime: 0, endTime: 1.5, text: "Hello"),
            SubtitleItem(id: 2, startTime: 1.5, endTime: 4.0, text: "world")
        ]

        let repository = MockSubtitleRepository(wordSubtitles: subtitles, sentenceSubtitles: subtitles)
        let playback = MockPlaybackController()
        let progressTracker = MockProgressTracker()
        let explanationService = MockSentenceExplainer()
        let appearanceDefaults = UserDefaults(suiteName: "AudioPlayerViewModelSubtitleTests-\(UUID().uuidString)")!
        appearanceDefaults.removePersistentDomain(forName: appearanceDefaultsSuiteName(appearanceDefaults))
        let appearanceStore = SubtitleAppearanceStore(defaults: appearanceDefaults)
        let appearanceController = SubtitleAppearanceController(store: appearanceStore)

        SavedLexiconStore.shared.clearAll()

        let viewModel = AudioPlayerViewModel(
            bookID: "book",
            chapterID: "chapter",
            appearanceStore: appearanceStore,
            appearanceController: appearanceController,
            playbackController: playback,
            progressTracker: progressTracker,
            subtitleRepository: repository,
            explanationService: explanationService
        )

        viewModel.currentTime = 2.5
        viewModel.setDisplayMode(.sentenceLevel)

        XCTAssertEqual(viewModel.initialSubtitleID, 2)
        XCTAssertEqual(viewModel.currentSubtitle?.id, 2)
    }
}

// MARK: - Test Doubles

private final class MockSubtitleRepository: SubtitleProviding {
    var wordSubtitles: [SubtitleItem]
    var sentenceSubtitles: [SubtitleItem]

    var inferredDuration: TimeInterval?
    var inferredWordCount: Int?

    init(wordSubtitles: [SubtitleItem], sentenceSubtitles: [SubtitleItem]) {
        self.wordSubtitles = wordSubtitles
        self.sentenceSubtitles = sentenceSubtitles
        inferredDuration = sentenceSubtitles.last?.endTime
        inferredWordCount = wordSubtitles.count
    }

    func load(from content: String?) throws {}

    func load(from url: URL) throws {}

    func subtitles(for mode: SubtitleDisplayMode) -> [SubtitleItem] {
        switch mode {
        case .wordLevel:
            return wordSubtitles
        case .sentenceLevel:
            return sentenceSubtitles
        }
    }

    func index(for time: TimeInterval, mode: SubtitleDisplayMode) -> Int? {
        let list = subtitles(for: mode)
        guard !list.isEmpty else { return nil }

        if let match = list.firstIndex(where: { $0.contains(time: time) }) {
            return match
        }

        if let previous = list.lastIndex(where: { $0.startTime <= time }) {
            return previous
        }

        return 0
    }

    func subtitle(at index: Int, mode: SubtitleDisplayMode) -> SubtitleItem? {
        let list = subtitles(for: mode)
        guard list.indices.contains(index) else { return nil }
        return list[index]
    }

    func context(around index: Int, mode: SubtitleDisplayMode) -> SentenceContext? {
        nil
    }
}

private func appearanceDefaultsSuiteName(_ defaults: UserDefaults) -> String {
    defaults.volatileDomainNames.first(where: { defaults.persistentDomain(forName: $0) != nil }) ?? ""
}

private final class MockPlaybackController: AudioPlaybackControlling {
    var duration: TimeInterval = 10
    var isPlaying: Bool = false
    var playbackRate: Double = 1.0

    private var currentTimeValue: TimeInterval = 0

    func loadAudio(url: URL, completion: (() -> Void)?) throws {}

    func play() {
        isPlaying = true
    }

    func pause() {
        isPlaying = false
    }

    func stop() {
        isPlaying = false
    }

    func seek(to time: TimeInterval, autoResume: Bool) {
        currentTimeValue = time
        isPlaying = autoResume
    }

    func currentTime() -> TimeInterval? {
        currentTimeValue
    }

    func setPlaybackRate(_ rate: Double) {
        playbackRate = rate
    }
}

private actor MockProgressTracker: PlaybackProgressTracking {
    func updateContext(bookID: String?, chapterID: String?, initialProgress: ChapterProgress?) async {}

    func record(_ snapshot: PlaybackProgressSnapshot) async {}

    func reset() async {}
}

private final class MockSentenceExplainer: SentenceExplaining {
    func cachedExplanation(subtitleID: Int, language: String, phrase: String?) -> SentenceExplanationViewData? {
        nil
    }

    func fetchSentenceExplanation(context: SentenceContext, language: String) async throws -> SentenceExplanationResult {
        throw CancellationError()
    }

    func fetchPhraseExplanation(_ phrase: String, context: SentenceContext, language: String) async throws -> SentenceExplanationResult {
        throw CancellationError()
    }

    func clearCache() {}
}
