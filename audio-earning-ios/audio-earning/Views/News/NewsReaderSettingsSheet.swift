//
//  NewsReaderSettingsSheet.swift
//  audio-earning
//
//  Settings sheet for customizing news article reading experience
//

import SwiftUI

struct NewsReaderSettingsSheet: View {
    @Binding var appearance: NewsReaderAppearance
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    // Preview Section
                    NewsReaderPreview(appearance: appearance)

                    // Title Font Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("標題字體")
                            .font(.headline)
                        VStack(spacing: 8) {
                            ForEach(NewsReaderFontOption.allCases) { option in
                                NewsReaderFontOptionRow(
                                    option: option,
                                    isSelected: appearance.titleFont == option,
                                    previewSize: appearance.textSize.titleSize,
                                    isTitleFont: true
                                ) {
                                    appearance.titleFont = option
                                }
                            }
                        }
                    }

                    // Body Font Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("內文字體")
                            .font(.headline)
                        VStack(spacing: 8) {
                            ForEach(NewsReaderFontOption.allCases) { option in
                                NewsReaderFontOptionRow(
                                    option: option,
                                    isSelected: appearance.bodyFont == option,
                                    previewSize: appearance.textSize.bodySize,
                                    isTitleFont: false
                                ) {
                                    appearance.bodyFont = option
                                }
                            }
                        }
                    }

                    // Text Size Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("文字大小")
                            .font(.headline)
                        Picker("Text size", selection: $appearance.textSize) {
                            ForEach(NewsReaderTextSize.allCases) { size in
                                Text(size.displayName)
                                    .font(.caption.weight(.semibold))
                                    .tag(size)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text("調整標題和內文的基礎字體大小。")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("閱讀設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Preview Section

private struct NewsReaderPreview: View {
    let appearance: NewsReaderAppearance
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title Preview
            Text("Dallas Wings win 2026 WNBA draft lottery, to select No. 1")
                .font(appearance.titleFont.font(size: appearance.textSize.titleSize, weight: .bold))
                .lineSpacing(4)
                .tracking(-0.3)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            // Metadata Preview
            HStack(spacing: 12) {
                Label {
                    Text("ESPN")
                        .font(.system(size: appearance.textSize.captionSize, weight: .medium))
                } icon: {
                    Image(systemName: "newspaper")
                        .font(.system(size: appearance.textSize.captionSize))
                }
                .foregroundColor(.secondary)

                Spacer()

                Text("2 小時前")
                    .font(.system(size: appearance.textSize.captionSize))
                    .foregroundColor(.secondary)
            }

            Divider()
                .background(Color.primary.opacity(0.1))
                .padding(.vertical, 4)

            // Body Preview
            VStack(alignment: .leading, spacing: 12) {
                Text("The Dallas Wings won the 2026 WNBA draft lottery on Sunday, securing the No. 1 overall pick in next year's draft.")
                    .font(appearance.bodyFont.font(size: appearance.textSize.bodySize, weight: .regular))
                    .lineSpacing(8)
                    .tracking(0.2)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("The Wings had the best odds at 44.2% after finishing with the league's worst record at 9-31 in 2025.")
                    .font(appearance.bodyFont.font(size: appearance.textSize.bodySize, weight: .regular))
                    .lineSpacing(8)
                    .tracking(0.2)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Font Option Row

private struct NewsReaderFontOptionRow: View {
    let option: NewsReaderFontOption
    let isSelected: Bool
    let previewSize: CGFloat
    let isTitleFont: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.displayName)
                        .font(.callout.weight(.semibold))
                        .foregroundColor(.primary)

                    Text(isTitleFont ? "極簡優雅的設計" : "The quick brown fox jumps over the lazy dog.")
                        .font(option.font(size: previewSize * 0.7, weight: isTitleFont ? .bold : .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.title3)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.tertiarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview Provider

#Preview {
    NewsReaderSettingsSheet(appearance: .constant(.default))
}
