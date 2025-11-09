//
//  WaveformGenerator.swift
//  audio-earning
//
//  Created by Claude on 2025/10/27.
//

import Foundation
import AVFoundation
import Accelerate

/// Waveform generator.
/// Extracts amplitude samples and produces data for visualization.
class WaveformGenerator {

    /// Waveform payload.
    struct WaveformData {
        let samples: [Float]  // Normalized amplitudes (0.0 ~ 1.0)
        let duration: TimeInterval
    }

    /// Generate waveform samples.
    /// - Parameters:
    ///   - audioURL: Audio file URL
    ///   - targetSampleCount: Desired sample count (typically view width in points)
    /// - Returns: Waveform data
    static func generateWaveform(from audioURL: URL, targetSampleCount: Int = 500) async throws -> WaveformData {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let waveformData = try processAudioFile(url: audioURL, targetSampleCount: targetSampleCount)
                    continuation.resume(returning: waveformData)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Process audio file (core algorithm).
    private static func processAudioFile(url: URL, targetSampleCount: Int) throws -> WaveformData {
        // 1. Open audio file
        let audioFile = try AVAudioFile(forReading: url)

        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: audioFile.processingFormat.sampleRate,
            channels: 1,  // Convert to mono
            interleaved: false
        ) else {
            throw WaveformError.invalidFormat
        }

        // 2. Gather audio metadata
        let totalFrames = Int(audioFile.length)
        let duration = Double(totalFrames) / audioFile.processingFormat.sampleRate

        guard totalFrames > 0 else {
            throw WaveformError.emptyFile
        }

        // 3. Create audio buffer
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(totalFrames)
        ) else {
            throw WaveformError.bufferCreationFailed
        }

        // 4. Read entire file into buffer
        try audioFile.read(into: buffer, frameCount: AVAudioFrameCount(totalFrames))

        // 5. Extract channel samples
        guard let channelData = buffer.floatChannelData?[0] else {
            throw WaveformError.noChannelData
        }

        let samples = Array(UnsafeBufferPointer(start: channelData, count: totalFrames))

        // 6. Downsample for rendering
        let downsampledSamples = downsample(samples: samples, targetCount: targetSampleCount)

        // 7. Normalize to 0.0 ~ 1.0
        let normalizedSamples = normalize(samples: downsampledSamples)

        return WaveformData(samples: normalizedSamples, duration: duration)
    }

    /// Downsample samples while preserving peak amplitude per bucket.
    private static func downsample(samples: [Float], targetCount: Int) -> [Float] {
        guard samples.count > targetCount else {
            return samples
        }

        var result: [Float] = []
        let bucketSize = samples.count / targetCount

        for i in 0..<targetCount {
            let startIndex = i * bucketSize
            let endIndex = min(startIndex + bucketSize, samples.count)

            // Find the maximum absolute amplitude within each bucket
            var maxAmplitude: Float = 0
            for j in startIndex..<endIndex {
                let absValue = abs(samples[j])
                if absValue > maxAmplitude {
                    maxAmplitude = absValue
                }
            }

            result.append(maxAmplitude)
        }

        return result
    }

    /// Normalize amplitudes to 0.0 ~ 1.0.
    private static func normalize(samples: [Float]) -> [Float] {
        guard !samples.isEmpty else { return [] }

        // Determine maximum amplitude
        var maxAmplitude: Float = 0
        for sample in samples {
            if sample > maxAmplitude {
                maxAmplitude = sample
            }
        }

        guard maxAmplitude > 0 else {
            return samples.map { _ in 0.0 }
        }

        // Normalize
        return samples.map { $0 / maxAmplitude }
    }

    /// Optional accelerated downsampling using vDSP.
    private static func downsampleAccelerated(samples: [Float], targetCount: Int) -> [Float] {
        guard samples.count > targetCount else {
            return samples
        }

        var result = [Float](repeating: 0, count: targetCount)
        let bucketSize = samples.count / targetCount

        for i in 0..<targetCount {
            let startIndex = i * bucketSize
            let endIndex = min(startIndex + bucketSize, samples.count)
            let bucketSamples = Array(samples[startIndex..<endIndex])

            // Compute RMS with vDSP
            var rms: Float = 0
            vDSP_rmsqv(bucketSamples, 1, &rms, vDSP_Length(bucketSamples.count))
            result[i] = rms
        }

        return result
    }
}

/// Waveform generation errors.
enum WaveformError: LocalizedError {
    case invalidFormat
    case emptyFile
    case bufferCreationFailed
    case noChannelData

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid audio format"
        case .emptyFile:
            return "Audio file is empty"
        case .bufferCreationFailed:
            return "Failed to create audio buffer"
        case .noChannelData:
            return "No audio channel data available"
        }
    }
}
