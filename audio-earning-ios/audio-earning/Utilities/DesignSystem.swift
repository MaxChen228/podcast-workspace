//
//  DesignSystem.swift
//  audio-earning
//
//  Created by Codex on 2025/11/01.
//

import SwiftUI

enum PlayerPalette {
    static let accent = Color(red: 217.0 / 255.0, green: 120.0 / 255.0, blue: 87.0 / 255.0)
    static let accentSoft = Color(red: 0.957, green: 0.851, blue: 0.808)
    static let accentGlow = Color(red: 0.996, green: 0.913, blue: 0.886)
    static let neutralBackground = Color(.systemBackground)
    static let mutedText = Color.primary.opacity(0.45)
    static let capsuleFill = Color(.secondarySystemBackground).opacity(0.9)
    static let controlBarBackground = Color.white.opacity(0.92)
    static let shadow = Color.black.opacity(0.12)
}

struct GlassCard<Content: View>: View {
    let cornerRadius: CGFloat
    let padding: EdgeInsets
    @ViewBuilder var content: Content

    init(
        cornerRadius: CGFloat = 24,
        padding: EdgeInsets = EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20),
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                PlayerPalette.accentGlow.opacity(0.55),
                                PlayerPalette.accentSoft.opacity(0.35)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.55), lineWidth: 0.8)
            )
            .shadow(color: PlayerPalette.shadow, radius: 18, y: 10)
            .overlay(
                content
                    .padding(padding)
            )
    }
}

enum StatusBadgeStyle {
    case accent
    case caution
    case neutral

    var background: Color {
        switch self {
        case .accent:
            return PlayerPalette.accentSoft
        case .caution:
            return Color(red: 1.0, green: 0.894, blue: 0.784)
        case .neutral:
            return PlayerPalette.capsuleFill
        }
    }

    var foreground: Color {
        switch self {
        case .accent:
            return PlayerPalette.accent
        case .caution:
            return Color(red: 0.760, green: 0.427, blue: 0.196)
        case .neutral:
            return Color.primary.opacity(0.65)
        }
    }
}

struct StatusBadge: View {
    let systemImage: String
    let text: String
    let style: StatusBadgeStyle

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(text)
                .lineLimit(1)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(style.foreground)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(style.background)
        )
    }
}
