//
//  NewsParagraphView.swift
//  audio-earning
//
//  Interactive paragraph view with AI explanation, highlighting, and notes
//

import SwiftUI

struct NewsParagraphView: View {
    let paragraph: NewsArticleParagraph
    let appearance: NewsReaderAppearance
    let bodySize: CGFloat
    let onExplainRequest: () -> Void
    let onHighlightToggle: () -> Void
    let onNoteAdd: () -> Void

    @State private var showContextMenu = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Paragraph Text
            paragraphText
                .contextMenu {
                    contextMenuContent
                }

            // Expandable Explanation Card
            if paragraph.isExplanationExpanded {
                ParagraphExplanationCard(
                    state: paragraph.explanationState,
                    onRetry: onExplainRequest,
                    onSaveToLexicon: {
                        // TODO: Implement save to lexicon
                    }
                )
                .padding(.top, ArticleReaderStyle.paragraphSpacing)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Note Display (if exists)
            if paragraph.hasNote, let note = paragraph.note {
                noteDisplay(note)
                    .padding(.top, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: paragraph.isExplanationExpanded)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: paragraph.hasNote)
    }

    // MARK: - Paragraph Text

    private var paragraphText: some View {
        Text(paragraph.text)
            .font(appearance.bodyFont.font(size: bodySize, weight: .regular))
            .lineSpacing(ArticleReaderStyle.bodyLineSpacing)
            .tracking(ArticleReaderStyle.bodyTracking)
            .multilineTextAlignment(.leading)
            .textSelection(.enabled)
            .foregroundColor(.primary)
            .padding(paragraph.isHighlighted ? 12 : 0)
            .background(
                paragraph.isHighlighted ?
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                    : nil
            )
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuContent: some View {
        Button {
            onExplainRequest()
        } label: {
            Label("AI 解釋", systemImage: "sparkles")
        }

        Button {
            onHighlightToggle()
        } label: {
            Label(
                paragraph.isHighlighted ? "取消高亮" : "高亮段落",
                systemImage: paragraph.isHighlighted ? "highlighter" : "highlighter"
            )
        }

        Button {
            onNoteAdd()
        } label: {
            Label(
                paragraph.hasNote ? "編輯筆記" : "添加筆記",
                systemImage: paragraph.hasNote ? "note.text" : "note.text.badge.plus"
            )
        }

        Divider()

        Button(role: .destructive) {
            // Collapse explanation if expanded
            if paragraph.isExplanationExpanded {
                onExplainRequest() // Toggle to collapse
            }
        } label: {
            Label("收起", systemImage: "xmark")
        }
        .disabled(!paragraph.isExplanationExpanded)
    }

    // MARK: - Note Display

    private func noteDisplay(_ note: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "note.text")
                .font(.caption)
                .foregroundColor(.accentColor)
                .padding(.top, 2)

            Text(note)
                .font(.system(size: bodySize * 0.9))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            Button {
                onNoteAdd()
            } label: {
                Image(systemName: "pencil")
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Explanation Card

struct ParagraphExplanationCard: View {
    let state: ParagraphExplanationState
    let onRetry: () -> Void
    let onSaveToLexicon: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch state {
            case .collapsed:
                EmptyView()

            case .loading:
                loadingView

            case .error(let message):
                errorView(message: message)

            case .expanded(let data):
                explanationContent(data)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Loading State

    private var loadingView: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("正在向 AI 取得解釋...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 8)
    }

    // MARK: - Error State

    private func errorView(message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("無法取得解釋")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.orange)
            }

            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)

            Button {
                onRetry()
            } label: {
                Label("重試", systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.accentColor)
        }
    }

    // MARK: - Explanation Content

    private func explanationContent(_ data: ParagraphExplanationData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Label("AI 解釋", systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.accentColor)

                if data.cached {
                    Spacer()
                    Text("來自快取")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Chinese Summary (if available)
            if let summary = data.chineseSummary, !summary.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("中文摘要")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    Text(summary)
                        .font(.body)
                        .foregroundColor(.primary)
                }
            }

            // Overview
            Text(data.overview)
                .font(.body)
                .foregroundColor(.primary)

            // Key Points
            if !data.keyPoints.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(data.keyPoints.enumerated()), id: \.offset) { _, point in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundColor(.accentColor)
                            Text(point)
                                .font(.body)
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            // Vocabulary
            if !data.vocabulary.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("重點詞彙")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)

                    ForEach(data.vocabulary) { vocab in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(vocab.word)
                                .font(.body.weight(.semibold))
                                .foregroundColor(.primary)
                            Text(vocab.meaning)
                                .font(.callout)
                                .foregroundColor(.secondary)
                            if let note = vocab.note, !note.isEmpty {
                                Text(note)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color(.tertiarySystemBackground))
                        )
                    }
                }
            }

            Divider()

            // Actions
            HStack(spacing: 12) {
                Button {
                    onSaveToLexicon()
                } label: {
                    Label("存入字詞庫", systemImage: "bookmark")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)

                Button {
                    onRetry()
                } label: {
                    Label("重新產生", systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            // Normal paragraph
            NewsParagraphView(
                paragraph: NewsArticleParagraph(text: "The Dallas Wings won the 2026 WNBA draft lottery on Sunday, securing the No. 1 overall pick in next year's draft.", index: 0),
                appearance: .default,
                bodySize: 18,
                onExplainRequest: {},
                onHighlightToggle: {},
                onNoteAdd: {}
            )

            // Highlighted paragraph with note
            NewsParagraphView(
                paragraph: NewsArticleParagraph(
                    text: "The Wings had the best odds at 44.2% after finishing with the league's worst record at 9-31 in 2025.",
                    index: 1,
                    isHighlighted: true,
                    note: "這段很重要，記得複習"
                ),
                appearance: .default,
                bodySize: 18,
                onExplainRequest: {},
                onHighlightToggle: {},
                onNoteAdd: {}
            )
        }
        .padding()
    }
}
