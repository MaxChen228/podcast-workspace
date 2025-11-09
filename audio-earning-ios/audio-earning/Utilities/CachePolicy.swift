//
//  CachePolicy.swift
//  audio-earning
//
//  Created by Codex on 2025/11/02.
//

import Foundation

enum CachePolicy {
    /// Default TTL for chapter list data (6 hours).
    static var chapterListTTL: TimeInterval = 6 * 60 * 60

    /// Default TTL for chapter playback assets (12 hours).
    static var chapterPayloadTTL: TimeInterval = 12 * 60 * 60

    /// Default TTL for downloaded media when skipping remote validation (24 hours).
    static var mediaTTL: TimeInterval = 24 * 60 * 60
}
