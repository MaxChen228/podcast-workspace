//
//  PlaybackSessionCoordinator.swift
//  audio-earning
//
//  Created by ChatGPT on 2025/11/05.
//

import Foundation
import Combine

struct PlaybackSnapshot: Equatable {
    var state: AudioPlayerState
    var currentTime: TimeInterval
    var totalDuration: TimeInterval
    var progress: Double
}

@MainActor
protocol PlaybackSessionCoordinatorDelegate: AnyObject {
    func playbackSession(_ coordinator: PlaybackSessionCoordinating, didProduce snapshot: PlaybackSnapshot)
    func playbackSessionDidFinish(_ coordinator: PlaybackSessionCoordinating)
}

@MainActor
protocol PlaybackSessionCoordinating: AnyObject {
    var snapshotPublisher: AnyPublisher<PlaybackSnapshot, Never> { get }
    var completionPublisher: AnyPublisher<Void, Never> { get }
    var currentSnapshot: PlaybackSnapshot { get }
    var playbackRate: Double { get }

    func setDelegate(_ delegate: PlaybackSessionCoordinatorDelegate?)
    func prepareContext(bookID: String?, chapterID: String?, initialProgress: ChapterProgress?)
    func loadAudio(url: URL) throws
    func configureSession(totalDuration: TimeInterval, audioDuration: Double?, savedProgress: ChapterProgress?, subtitlePresenter: SubtitlePresenting)
    func clearSavedProgress()
    func play()
    func pause()
    func togglePlayPause()
    func pauseForUserInteraction()
    func seek(to time: TimeInterval, autoResume: Bool)
    func skip(seconds: Double)
    func setPlaybackRate(_ rate: Double)
    func persistProgress(force: Bool, completed: Bool)
    func stop()
}

@MainActor
final class PlaybackSessionCoordinator: PlaybackSessionCoordinating {
    private let playbackController: AudioPlaybackControlling
    private let progressTracker: PlaybackProgressTracking

    private weak var subtitlePresenter: SubtitlePresenting?
    private weak var delegate: PlaybackSessionCoordinatorDelegate?

    private let snapshotSubject: CurrentValueSubject<PlaybackSnapshot, Never>
    private let completionSubject = PassthroughSubject<Void, Never>()

    private var timer: Timer?
    private let timerInterval: TimeInterval = 1.0 / 30.0

    private(set) var playbackRate: Double = 1.0
    private var audioDurationSec: Double?
    private var savedProgress: ChapterProgress?

    private var activeTask: Task<Void, Never>?

    init(
        playbackController: AudioPlaybackControlling,
        progressTracker: PlaybackProgressTracking
    ) {
        self.playbackController = playbackController
        self.progressTracker = progressTracker
        let initialSnapshot = PlaybackSnapshot(state: .idle, currentTime: 0, totalDuration: 0, progress: 0)
        self.snapshotSubject = CurrentValueSubject(initialSnapshot)
    }

    var snapshotPublisher: AnyPublisher<PlaybackSnapshot, Never> {
        snapshotSubject.eraseToAnyPublisher()
    }

    var completionPublisher: AnyPublisher<Void, Never> {
        completionSubject.eraseToAnyPublisher()
    }

    var currentSnapshot: PlaybackSnapshot {
        snapshotSubject.value
    }

    func setDelegate(_ delegate: PlaybackSessionCoordinatorDelegate?) {
        self.delegate = delegate
    }

    func prepareContext(bookID: String?, chapterID: String?, initialProgress: ChapterProgress?) {
        activeTask?.cancel()
        activeTask = Task {
            await progressTracker.updateContext(bookID: bookID, chapterID: chapterID, initialProgress: initialProgress)
        }
    }

    func loadAudio(url: URL) throws {
        try playbackController.loadAudio(url: url) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.handlePlaybackFinished()
            }
        }
    }

    func configureSession(
        totalDuration: TimeInterval,
        audioDuration: Double?,
        savedProgress: ChapterProgress?,
        subtitlePresenter: SubtitlePresenting
    ) {
        self.subtitlePresenter = subtitlePresenter
        self.audioDurationSec = audioDuration
        self.savedProgress = savedProgress

        var snapshot = snapshotSubject.value
        snapshot.totalDuration = totalDuration
        snapshot.currentTime = 0
        snapshot.progress = 0
        snapshot.state = .ready
        snapshotSubject.send(snapshot)
        notifyDelegate(with: snapshot)

        applyInitialProgressIfNeeded()
    }

    func clearSavedProgress() {
        savedProgress = nil
    }

    func play() {
        var snapshot = snapshotSubject.value
        let finished = snapshot.state == .finished || snapshot.currentTime >= snapshot.totalDuration - 0.001
        if finished {
            let effectiveDuration = snapshot.totalDuration > 0 ? snapshot.totalDuration : (audioDurationSec ?? 0)
            let resumeTime: TimeInterval
            if effectiveDuration > 0 {
                resumeTime = max(0, min(effectiveDuration - 0.25, snapshot.currentTime))
            } else {
                resumeTime = snapshot.currentTime
            }

            playbackController.seek(to: resumeTime, autoResume: true)
            refreshCurrentTime(fallback: resumeTime)
        } else {
            playbackController.play()
            refreshCurrentTime()
        }

        snapshot = snapshotSubject.value
        snapshot.state = .playing
        updateProgress()
        startTimer()
        subtitlePresenter?.sync(to: snapshot.currentTime)
        snapshotSubject.send(snapshot)
        notifyDelegate(with: snapshot)
    }

    func pause() {
        refreshCurrentTime()
        playbackController.pause()
        stopTimer()
        var snapshot = snapshotSubject.value
        snapshot.state = .paused
        updateProgress()
        subtitlePresenter?.sync(to: snapshot.currentTime)
        snapshotSubject.send(snapshot)
        notifyDelegate(with: snapshot)
        persistProgress(force: true, completed: false)
    }

    func togglePlayPause() {
        switch snapshotSubject.value.state {
        case .playing:
            pause()
        case .finished:
            play()
        default:
            play()
        }
    }

    func pauseForUserInteraction() {
        if snapshotSubject.value.state == .playing {
            pause()
        }
    }

    func seek(to time: TimeInterval, autoResume: Bool) {
        let totalDuration = snapshotSubject.value.totalDuration
        let clampedTime = max(0, min(totalDuration, time))
        let shouldResume = autoResume && (snapshotSubject.value.state == .playing || playbackController.isPlaying)

        playbackController.seek(to: clampedTime, autoResume: shouldResume)

        refreshCurrentTime(fallback: clampedTime)
        updateProgress()
        subtitlePresenter?.sync(to: snapshotSubject.value.currentTime)

        if shouldResume {
            var snapshot = snapshotSubject.value
            snapshot.state = .playing
            startTimer()
            snapshotSubject.send(snapshot)
            notifyDelegate(with: snapshot)
        } else {
            stopTimer()
            var snapshot = snapshotSubject.value
            snapshot.state = .paused
            snapshotSubject.send(snapshot)
            notifyDelegate(with: snapshot)
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.refreshCurrentTime()
            self.updateProgress()
            self.subtitlePresenter?.sync(to: self.snapshotSubject.value.currentTime)
            self.notifyDelegate(with: self.snapshotSubject.value)
        }

        persistProgress(force: true, completed: false)
    }

    func skip(seconds: Double) {
        let newTime = snapshotSubject.value.currentTime + seconds
        seek(to: newTime, autoResume: snapshotSubject.value.state == .playing)
    }

    func setPlaybackRate(_ rate: Double) {
        playbackRate = rate
        playbackController.setPlaybackRate(rate)
    }

    func persistProgress(force: Bool, completed: Bool) {
        let snapshot = snapshotSubject.value
        let effectiveDuration = snapshot.totalDuration > 0 ? snapshot.totalDuration : (audioDurationSec ?? 0)
        let durationValue = effectiveDuration > 0 ? effectiveDuration : nil
        let snapshotForTracker = PlaybackProgressSnapshot(
            position: snapshot.currentTime,
            duration: durationValue,
            force: force,
            completed: completed
        )
        let tracker = progressTracker
        Task(priority: .utility) {
            await tracker.record(snapshotForTracker)
        }
    }

    func stop() {
        stopTimer()
        playbackController.stop()
        var snapshot = snapshotSubject.value
        snapshot.state = .idle
        snapshotSubject.send(snapshot)
        notifyDelegate(with: snapshot)
    }

    // MARK: - Private Helpers

    private func applyInitialProgressIfNeeded() {
        guard let savedProgress else { return }
        guard let presenter = subtitlePresenter else { return }

        let duration = snapshotSubject.value.totalDuration > 0 ? snapshotSubject.value.totalDuration : savedProgress.totalDurationSec ?? 0
        guard duration > 0 else {
            self.savedProgress = nil
            return
        }

        guard let clamped = presenter.initialResumePosition(progress: savedProgress, totalDuration: duration) else {
            self.savedProgress = nil
            return
        }

        playbackController.seek(to: clamped, autoResume: false)
        refreshCurrentTime(fallback: clamped)
        updateProgress()
        presenter.sync(to: snapshotSubject.value.currentTime)
        notifyDelegate(with: snapshotSubject.value)
        self.savedProgress = nil
    }

    private func refreshCurrentTime(fallback: TimeInterval? = nil, allowIncrement: Bool = false) {
        var snapshot = snapshotSubject.value
        if let engineTime = playbackController.currentTime() {
            snapshot.currentTime = min(max(engineTime, 0), snapshot.totalDuration)
        } else if let fallback {
            snapshot.currentTime = min(max(fallback, 0), snapshot.totalDuration)
        } else if allowIncrement && playbackController.isPlaying {
            snapshot.currentTime = min(snapshot.currentTime + timerInterval, snapshot.totalDuration)
        }
        snapshotSubject.send(snapshot)
    }

    private func updateProgress() {
        var snapshot = snapshotSubject.value
        if snapshot.totalDuration > 0 {
            snapshot.progress = snapshot.currentTime / snapshot.totalDuration
        } else {
            snapshot.progress = 0
        }
        snapshotSubject.send(snapshot)
    }

    private func startTimer() {
        stopTimer()
        let timer = Timer(timeInterval: timerInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleTimerTick()
            }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func handleTimerTick() {
        refreshCurrentTime(allowIncrement: true)
        updateProgress()
        subtitlePresenter?.sync(to: snapshotSubject.value.currentTime)
        notifyDelegate(with: snapshotSubject.value)
        persistProgress(force: false, completed: false)
    }

    private func handlePlaybackFinished() {
        stopTimer()
        refreshCurrentTime(fallback: snapshotSubject.value.totalDuration)
        var snapshot = snapshotSubject.value
        snapshot.state = .finished
        updateProgress()
        subtitlePresenter?.sync(to: snapshot.currentTime)
        snapshotSubject.send(snapshot)
        notifyDelegate(with: snapshot)
        persistProgress(force: true, completed: true)
        completionSubject.send(())
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.delegate?.playbackSessionDidFinish(self)
        }
    }

    private func notifyDelegate(with snapshot: PlaybackSnapshot) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.delegate?.playbackSession(self, didProduce: snapshot)
        }
    }
}
