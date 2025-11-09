//
//  SubtitleAppearance.swift
//  audio-earning
//
//  Created by ChatGPT on 2025/11/05.
//

import Foundation
import SwiftUI
import UIKit

/// Subtitle typography and palette configuration.
struct SubtitleAppearance: Codable, Equatable {
    var font: SubtitleFontOption
    var textSize: SubtitleTextSize
    var theme: SubtitleTheme

    static let `default` = SubtitleAppearance(font: .rounded, textSize: .medium, theme: .midnight)
}

enum SubtitleFontOption: String, CaseIterable, Identifiable, Codable {
    case rounded
    case serif
    case sans

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rounded: return "SF Rounded"
        case .serif: return "New York"
        case .sans: return "SF Pro"
        }
    }

    func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch self {
        case .rounded: return .system(size: size, weight: weight, design: .rounded)
        case .serif: return .system(size: size, weight: weight, design: .serif)
        case .sans: return .system(size: size, weight: weight, design: .default)
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
        }
    }
}

enum SubtitleTextSize: String, CaseIterable, Identifiable, Codable {
    case small
    case medium
    case large

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .small: return "S"
        case .medium: return "M"
        case .large: return "L"
        }
    }

    var pointSize: CGFloat {
        switch self {
        case .small: return 18
        case .medium: return 22
        case .large: return 26
        }
    }
}

enum SubtitleTheme: String, CaseIterable, Identifiable, Codable {
    case midnight
    case dusk
    case ivory
    case clear

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .midnight: return "Midnight"
        case .dusk: return "Dusk"
        case .ivory: return "Ivory"
        case .clear: return "Clear"
        }
    }

    var activeBackground: LinearGradient {
        switch self {
        case .midnight:
            return LinearGradient(colors: [Color(red: 0.09, green: 0.14, blue: 0.28), Color(red: 0.02, green: 0.05, blue: 0.16)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .dusk:
            return LinearGradient(colors: [Color(red: 0.17, green: 0.11, blue: 0.21), Color(red: 0.11, green: 0.07, blue: 0.18)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .ivory:
            return LinearGradient(colors: [Self.brandPrimaryLight, Self.brandPrimaryBase], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .clear:
            return LinearGradient(colors: [Color.clear, Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    var inactiveBackground: LinearGradient {
        switch self {
        case .midnight:
            return LinearGradient(colors: [Color(red: 0.08, green: 0.1, blue: 0.18), Color(red: 0.05, green: 0.07, blue: 0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .dusk:
            return LinearGradient(colors: [Color(red: 0.12, green: 0.08, blue: 0.15), Color(red: 0.08, green: 0.06, blue: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .ivory:
            return LinearGradient(colors: [Self.brandPrimarySoft, Self.brandPrimaryLight], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .clear:
            return LinearGradient(colors: [Color.clear, Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    var activeTextColor: Color {
        switch self {
        case .midnight, .dusk: return .white
        case .ivory: return .white
        case .clear: return Color.primary
        }
    }

    var inactiveTextColor: Color {
        switch self {
        case .midnight, .dusk: return Color.white.opacity(0.7)
        case .ivory: return Color.white.opacity(0.78)
        case .clear: return Color.primary.opacity(0.65)
        }
    }

    var subtitleShadow: Color {
        switch self {
        case .midnight: return Color.black.opacity(0.35)
        case .dusk: return Color(red: 0.08, green: 0.02, blue: 0.14)
        case .ivory: return Self.brandPrimaryDark.opacity(0.35)
        case .clear: return Color.black.opacity(0.05)
        }
    }

    private static var brandPrimaryBase: Color {
        Color(red: 217.0 / 255.0, green: 120.0 / 255.0, blue: 87.0 / 255.0)
    }

    private static var brandPrimaryLight: Color {
        Color(red: 0.911, green: 0.683, blue: 0.605)
    }

    private static var brandPrimarySoft: Color {
        Color(red: 0.940, green: 0.788, blue: 0.736)
    }

    private static var brandPrimaryDark: Color {
        Color(red: 0.723, green: 0.400, blue: 0.290)
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
