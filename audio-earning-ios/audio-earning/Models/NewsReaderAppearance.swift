//
//  NewsReaderAppearance.swift
//  audio-earning
//
//  News article reader typography and appearance configuration
//

import Foundation
import SwiftUI
import UIKit

/// News reader typography configuration with separate title and body fonts
struct NewsReaderAppearance: Codable, Equatable {
    var titleFont: NewsReaderFontOption
    var bodyFont: NewsReaderFontOption
    var textSize: NewsReaderTextSize

    static let `default` = NewsReaderAppearance(
        titleFont: .serif,
        bodyFont: .serif,
        textSize: .medium
    )
}

enum NewsReaderFontOption: String, CaseIterable, Identifiable, Codable {
    case rounded
    case serif
    case sans
    case spaceMono
    case cormorantGaramond
    case tangerine

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rounded: return "SF Rounded"
        case .serif: return "New York"
        case .sans: return "SF Pro"
        case .spaceMono: return "Space Mono"
        case .cormorantGaramond: return "Cormorant Garamond"
        case .tangerine: return "Tangerine"
        }
    }

    func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch self {
        case .rounded:
            return .system(size: size, weight: weight, design: .rounded)
        case .serif:
            return .system(size: size, weight: weight, design: .serif)
        case .sans:
            return .system(size: size, weight: weight, design: .default)
        case .spaceMono:
            let fontName = weight == .bold ? "SpaceMono-Bold" : "SpaceMono-Regular"
            return .custom(fontName, size: size)
        case .cormorantGaramond:
            let fontName: String
            switch weight {
            case .bold, .heavy, .black:
                fontName = "CormorantGaramond-Bold"
            case .medium, .semibold:
                fontName = "CormorantGaramond-Medium"
            default:
                fontName = "CormorantGaramond-Regular"
            }
            return .custom(fontName, size: size)
        case .tangerine:
            let fontName = weight == .bold ? "Tangerine-Bold" : "Tangerine-Regular"
            return .custom(fontName, size: size)
        }
    }

    func uiFont(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        switch self {
        case .rounded:
            let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
                .withDesign(.rounded) ?? UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
            return UIFont(descriptor: descriptor, size: size).withWeight(weight)
        case .serif:
            let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
                .withDesign(.serif) ?? UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
            return UIFont(descriptor: descriptor, size: size).withWeight(weight)
        case .sans:
            return UIFont.systemFont(ofSize: size, weight: weight)
        case .spaceMono:
            let fontName = weight == .bold ? "SpaceMono-Bold" : "SpaceMono-Regular"
            return UIFont(name: fontName, size: size) ?? UIFont.monospacedSystemFont(ofSize: size, weight: weight)
        case .cormorantGaramond:
            let fontName: String
            if weight == .bold || weight == .heavy || weight == .black {
                fontName = "CormorantGaramond-Bold"
            } else if weight == .medium || weight == .semibold {
                fontName = "CormorantGaramond-Medium"
            } else {
                fontName = "CormorantGaramond-Regular"
            }
            return UIFont(name: fontName, size: size) ?? UIFont.systemFont(ofSize: size, weight: weight)
        case .tangerine:
            let fontName = weight == .bold ? "Tangerine-Bold" : "Tangerine-Regular"
            return UIFont(name: fontName, size: size) ?? UIFont.systemFont(ofSize: size, weight: weight)
        }
    }
}

enum NewsReaderTextSize: String, CaseIterable, Identifiable, Codable {
    case small
    case medium
    case large

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .small: return "小"
        case .medium: return "中"
        case .large: return "大"
        }
    }

    /// Title base size (will be scaled with @ScaledMetric)
    var titleSize: CGFloat {
        switch self {
        case .small: return 28
        case .medium: return 32
        case .large: return 36
        }
    }

    /// Body base size (will be scaled with @ScaledMetric)
    var bodySize: CGFloat {
        switch self {
        case .small: return 16
        case .medium: return 18
        case .large: return 20
        }
    }

    /// Caption/metadata size
    var captionSize: CGFloat {
        switch self {
        case .small: return 12
        case .medium: return 14
        case .large: return 16
        }
    }
}

// MARK: - UserDefaults Persistence

extension NewsReaderAppearance {
    private static let userDefaultsKey = "newsReaderAppearance"

    /// Load appearance from UserDefaults, fallback to default
    static func loadFromUserDefaults() -> NewsReaderAppearance {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let appearance = try? JSONDecoder().decode(NewsReaderAppearance.self, from: data) else {
            return .default
        }
        return appearance
    }

    /// Save appearance to UserDefaults
    func saveToUserDefaults() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
    }
}

private extension UIFont {
    func withWeight(_ weight: UIFont.Weight) -> UIFont {
        guard weight != .regular else { return self }
        let descriptor = fontDescriptor.addingAttributes([
            UIFontDescriptor.AttributeName.traits: [UIFontDescriptor.TraitKey.weight: weight]
        ])
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
