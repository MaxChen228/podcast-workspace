//
//  PlaybackProgressTracker.swift
//  audio-earning
//
//  Created by Codex on 2025/11/04.
//

import Foundation

struct PlaybackProgressSnapshot: Sendable {
    let position: Double
    let duration: Double?
    let force: Bool
    let completed: Bool
}

protocol PlaybackProgressTracking: AnyObject {
    func updateContext(bookID: String?, chapterID: String?, initialProgress: ChapterProgress?) async
    func record(_ snapshot: PlaybackProgressSnapshot) async
    func reset() async
}

actor PlaybackProgressTracker: PlaybackProgressTracking {
    private let store: ListeningProgressStore
    private let minDelta: TimeInterval
    private let minInterval: TimeInterval

    private var context: (bookID: String, chapterID: String)?
    private var lastPosition: Double = 0
    private var lastSavedAt: Date = .distantPast
    private var storedDuration: Double?

    init(
        store: ListeningProgressStore = .shared,
        minDelta: TimeInterval = 5,
        minInterval: TimeInterval = 10
    ) {
        self.store = store
        self.minDelta = minDelta
        self.minInterval = minInterval
    }

    func updateContext(bookID: String?, chapterID: String?, initialProgress: ChapterProgress?) async {
        guard let bookID, let chapterID else {
            context = nil
            lastPosition = 0
            lastSavedAt = .distantPast
            storedDuration = nil
            return
        }

        context = (bookID, chapterID)

        if let initialProgress {
            lastPosition = max(0, initialProgress.lastPositionSec)
            lastSavedAt = initialProgress.updatedAt
            storedDuration = initialProgress.totalDurationSec
        } else if let existing = await store.progress(bookID: bookID, chapterID: chapterID) {
            lastPosition = max(0, existing.lastPositionSec)
            lastSavedAt = existing.updatedAt
            storedDuration = existing.totalDurationSec
        } else {
            lastPosition = 0
            lastSavedAt = .distantPast
            storedDuration = nil
        }
    }

    func record(_ snapshot: PlaybackProgressSnapshot) async {
        guard let context else { return }

        var sanitizedPosition = max(0, snapshot.position)
        if let duration = snapshot.duration, duration > 0 {
            storedDuration = duration
        }

        let effectiveDuration = storedDuration ?? snapshot.duration

        if !snapshot.force && !snapshot.completed {
            let hasMovedEnough = abs(sanitizedPosition - lastPosition) >= minDelta
            let elapsed = Date().timeIntervalSince(lastSavedAt)
            let hasWaitedEnough = elapsed >= minInterval

            guard hasMovedEnough && hasWaitedEnough else {
                return
            }
        }

        if snapshot.completed, let effectiveDuration {
            sanitizedPosition = max(sanitizedPosition, effectiveDuration)
        }

        await store.saveProgress(
            bookID: context.bookID,
            chapterID: context.chapterID,
            position: sanitizedPosition,
            duration: effectiveDuration,
            completed: snapshot.completed
        )

        lastPosition = sanitizedPosition
        lastSavedAt = Date()

        if snapshot.completed {
            storedDuration = effectiveDuration
        }
    }

    func reset() async {
        context = nil
        lastPosition = 0
        lastSavedAt = .distantPast
        storedDuration = nil
    }
}
