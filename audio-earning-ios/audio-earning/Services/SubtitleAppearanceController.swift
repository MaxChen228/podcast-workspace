//
//  SubtitleAppearanceController.swift
//  audio-earning
//
//  Created by ChatGPT on 2025/11/04.
//

import Foundation
import Combine

protocol SubtitleAppearanceManaging: AnyObject {
    var appearancePublisher: AnyPublisher<SubtitleAppearance, Never> { get }
    var currentAppearance: SubtitleAppearance { get }

    func updateAppearance(_ appearance: SubtitleAppearance)
    func setFont(_ option: SubtitleFontOption)
    func setTextSize(_ size: SubtitleTextSize)
    func setTheme(_ theme: SubtitleTheme)
    func resetToDefault()
}

final class SubtitleAppearanceController: SubtitleAppearanceManaging {
    private let store: SubtitleAppearancePersisting
    private let subject: CurrentValueSubject<SubtitleAppearance, Never>

    init(store: SubtitleAppearancePersisting = SubtitleAppearanceStore.shared) {
        self.store = store
        let initial = store.load()
        self.subject = CurrentValueSubject(initial)
    }

    var appearancePublisher: AnyPublisher<SubtitleAppearance, Never> {
        subject.eraseToAnyPublisher()
    }

    var currentAppearance: SubtitleAppearance {
        subject.value
    }

    func updateAppearance(_ appearance: SubtitleAppearance) {
        guard subject.value != appearance else { return }
        subject.send(appearance)
        store.save(appearance)
    }

    func setFont(_ option: SubtitleFontOption) {
        var appearance = subject.value
        guard appearance.font != option else { return }
        appearance.font = option
        updateAppearance(appearance)
    }

    func setTextSize(_ size: SubtitleTextSize) {
        var appearance = subject.value
        guard appearance.textSize != size else { return }
        appearance.textSize = size
        updateAppearance(appearance)
    }

    func setTheme(_ theme: SubtitleTheme) {
        var appearance = subject.value
        guard appearance.theme != theme else { return }
        appearance.theme = theme
        updateAppearance(appearance)
    }

    func resetToDefault() {
        updateAppearance(.default)
    }

    // TODO: add unit tests covering publisher updates and persistence writes.
}
