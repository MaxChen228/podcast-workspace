//
//  CacheManager.swift
//  audio-earning
//
//  Created by Codex on 2025/10/31.
//

import Foundation

struct CacheClearSummary {
    let removedMediaFiles: Int
}

/// Coordinates clearing cached assets and persisted metadata.
actor CacheManager {
    static let shared = CacheManager()

    private init() {}

    @discardableResult
    func clearAllCaches() async throws -> CacheClearSummary {
        let mediaFilesRemoved = try APIService.shared.clearMediaCache()

        await ChapterCacheStore.shared.clearAll()
        await ChapterListCacheStore.shared.clearAll()

        return CacheClearSummary(removedMediaFiles: mediaFilesRemoved)
    }
}
