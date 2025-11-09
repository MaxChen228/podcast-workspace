import SwiftUI

struct SentenceDetailView: View {
    @ObservedObject var viewModel: AudioPlayerViewModel

    var body: some View {
        Group {
            if let detail = viewModel.sentenceDetail {
                WorkspaceScrollContainer {
                    VStack(alignment: .leading, spacing: WorkspaceStyle.spacingLg) {
                        WorkspaceSectionHeader(title: Text("重點句子"))

                        sentenceTokensSection(detail)

                        WorkspaceSeparator()

                        WorkspaceSectionHeader(title: Text("上下文線索"))

                        contextSection(detail)

                        WorkspaceSeparator()

                        WorkspaceSectionHeader(title: Text("AI 解釋"))

                        aiExplanationSection(detail)
                    }
                }
                .presentationDragIndicator(.visible)
            } else {
                ProgressView("載入中…")
                    .padding()
            }
        }
        .alert(item: $viewModel.lexiconSaveFeedback) { feedback in
            switch feedback.kind {
            case .success:
                return Alert(title: Text("已儲存"), message: Text(feedback.message), dismissButton: .default(Text("好")))
            case .failure:
                return Alert(title: Text("無法儲存"), message: Text(feedback.message), dismissButton: .default(Text("好")))
            }
        }
    }

    // MARK: - Sections

    private func sentenceTokensSection(_ detail: SentenceDetailState) -> some View {
        let tokens = sentenceTokens(from: detail.subtitle.text)

        return WorkspaceCard {
            VStack(alignment: .leading, spacing: WorkspaceStyle.spacingMd) {
                if tokens.isEmpty {
                    Text(detail.subtitle.text)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    if !detail.selectedWords.isEmpty {
                        HStack(alignment: .center, spacing: WorkspaceStyle.spacingXs) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(WorkspaceStyle.accent)
                            Text("已選 \(detail.selectedWords.count) 個詞")
                                .font(.caption)
                                .foregroundStyle(WorkspaceStyle.textMuted)
                            Spacer()
                            Button("清除") {
                                viewModel.clearSelectedWords()
                            }
                            .font(.caption.weight(.semibold))
                            .buttonStyle(WorkspaceSecondaryButtonStyle(compact: true))
                        }
                    }

                    FlowLayout(spacing: WorkspaceStyle.spacingSm) {
                        ForEach(tokens) { token in
                            WordChip(
                                text: token.display,
                                isSelected: viewModel.isWordSelected(token.lookup, in: detail)
                            ) {
                                viewModel.toggleWordSelection(token.lookup)
                            }
                        }
                    }
                }
            }
        }
    }

    private func contextSection(_ detail: SentenceDetailState) -> some View {
        WorkspaceCard {
            VStack(alignment: .leading, spacing: WorkspaceStyle.spacingSm) {
                contextRow(
                    sentence: detail.context.previous?.text,
                    buttonTitle: "上一句",
                    systemImage: "chevron.up",
                    action: { viewModel.jumpToSentence(offset: -1) }
                )

                contextRow(
                    sentence: detail.context.next?.text,
                    buttonTitle: "下一句",
                    systemImage: "chevron.down",
                    action: { viewModel.jumpToSentence(offset: 1) }
                )
            }
        }
    }

    private func contextRow(
        sentence: String?,
        buttonTitle: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        let text = sentence?.trimmingCharacters(in: .whitespacesAndNewlines)
        let isAvailable = !(text?.isEmpty ?? true)

        return VStack(alignment: .leading, spacing: WorkspaceStyle.spacingXs) {
            Button(action: action) {
                Label(buttonTitle, systemImage: systemImage)
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(WorkspaceSecondaryButtonStyle(compact: true))
            .disabled(!isAvailable)

            Text(text ?? "沒有更多內容")
                .font(.body)
                .foregroundStyle(isAvailable ? Color.primary : WorkspaceStyle.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func aiExplanationSection(_ detail: SentenceDetailState) -> some View {
        switch detail.explanationState {
        case .idle:
            WorkspaceCard {
                VStack(alignment: .leading, spacing: WorkspaceStyle.spacingMd) {
                    Text("需要 AI 解釋這句話嗎？")
                        .font(.subheadline)
                        .foregroundStyle(WorkspaceStyle.textMuted)

                    Button {
                        viewModel.requestSentenceExplanation()
                    } label: {
                        Group {
                            if detail.selectedWords.isEmpty {
                                Label("產生 AI 解釋", systemImage: "sparkles")
                            } else {
                                Label("解釋所選用法", systemImage: "sparkles")
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(WorkspacePrimaryButtonStyle())
                }
            }

        case .loading:
            WorkspaceCard {
                VStack(spacing: WorkspaceStyle.spacingSm) {
                    ProgressView()
                    Text(detail.selectedWords.isEmpty ? "正在向 AI 取得說明…" : "正在解釋所選用法…")
                        .font(.subheadline)
                        .foregroundStyle(WorkspaceStyle.textMuted)
                }
                .frame(maxWidth: .infinity)
            }

        case .failure(let message):
            WorkspaceCard {
                VStack(alignment: .leading, spacing: WorkspaceStyle.spacingSm) {
                    Text("取得解釋時發生問題。")
                        .font(.subheadline)
                        .foregroundStyle(Color.red)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(WorkspaceStyle.textMuted)
                    Button("重試") {
                        viewModel.requestSentenceExplanation()
                    }
                    .buttonStyle(WorkspaceSecondaryButtonStyle())
                }
            }

        case .loaded(let data, let cached):
            WorkspaceCard {
                VStack(alignment: .leading, spacing: WorkspaceStyle.spacingMd) {
                    if cached {
                        Text("來自快取")
                            .font(.caption)
                            .foregroundStyle(WorkspaceStyle.textMuted)
                    }

                    if let meaning = data.chineseMeaning, !meaning.isEmpty {
                        VStack(alignment: .leading, spacing: WorkspaceStyle.spacingXs) {
                            Text("中文意思")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(WorkspaceStyle.textMuted)
                            Text(meaning)
                                .font(.body)
                        }
                    }

                    Text(data.overview)
                        .font(.body)

                    if !data.keyPoints.isEmpty {
                        VStack(alignment: .leading, spacing: WorkspaceStyle.spacingXs) {
                            ForEach(Array(data.keyPoints.enumerated()), id: \.offset) { point in
                                HStack(alignment: .top, spacing: WorkspaceStyle.spacingXs) {
                                    Text("•")
                                    Text(point.element)
                                }
                                .font(.body)
                            }
                        }
                    }

                    if !data.vocabulary.isEmpty {
                        VStack(alignment: .leading, spacing: WorkspaceStyle.spacingSm) {
                            ForEach(data.vocabulary) { vocab in
                                VStack(alignment: .leading, spacing: WorkspaceStyle.spacingXs) {
                                    Text(vocab.word)
                                        .font(.body.weight(.semibold))
                                    Text(vocab.meaning)
                                        .font(.body)
                                    if let note = vocab.note, !note.isEmpty {
                                        Text(note)
                                            .font(.caption)
                                            .foregroundStyle(WorkspaceStyle.textMuted)
                                    }
                                }
                                .padding(.vertical, WorkspaceStyle.spacingSm)
                                .padding(.horizontal, WorkspaceStyle.spacingMd)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: WorkspaceStyle.radiusMd, style: .continuous)
                                        .fill(WorkspaceStyle.cardTint)
                                )
                            }
                        }
                    }

                    Button {
                        viewModel.saveCurrentExplanation()
                    } label: {
                        Label("存入字詞庫", systemImage: "bookmark")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(WorkspacePrimaryButtonStyle())

                    Button {
                        viewModel.requestSentenceExplanation()
                    } label: {
                        Label("重新產生解釋", systemImage: "arrow.clockwise")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(WorkspaceSecondaryButtonStyle())
                }
            }
        }
    }

    // MARK: - Helpers

    private func sentenceTokens(from text: String) -> [SentenceToken] {
        text.split(whereSeparator: { $0.isWhitespace }).compactMap { raw -> SentenceToken? in
            let display = String(raw)
            let lookup = display.trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.symbols))
            guard !lookup.isEmpty else { return nil }
            return SentenceToken(display: display, lookup: lookup)
        }
    }
}

// MARK: - Subviews & Models

private struct WordChip: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.callout.weight(.semibold))
                .padding(.vertical, WorkspaceStyle.spacingXs)
                .padding(.horizontal, WorkspaceStyle.spacingMd)
                .frame(minHeight: 40)
        }
        .buttonStyle(WordChipStyle(isSelected: isSelected))
    }
}

private struct WordChipStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: WorkspaceStyle.radiusSm, style: .continuous)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .foregroundStyle(isSelected ? WorkspaceStyle.accent : Color.primary)
            .overlay(
                RoundedRectangle(cornerRadius: WorkspaceStyle.radiusSm, style: .continuous)
                    .stroke(isSelected ? WorkspaceStyle.accent : Color.clear, lineWidth: WorkspaceStyle.hairline)
            )
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isSelected {
            return WorkspaceStyle.accentSoft.opacity(isPressed ? 0.8 : 1)
        }
        return WorkspaceStyle.cardTint.opacity(isPressed ? 0.9 : 1)
    }
}

private struct SentenceToken: Identifiable {
    let id = UUID()
    let display: String
    let lookup: String
}

// MARK: - Flow Layout

/// 流式布局，让单词像正常文字一样排列
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGSize {
        guard !subviews.isEmpty else { return .zero }

        let proposedWidth = proposal.width ?? .infinity
        var currentLineWidth: CGFloat = 0
        var currentLineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0

        for subview in subviews {
            let subviewSize = subview.sizeThatFits(.unspecified)
            if currentLineWidth + subviewSize.width > proposedWidth, currentLineWidth > 0 {
                totalHeight += currentLineHeight + spacing
                let effectiveWidth = max(0, currentLineWidth - spacing)
                maxRowWidth = max(maxRowWidth, effectiveWidth)
                currentLineWidth = 0
                currentLineHeight = 0
            }

            currentLineWidth += subviewSize.width + spacing
            currentLineHeight = max(currentLineHeight, subviewSize.height)
        }

        totalHeight += currentLineHeight
        let effectiveWidth = max(0, currentLineWidth - spacing)
        maxRowWidth = max(maxRowWidth, effectiveWidth)

        let widthLimit = proposedWidth.isFinite ? min(maxRowWidth, proposedWidth) : maxRowWidth
        return CGSize(width: widthLimit, height: totalHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        guard !subviews.isEmpty else { return }

        let availableWidth = bounds.width
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x + size.width - bounds.minX > availableWidth, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(size)
            )

            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Workspace Styling Helpers

private enum WorkspaceStyle {
    static let spacingLg: CGFloat = 24
    static let spacingMd: CGFloat = 16
    static let spacingSm: CGFloat = 12
    static let spacingXs: CGFloat = 8
    static let hairline: CGFloat = 0.75
    static let radiusLg: CGFloat = 20
    static let radiusMd: CGFloat = 16
    static let radiusSm: CGFloat = 14

    static let background = Color(.systemGroupedBackground)
    static let cardBackground = Color(.systemBackground)
    static let cardBorder = Color.accentColor.opacity(0.18)
    static let cardTint = Color(.secondarySystemBackground)
    static let accent = Color.accentColor
    static let accentSoft = Color.accentColor.opacity(0.18)
    static let textMuted = Color.primary.opacity(0.55)
}

private struct WorkspaceScrollContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            content
                .padding(.horizontal, WorkspaceStyle.spacingLg)
                .padding(.vertical, WorkspaceStyle.spacingLg)
        }
        .background(WorkspaceStyle.background.ignoresSafeArea())
    }
}

private struct WorkspaceSectionHeader: View {
    var title: Text
    var subtitle: Text? = nil

    init(title: Text, subtitle: Text? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            title
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.primary)
            if let subtitle {
                subtitle
                    .font(.body)
                    .foregroundStyle(WorkspaceStyle.textMuted)
            }
        }
    }
}

private struct WorkspaceCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WorkspaceStyle.spacingSm) {
            content
        }
        .padding(.vertical, WorkspaceStyle.spacingMd)
        .padding(.horizontal, WorkspaceStyle.spacingMd)
        .background(
            RoundedRectangle(cornerRadius: WorkspaceStyle.radiusLg, style: .continuous)
                .fill(WorkspaceStyle.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: WorkspaceStyle.radiusLg, style: .continuous)
                .stroke(WorkspaceStyle.cardBorder.opacity(0.6), lineWidth: WorkspaceStyle.hairline)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 12, y: 6)
    }
}

private struct WorkspaceSeparator: View {
    var inset: Bool = false

    var body: some View {
        Rectangle()
            .fill(WorkspaceStyle.accent.opacity(0.16))
            .frame(height: WorkspaceStyle.hairline)
            .cornerRadius(WorkspaceStyle.hairline)
            .padding(.horizontal, inset ? WorkspaceStyle.spacingMd : 0)
    }
}

private struct WorkspacePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.white)
            .padding(.vertical, WorkspaceStyle.spacingSm)
            .padding(.horizontal, WorkspaceStyle.spacingMd)
            .background(
                RoundedRectangle(cornerRadius: WorkspaceStyle.radiusMd, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [WorkspaceStyle.accent, WorkspaceStyle.accent.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .opacity(configuration.isPressed ? 0.9 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct WorkspaceSecondaryButtonStyle: ButtonStyle {
    var compact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(WorkspaceStyle.accent)
            .padding(.vertical, compact ? WorkspaceStyle.spacingXs : WorkspaceStyle.spacingSm)
            .padding(.horizontal, compact ? WorkspaceStyle.spacingSm : WorkspaceStyle.spacingMd)
            .background(
                RoundedRectangle(cornerRadius: WorkspaceStyle.radiusMd, style: .continuous)
                    .fill(WorkspaceStyle.accentSoft.opacity(0.35))
            )
            .overlay(
                RoundedRectangle(cornerRadius: WorkspaceStyle.radiusMd, style: .continuous)
                    .stroke(WorkspaceStyle.accent.opacity(0.35), lineWidth: WorkspaceStyle.hairline)
            )
            .opacity(configuration.isPressed ? 0.9 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}
