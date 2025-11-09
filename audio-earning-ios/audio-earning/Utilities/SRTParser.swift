//
//  SRTParser.swift
//  audio-earning
//
//  Created by Claude on 2025/10/27.
//

import Foundation

/// SRT parser converting SRT text into subtitle items.
class SRTParser {

    /// Parse an SRT file from disk.
    /// - Parameter url: URL pointing to an SRT file
    /// - Returns: Parsed subtitle items
    static func parse(url: URL) throws -> [SubtitleItem] {
        let content = try String(contentsOf: url, encoding: .utf8)
        return try parse(content: content)
    }

    /// Parse SRT content provided as text.
    /// - Parameter content: Raw SRT text
    /// - Returns: Parsed subtitle items
    static func parse(content: String) throws -> [SubtitleItem] {
        var subtitles: [SubtitleItem] = []

        // Split blocks by double newlines
        let blocks = content.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for block in blocks {
            // Split into trimmed lines
            let lines = block.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            guard lines.count >= 3 else { continue }

            // First line: index
            guard let id = Int(lines[0]) else { continue }

            // Second line: timestamp (e.g. 00:00:00,000 --> 00:00:05,200)
            let timeRange = lines[1]
            guard let (startTime, endTime) = parseTimeRange(timeRange) else {
                continue
            }

            // Remaining lines: subtitle text (may span multiple lines)
            let text = lines[2...].joined(separator: "\n")

            let subtitle = SubtitleItem(
                id: id,
                startTime: startTime,
                endTime: endTime,
                text: text
            )

            subtitles.append(subtitle)
        }

        // Sort by start time
        return subtitles.sorted { $0.startTime < $1.startTime }
    }

    /// Parse a time range such as "00:00:00,000 --> 00:00:05,200".
    /// - Parameter timeRange: Raw time range text
    /// - Returns: Tuple containing start and end times in seconds
    private static func parseTimeRange(_ timeRange: String) -> (TimeInterval, TimeInterval)? {
        let components = timeRange.components(separatedBy: " --> ")
        guard components.count == 2 else { return nil }

        guard let startTime = parseTimestamp(components[0]),
              let endTime = parseTimestamp(components[1]) else {
            return nil
        }

        return (startTime, endTime)
    }

    /// Parse a timestamp string (e.g. "00:01:23,456").
    /// - Parameter timestamp: Timestamp text
    /// - Returns: Time interval in seconds
    private static func parseTimestamp(_ timestamp: String) -> TimeInterval? {
        // Format: HH:MM:SS,mmm
        let components = timestamp.components(separatedBy: CharacterSet(charactersIn: ":,"))
        guard components.count == 4 else { return nil }

        guard let hours = Double(components[0]),
              let minutes = Double(components[1]),
              let seconds = Double(components[2]),
              let milliseconds = Double(components[3]) else {
            return nil
        }

        // Convert to total seconds
        let totalSeconds = hours * 3600 + minutes * 60 + seconds + milliseconds / 1000.0
        return totalSeconds
    }
}

/// SRT parser errors.
enum SRTParserError: LocalizedError {
    case invalidFormat
    case fileNotFound
    case encodingError

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid SRT format"
        case .fileNotFound:
            return "SRT file not found"
        case .encodingError:
            return "Failed to decode SRT file"
        }
    }
}
