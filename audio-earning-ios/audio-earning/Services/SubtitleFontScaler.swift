//
//  SubtitleFontScaler.swift
//  audio-earning
//
//  Created by ChatGPT on 2025/11/04.
//

import UIKit
import SwiftUI

enum SubtitleFontScaler {
    private static let compactMapping: [SubtitleTextSize: CGFloat] = [
        .small: 18,
        .medium: 22,
        .large: 26
    ]

    private static let regularMapping: [SubtitleTextSize: CGFloat] = [
        .small: 24,
        .medium: 30,
        .large: 36
    ]

    static func basePointSize(
        for textSize: SubtitleTextSize,
        horizontalClass swiftSizeClass: UserInterfaceSizeClass?,
        dynamicType: DynamicTypeSize
    ) -> CGFloat {
        let category = UIContentSizeCategory(dynamicTypeSize: dynamicType)
        let uiSizeClass: UIUserInterfaceSizeClass?

        switch swiftSizeClass {
        case .compact?: uiSizeClass = .compact
        case .regular?: uiSizeClass = .regular
        case nil: uiSizeClass = nil
        @unknown default:
            uiSizeClass = nil
        }

        return basePointSize(for: textSize, horizontalClass: uiSizeClass, contentSizeCategory: category)
    }

    static func basePointSize(
        for textSize: SubtitleTextSize,
        horizontalClass: UIUserInterfaceSizeClass?,
        contentSizeCategory: UIContentSizeCategory?
    ) -> CGFloat {
        let mapping = (horizontalClass == .regular ? regularMapping : compactMapping)
        let baseSize = mapping[textSize] ?? 22

        guard let category = contentSizeCategory else {
            return baseSize
        }

        let trait = UITraitCollection(preferredContentSizeCategory: category)
        return UIFontMetrics(forTextStyle: .title2).scaledValue(for: baseSize, compatibleWith: trait)
    }
}

private extension UIContentSizeCategory {
    init(dynamicTypeSize: DynamicTypeSize) {
        switch dynamicTypeSize {
        case .xSmall: self = .extraSmall
        case .small: self = .small
        case .medium: self = .medium
        case .large: self = .large
        case .xLarge: self = .extraLarge
        case .xxLarge: self = .extraExtraLarge
        case .xxxLarge: self = .extraExtraExtraLarge
        case .accessibility1: self = .accessibilityMedium
        case .accessibility2: self = .accessibilityLarge
        case .accessibility3: self = .accessibilityExtraLarge
        case .accessibility4: self = .accessibilityExtraExtraLarge
        case .accessibility5: self = .accessibilityExtraExtraExtraLarge
        @unknown default: self = .large
        }
    }
}
