//
//  AudioPlaybackController.swift
//  audio-earning
//
//  Created by Codex on 2025/11/04.
//

import Foundation
import AVFoundation

/// Abstraction for controlling audio playback.
protocol AudioPlaybackControlling: AnyObject {
    var duration: TimeInterval { get }
    var isPlaying: Bool { get }
    var playbackRate: Double { get }

    /// Load a local audio resource and prepare for playback.
    func loadAudio(url: URL, completion: (() -> Void)?) throws

    func play()
    func pause()
    func stop()

    func seek(to time: TimeInterval, autoResume: Bool)
    func currentTime() -> TimeInterval?
    func setPlaybackRate(_ rate: Double)
}

/// Default implementation backed by `AudioEngineManager`.
final class AudioPlaybackController: AudioPlaybackControlling {
    private let engineManager: AudioEngineManager
    private(set) var playbackRate: Double = 1.0

    init(engineManager: AudioEngineManager = AudioEngineManager()) {
        self.engineManager = engineManager
    }

    func loadAudio(url: URL, completion: (() -> Void)?) throws {
        try engineManager.loadAudio(url: url, onComplete: completion)
        engineManager.setPlaybackRate(Float(playbackRate))
    }

    func play() {
        engineManager.play()
    }

    func pause() {
        engineManager.pause()
    }

    func stop() {
        engineManager.stop()
    }

    func seek(to time: TimeInterval, autoResume: Bool) {
        engineManager.seek(to: time, shouldResume: autoResume)
    }

    func currentTime() -> TimeInterval? {
        engineManager.getCurrentTime()
    }

    func setPlaybackRate(_ rate: Double) {
        playbackRate = rate
        engineManager.setPlaybackRate(Float(rate))
    }

    var duration: TimeInterval {
        engineManager.duration
    }

    var isPlaying: Bool {
        engineManager.isPlaying
    }
}
