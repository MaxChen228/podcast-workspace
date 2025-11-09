//
//  SubtitleItem.swift
//  audio-earning
//
//  Created by Claude on 2025/10/27.
//

import Foundation

/// Subtitle data model.
struct SubtitleItem: Identifiable, Equatable {
    let id: Int
    let startTime: TimeInterval  // Start time in seconds
    let endTime: TimeInterval    // End time in seconds
    let text: String             // Subtitle text

    /// Returns true when the provided time falls within the subtitle range.
    func contains(time: TimeInterval) -> Bool {
        return time >= startTime && time <= endTime
    }

    /// Subtitle duration.
    var duration: TimeInterval {
        return endTime - startTime
    }
}

/// Audio player states.
enum AudioPlayerState: Equatable {
    case idle        // Idle
    case loading     // Loading
    case ready       // Ready
    case playing     // Playing
    case paused      // Paused
    case finished    // Finished
    case error(String) // Error

    // Equatable implementation
    static func == (lhs: AudioPlayerState, rhs: AudioPlayerState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.loading, .loading),
             (.ready, .ready),
             (.playing, .playing),
             (.paused, .paused),
             (.finished, .finished):
            return true
        case (.error(let lhsMessage), .error(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}

/// Subtitle display modes.
enum SubtitleDisplayMode: String, CaseIterable {
    case wordLevel = "Word"      // Word-level display
    case sentenceLevel = "Sentence"  // Sentence-level display

    var description: String {
        return self.rawValue
    }
}
