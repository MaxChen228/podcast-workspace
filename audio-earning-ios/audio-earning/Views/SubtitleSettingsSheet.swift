//
//  SubtitleSettingsSheet.swift
//  audio-earning
//
//  Created by Codex on 2025/10/30.
//

import SwiftUI

struct SubtitleSettingsSheet: View {
    @ObservedObject var viewModel: AudioPlayerViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var appearance: SubtitleAppearance { viewModel.subtitleAppearance }

    private var basePointSize: CGFloat {
        SubtitleFontScaler.basePointSize(
            for: appearance.textSize,
            horizontalClass: horizontalSizeClass,
            dynamicType: dynamicTypeSize
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    SubtitleSettingsPreview(appearance: appearance, basePointSize: basePointSize)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Display Mode")
                            .font(.headline)
                        Picker(
                            "Subtitle mode",
                            selection: Binding(
                                get: { viewModel.displayMode },
                                set: { viewModel.setDisplayMode($0) }
                            )
                        ) {
                            ForEach(SubtitleDisplayMode.allCases, id: \.self) { mode in
                                Text(mode.description)
                                    .font(.caption.weight(.semibold))
                                    .tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        Text("選擇想要的字幕呈現方式，可在單字或句子模式間切換。")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Font")
                            .font(.headline)
                        VStack(spacing: 8) {
                            ForEach(SubtitleFontOption.allCases) { option in
                                SubtitleFontOptionRow(
                                    option: option,
                                    isSelected: appearance.font == option,
                                    basePointSize: basePointSize,
                                    action: { viewModel.setSubtitleFont(option) }
                                )
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Size")
                            .font(.headline)
                        Picker("Text size", selection: Binding(get: { appearance.textSize }, set: { viewModel.setSubtitleTextSize($0) })) {
                            ForEach(SubtitleTextSize.allCases) { size in
                                Text(size.displayName)
                                    .font(.caption.weight(.semibold))
                                    .tag(size)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Theme")
                            .font(.headline)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(SubtitleTheme.allCases) { theme in
                                SubtitleThemeOption(theme: theme, isSelected: appearance.theme == theme) {
                                    viewModel.setSubtitleTheme(theme)
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Subtitle Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct SubtitleSettingsPreview: View {
    let appearance: SubtitleAppearance
    let basePointSize: CGFloat

    var body: some View {
        VStack(spacing: 14) {
            SubtitlePreviewBubble(
                text: "Hardin sent this recording to be analyzed.",
                isActive: true,
                appearance: appearance,
                basePointSize: basePointSize
            )

            SubtitlePreviewBubble(
                text: "So the board was angry about Hardin's secret recording.",
                isActive: false,
                appearance: appearance,
                basePointSize: basePointSize
            )
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 12)
    }
}

private struct SubtitlePreviewBubble: View {
    let text: String
    let isActive: Bool
    let appearance: SubtitleAppearance
    let basePointSize: CGFloat

    var body: some View {
        Text(text)
            .font(appearance.font.font(size: basePointSize + (isActive ? 2 : -1), weight: isActive ? .semibold : .medium))
            .foregroundColor(isActive ? appearance.theme.activeTextColor : appearance.theme.inactiveTextColor)
            .multilineTextAlignment(.center)
            .padding(.vertical, isActive ? 18 : 14)
            .padding(.horizontal, isActive ? 24 : 20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(isActive ? appearance.theme.activeBackground : appearance.theme.inactiveBackground)
            )
            .shadow(color: appearance.theme.subtitleShadow.opacity(isActive ? 0.35 : 0.2), radius: isActive ? 22 : 12, x: 0, y: isActive ? 14 : 8)
    }
}

private struct SubtitleFontOptionRow: View {
    let option: SubtitleFontOption
    let isSelected: Bool
    let basePointSize: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.displayName)
                        .font(.callout.weight(.semibold))
                        .foregroundColor(.primary)
                    Text("The quick brown fox.")
                        .font(option.font(size: basePointSize, weight: .medium))
                        .foregroundColor(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.tertiarySystemBackground))
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SubtitleThemeOption: View {
    let theme: SubtitleTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(theme.activeBackground)
                    .frame(height: 64)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(isSelected ? Color.accentColor : Color.white.opacity(0.12), lineWidth: isSelected ? 2 : 1)
                    )
                    .shadow(color: theme.subtitleShadow.opacity(0.3), radius: 10, x: 0, y: 6)

                Text(theme.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.primary)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.08) : Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
    }
}
