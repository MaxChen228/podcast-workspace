//
//  LibraryModels.swift
//  audio-earning
//
//  Created by Codex on 2025/11/09.
//

import Foundation

struct LibraryChapterRecord: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    var audioAvailable: Bool
    var subtitlesAvailable: Bool
    var metrics: ChapterPlaybackMetrics?
}

struct LibraryBookRecord: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    var coverURLString: String?
    var addedAt: Date
    var lastSyncedAt: Date
    var chapters: [LibraryChapterRecord]

    var coverURL: URL? {
        guard let coverURLString, let url = URL(string: coverURLString) else {
            return nil
        }
        return url
    }
}

