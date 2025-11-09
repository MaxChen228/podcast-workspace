//
//  AudioEngineManager.swift
//  audio-earning
//
//  Created by Claude on 2025/10/27.
//

import Foundation
import AVFoundation

/// Audio engine manager built on AVAudioEngine.
class AudioEngineManager {

    // MARK: - Properties

    private var audioEngine: AVAudioEngine!
    private var audioPlayerNode: AVAudioPlayerNode!
    private var timePitchNode: AVAudioUnitTimePitch!
    private var audioFile: AVAudioFile?

    private var currentSegmentStartTime: TimeInterval = 0
    private var playbackCompletionHandler: (() -> Void)?
    private var ignoreNextCompletion = false
    private var currentPlaybackRate: Float = 1.0

    // Optional frequency analysis callback
    var onFrequencyUpdate: (([Float]) -> Void)?

    // MARK: - Initialization

    init() {
        setupAudioEngine()
    }

    deinit {
        audioEngine?.stop()
    }

    // MARK: - Setup

    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        audioPlayerNode = AVAudioPlayerNode()
        timePitchNode = AVAudioUnitTimePitch()
        audioEngine.attach(audioPlayerNode)
        audioEngine.attach(timePitchNode)
    }

    // MARK: - Load Audio

    func loadAudio(url: URL, onComplete: (() -> Void)? = nil) throws {
        #if DEBUG
        print("🎵 Loading audio: \(url.lastPathComponent)")
        #endif

        // 0. Stop any existing playback
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        ignoreNextCompletion = true
        audioPlayerNode.stop()

        // 1. Read audio file
        audioFile = try AVAudioFile(forReading: url)

        guard let audioFile = audioFile else {
            throw AudioEngineError.invalidFile
        }

        let format = audioFile.processingFormat
        #if DEBUG
        print("✅ Audio format: \(format.sampleRate) Hz, \(format.channelCount) channels")
        #endif

        // 2. Reconnect nodes (disconnect before reconnecting)
        audioEngine.disconnectNodeOutput(audioPlayerNode)
        audioEngine.disconnectNodeOutput(timePitchNode)
        audioEngine.connect(
            audioPlayerNode,
            to: timePitchNode,
            format: format
        )
        audioEngine.connect(
            timePitchNode,
            to: audioEngine.mainMixerNode,
            format: format
        )
        applyPlaybackRate(currentPlaybackRate)

        // 3. Start the engine
        try audioEngine.start()

        // 4. Schedule entire file for playback
        playbackCompletionHandler = onComplete
        currentSegmentStartTime = 0
        scheduleFile()
        ignoreNextCompletion = false

        #if DEBUG
        print("✅ Audio engine started, duration: \(duration)s")
        #endif
    }

    private func scheduleFile() {
        guard let audioFile = audioFile else { return }

        audioPlayerNode.scheduleFile(
            audioFile,
            at: nil,
            completionHandler: { [weak self] in
                self?.handleNodeCompletion()
            }
        )
    }

    // MARK: - Playback Control

    func play() {
        if !audioEngine.isRunning {
            try? audioEngine.start()
        }
        audioPlayerNode.play()
    }

    func setPlaybackRate(_ rate: Float) {
        let clamped = max(0.5, min(rate, 2.0))
        currentPlaybackRate = clamped
        applyPlaybackRate(clamped)
    }

    func pause() {
        audioPlayerNode.pause()
    }

    func stop() {
        audioPlayerNode.stop()
        audioEngine.stop()
    }

    var isPlaying: Bool {
        return audioPlayerNode.isPlaying
    }

    // MARK: - Seek

    func seek(to time: TimeInterval, shouldResume: Bool) {
        guard let audioFile = audioFile else { return }

        let sampleRate = audioFile.processingFormat.sampleRate
        let startFrame = AVAudioFramePosition(time * sampleRate)
        let frameCount = audioFile.length - startFrame

        guard startFrame >= 0, frameCount > 0 else { return }

        // Stop current playback
        ignoreNextCompletion = true
        audioPlayerNode.stop()

        // Reschedule from specific position
        audioPlayerNode.scheduleSegment(
            audioFile,
            startingFrame: startFrame,
            frameCount: AVAudioFrameCount(frameCount),
            at: nil,
            completionHandler: { [weak self] in
                self?.handleNodeCompletion()
            }
        )

        currentSegmentStartTime = time

        if shouldResume {
            play()
        }

        ignoreNextCompletion = false
    }

    // MARK: - Properties

    var duration: TimeInterval {
        guard let audioFile = audioFile else { return 0 }
        let sampleRate = audioFile.processingFormat.sampleRate
        return Double(audioFile.length) / sampleRate
    }

    /// Retrieve the current playback time.
    /// AVAudioPlayerNode lacks a direct time property, so we compute it manually.
    func getCurrentTime() -> TimeInterval? {
        guard let nodeTime = audioPlayerNode.lastRenderTime,
              let playerTime = audioPlayerNode.playerTime(forNodeTime: nodeTime) else {
            return nil
        }

        let sampleRate = audioFile?.processingFormat.sampleRate ?? 44100
        let elapsed = Double(playerTime.sampleTime) / sampleRate
        return currentSegmentStartTime + elapsed
    }

    // MARK: - Completion Handling

    private func handleNodeCompletion() {
        if ignoreNextCompletion {
            ignoreNextCompletion = false
            return
        }

        playbackCompletionHandler?()
    }

    private func applyPlaybackRate(_ rate: Float) {
        timePitchNode?.rate = rate
    }

}

/// Audio engine errors.
enum AudioEngineError: LocalizedError {
    case invalidFile
    case engineNotStarted

    var errorDescription: String? {
        switch self {
        case .invalidFile:
            return "Invalid audio file"
        case .engineNotStarted:
            return "Audio engine not started"
        }
    }
}
