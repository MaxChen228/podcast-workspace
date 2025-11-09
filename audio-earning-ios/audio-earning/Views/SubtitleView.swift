//
//  SubtitleView.swift
//  audio-earning
//
//  Created by Claude on 2025/10/27.
//

import SwiftUI
import UIKit

/// Subtitle display view with optional word-level highlighting.
struct SubtitleView: View {
    @ObservedObject var viewModel: AudioPlayerViewModel
    let text: String
    let isActive: Bool

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var appearance: SubtitleAppearance {
        viewModel.subtitleAppearance
    }

    private var basePointSize: CGFloat {
        SubtitleFontScaler.basePointSize(
            for: appearance.textSize,
            horizontalClass: horizontalSizeClass,
            dynamicType: dynamicTypeSize
        )
    }

    private var wordTokens: [SubtitleToken] {
        tokenize(text: text)
    }

    var body: some View {
        Group {
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                placeholderView
            } else if isWordMode {
                focusWordView
            } else if #available(iOS 17.0, *) {
                SelectableSubtitleTextView(
                    viewModel: viewModel,
                    text: text,
                    isActive: isActive,
                    appearance: appearance
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                fallbackTokenizedView
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, isWordMode ? 28 : 14)
        .frame(maxWidth: .infinity, minHeight: isWordMode ? 140 : 70, alignment: isWordMode ? .center : .leading)
        .background(bubbleBackground)
        .shadow(color: appearance.theme.subtitleShadow.opacity(isActive ? 0.35 : 0.18), radius: isActive ? 18 : 10, x: 0, y: isActive ? 12 : 6)
    }

    private var placeholderView: some View {
        Text("—")
            .font(appearance.font.font(size: basePointSize, weight: .medium))
            .foregroundColor(appearance.theme.inactiveTextColor)
            .frame(maxWidth: .infinity, minHeight: 60)
    }

    private var isWordMode: Bool {
        viewModel.displayMode == .wordLevel
    }

    private var focusWordView: some View {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = viewModel.normalizedWord(trimmed)
        let isHighlighted = viewModel.isWordHighlighted(trimmed)
        let displayColor = isHighlighted ? Color.accentColor : appearance.theme.activeTextColor
        let fontSize = basePointSize * 2.2

        return Text(trimmed)
            .font(appearance.font.font(size: fontSize, weight: .semibold))
            .foregroundColor(displayColor)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .onTapGesture {
                guard !normalized.isEmpty else { return }
                if isHighlighted {
                    viewModel.removeHighlight(trimmed)
                } else {
                    viewModel.highlightWord(trimmed)
                }
            }
    }

    @ViewBuilder
    private var fallbackTokenizedView: some View {
        if wordTokens.isEmpty {
            placeholderView
        } else {
            WordWrapLayout(spacing: 8) {
                ForEach(wordTokens) { token in
                    HighlightableWordView(
                        text: token.display,
                        isHighlighted: viewModel.isWordHighlighted(token.display),
                        appearance: appearance,
                        basePointSize: basePointSize,
                        highlightAction: {
                            viewModel.highlightWord(token.display)
                        },
                        removeAction: {
                            viewModel.removeHighlight(token.display)
                        }
                    )
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.highlightedWords)
        }
    }

    /// Split subtitle text into tokens.
    private func tokenize(text: String) -> [SubtitleToken] {
        text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .map { SubtitleToken(display: $0) }
    }

    private var bubbleBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(isActive ? appearance.theme.activeBackground : appearance.theme.inactiveBackground)
    }
}

/// Subtitle container that shows controls and the current subtitle presentation.
struct SubtitleContainerView: View {
    @ObservedObject var viewModel: AudioPlayerViewModel
    @State private var isShowingSettingsSheet = false
    @State private var isShowingLexiconList = false
    @State private var isAdjustingSpeed = false
    @State private var dragStepProgress = 0
    @State private var speedToast: SpeedToast?
    @State private var toastDismissTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                metricsBadge
                controlButtonRow
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 14, x: 0, y: 8)
            .padding(.horizontal, 8)

            Group {
                if viewModel.displayMode == .sentenceLevel {
                    SentenceWheelSubtitleView(viewModel: viewModel)
                        .frame(minHeight: 260, idealHeight: 300, maxHeight: 360)
                        .layoutPriority(1)
                } else {
                    SubtitleView(
                        viewModel: viewModel,
                        text: viewModel.currentSubtitleText,
                        isActive: !viewModel.currentSubtitleText.isEmpty
                    )
                }
            }
            .padding(.horizontal, 12)
        }
        .sheet(isPresented: $isShowingSettingsSheet) {
            SubtitleSettingsSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $isShowingLexiconList) {
            LexiconListView(store: SavedLexiconStore.shared)
        }
        .overlay(alignment: .top) {
            if let toast = speedToast {
                SpeedToastView(message: toast.message)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 4)
            }
        }
        .onDisappear {
            toastDismissTask?.cancel()
            toastDismissTask = nil
        }
    }

    private var controlButtonRow: some View {
        HStack(spacing: 8) {
            translateButton
            lexiconButton
            settingsButton
        }
    }

    @ViewBuilder
    private var metricsBadge: some View {
        if let title = viewModel.metricsBadgeTitle {
            Button {
                resetPlaybackSpeed()
            } label: {
                speedBadgeLabel(base: title, delta: viewModel.metricsBadgeDeltaText)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .highPriorityGesture(speedAdjustmentGesture)
            .accessibilityLabel(speedAccessibilityLabel(base: title))
            .accessibilityHint("向上或向下滑動可每次調整五個字每分鐘，點一下恢復原速")
        }
        Spacer(minLength: 0)
    }

    private let speedGestureStride: CGFloat = 16
    private let speedStepValue = 5

    private var speedAdjustmentGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged { value in
                if !isAdjustingSpeed {
                    isAdjustingSpeed = true
                    dragStepProgress = viewModel.wordsPerMinuteDelta / speedStepValue
                }
                handleSpeedDragChanged(value.translation)
            }
            .onEnded { _ in
                finishSpeedAdjustment()
            }
    }

    private func handleSpeedDragChanged(_ translation: CGSize) {
        let rawStep = (-translation.height) / speedGestureStride
        let targetStep = Int(rawStep.rounded(.towardZero))
        let currentStep = dragStepProgress
        let difference = targetStep - currentStep
        guard difference != 0 else { return }

        let direction = difference > 0 ? 1 : -1
        var remaining = abs(difference)

        while remaining > 0 {
            let result = viewModel.adjustWordsPerMinute(by: direction * speedStepValue)
            triggerHaptic(for: result)
            showSpeedToast(for: result)
            if result == .reachedMaximum || result == .reachedMinimum {
                break
            }
            remaining -= 1
        }

        dragStepProgress = viewModel.wordsPerMinuteDelta / speedStepValue
    }

    private func finishSpeedAdjustment() {
        isAdjustingSpeed = false
        dragStepProgress = viewModel.wordsPerMinuteDelta / speedStepValue
    }

    private func resetPlaybackSpeed() {
        viewModel.setPlaybackRate(1.0)
        triggerImpact(style: .medium)
        showSpeedToast(for: .applied)
    }

    private func triggerHaptic(for result: PlaybackRateAdjustmentResult) {
        switch result {
        case .applied:
            triggerImpact(style: .light)
        case .reachedMinimum, .reachedMaximum:
            triggerImpact(style: .rigid)
        }
    }

    private func triggerImpact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    private func showSpeedToast(for result: PlaybackRateAdjustmentResult) {
        let currentWPM = viewModel.currentWordsPerMinuteDisplay
        var message = "\(currentWPM) WPM · \(viewModel.playbackMultiplierText)"
        if viewModel.isUsingEstimatedWordsPerMinute {
            message += " · 以估算語速"
        }
        switch result {
        case .reachedMaximum:
            message += " · 已達最快"
        case .reachedMinimum:
            message += " · 已達最慢"
        case .applied:
            break
        }
        presentSpeedToast(message)
    }

    private func presentSpeedToast(_ message: String) {
        let toast = SpeedToast(message: message)
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            speedToast = toast
        }
        toastDismissTask?.cancel()
        toastDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if speedToast?.id == toast.id {
                withAnimation(.easeOut(duration: 0.22)) {
                    speedToast = nil
                }
            }
        }
    }

    private func speedBadgeLabel(base: String, delta: String?) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "speedometer")
                .font(.system(size: 12, weight: .semibold))
            HStack(spacing: 4) {
                Text(base)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                if let delta {
                    Text(delta)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.accentColor.opacity(0.12))
        )
        .foregroundColor(.accentColor)
        .overlay(
            VStack(spacing: 2) {
                Image(systemName: "arrow.up")
                Image(systemName: "arrow.down")
            }
            .font(.system(size: 8, weight: .bold))
            .foregroundColor(Color.accentColor.opacity(isAdjustingSpeed ? 0.85 : 0))
            .opacity(isAdjustingSpeed ? 1 : 0)
            .animation(.easeInOut(duration: 0.18), value: isAdjustingSpeed)
        )
        .animation(.easeInOut(duration: 0.18), value: delta)
    }

    private func speedAccessibilityLabel(base: String) -> String {
        if let delta = viewModel.metricsBadgeDeltaText {
            return "播放速度，每分鐘 \(base) 字，較原速 \(delta)"
        } else {
            return "播放速度，每分鐘 \(base) 字"
        }
    }

    private var translateButton: some View {
        Button {
            viewModel.presentSentenceDetail()
        } label: {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.accentColor.opacity(viewModel.canShowSentenceDetail ? 0.18 : 0.08))
            )
            .foregroundColor(viewModel.canShowSentenceDetail ? .accentColor : .secondary)
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canShowSentenceDetail)
        .accessibilityLabel("查看句子詳情")
    }


    private var lexiconButton: some View {
        Button {
            isShowingLexiconList = true
        } label: {
            Image(systemName: "bookmark")
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.accentColor.opacity(0.12))
            )
            .foregroundColor(.accentColor)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("開啟字詞庫")
    }

    private var settingsButton: some View {
        Button {
            isShowingSettingsSheet = true
        } label: {
            Image(systemName: "textformat")
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.accentColor.opacity(0.12))
            )
            .foregroundColor(.accentColor)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("開啟字幕設定")
    }

}

// MARK: - Supporting types

private struct SpeedToast: Identifiable, Equatable {
    let id = UUID()
    let message: String
}

private struct SpeedToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 6)
    }
}

private struct SubtitleToken: Identifiable {
    let id = UUID()
    let display: String
}

private struct HighlightableWordView: View {
    let text: String
    let isHighlighted: Bool
    let appearance: SubtitleAppearance
    let basePointSize: CGFloat
    let highlightAction: () -> Void
    let removeAction: () -> Void

    private var highlightColor: Color {
        Color.accentColor
    }

    var body: some View {
        Text(text)
            .font(appearance.font.font(size: basePointSize * 0.9, weight: .medium))
            .foregroundColor(isHighlighted ? highlightColor : appearance.theme.activeTextColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHighlighted ? highlightColor.opacity(0.18) : Color.clear)
            )
            .onLongPressGesture(minimumDuration: 0.25) {
                if !isHighlighted {
                    highlightAction()
                }
            }
            .onTapGesture {
                if isHighlighted {
                    removeAction()
                }
            }
    }
}

private struct WordWrapLayout: Layout {
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

struct SentenceWheelSubtitleView: View {
    @ObservedObject var viewModel: AudioPlayerViewModel

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var isUserInteracting = false
    @State private var nearestSubtitleID: Int?
    @State private var didFinishInitialAlignment = false

    fileprivate static let coordinateSpaceName = "SentenceWheelScroll"
    private let itemSpacing: CGFloat = 20

    private var basePointSize: CGFloat {
        SubtitleFontScaler.basePointSize(
            for: viewModel.subtitleAppearance.textSize,
            horizontalClass: horizontalSizeClass,
            dynamicType: dynamicTypeSize
        )
    }

    var body: some View {
        GeometryReader { outerGeo in
            let containerHeight = max(outerGeo.size.height, 260)

            ScrollViewReader { proxy in
                ZStack {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: itemSpacing) {
                            ForEach(viewModel.displayedSubtitles) { subtitle in
                                SentenceWheelRow(
                                    subtitle: subtitle,
                                    containerHeight: containerHeight,
                                    isActive: isSubtitleActive(subtitle.id),
                                    isFocused: isSubtitleFocused(subtitle.id),
                                    shouldTrackFocus: shouldTrackFocus,
                                    alignmentCompleted: didFinishInitialAlignment,
                                    appearance: viewModel.subtitleAppearance,
                                    basePointSize: basePointSize,
                                    onTap: {
                                        handleTap(on: subtitle, proxy: proxy)
                                    }
                                )
                                .id(subtitle.id)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, containerHeight * 0.45)
                        .frame(maxWidth: .infinity)
                    }
                    .modifier(ScrollClipDisabledIfAvailable())
                    .mask(fadeMask)
                    .coordinateSpace(name: Self.coordinateSpaceName)
                    .contentShape(Rectangle())
                    .gesture(dragGesture())
                    .onAppear {
                        let initialID = resolvedInitialSubtitleID()
                        nearestSubtitleID = initialID
                        scrollToActiveSubtitle(proxy: proxy, animate: false)
                        DispatchQueue.main.async {
                            didFinishInitialAlignment = initialID != nil
                        }
                    }
                    .onChange(of: viewModel.currentSubtitle?.id) { _, newValue in
                        guard !isUserInteracting else { return }
                        let fallback = resolvedInitialSubtitleID()
                        nearestSubtitleID = newValue ?? fallback
                        didFinishInitialAlignment = (newValue ?? fallback) != nil
                        scrollToActiveSubtitle(proxy: proxy, animate: true)
                    }
                    .onChange(of: viewModel.displayedSubtitles) { _, _ in
                        guard !viewModel.displayedSubtitles.isEmpty else { return }
                        didFinishInitialAlignment = false
                        // 使用主线程更新，避免后台线程更新UI警告
                        Task { @MainActor in
                            nearestSubtitleID = resolvedInitialSubtitleID()
                            scrollToActiveSubtitle(proxy: proxy, animate: false)
                            didFinishInitialAlignment = nearestSubtitleID != nil
                        }
                    }
                    .onChange(of: viewModel.initialSubtitleID) { _, _ in
                        guard !isUserInteracting else { return }
                        let fallback = resolvedInitialSubtitleID()
                        nearestSubtitleID = fallback
                        if fallback != nil {
                            scrollToActiveSubtitle(proxy: proxy, animate: false)
                            didFinishInitialAlignment = true
                        }
                    }
                    .onPreferenceChange(SubtitleOffsetPreferenceKey.self) { entries in
                        updateNearestSubtitle(with: entries)
                    }
                }
                .overlay(alignment: .top) {
                    if !didFinishInitialAlignment {
                        VStack(spacing: 8) {
                            ProgressView()
                                .progressViewStyle(.circular)
                            Text("Aligning subtitles…")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 12)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                    }
                }
            }
        }
    }

    private var shouldTrackFocus: Bool {
        isUserInteracting || viewModel.playerState != .playing
    }

    private func dragGesture() -> some Gesture {
        DragGesture()
            .onChanged { _ in
                if !isUserInteracting {
                    isUserInteracting = true
                    viewModel.pauseForUserInteraction()
                }
            }
            .onEnded { _ in
                isUserInteracting = false
            }
    }

    private func handleTap(on subtitle: SubtitleItem, proxy: ScrollViewProxy) {
        viewModel.pauseForUserInteraction()
        viewModel.seek(to: subtitle.startTime, autoResume: false)
        nearestSubtitleID = subtitle.id

        withAnimation(.easeInOut(duration: 0.3)) {
            proxy.scrollTo(subtitle.id, anchor: .center)
        }
    }

    private func isSubtitleActive(_ id: Int) -> Bool {
        viewModel.currentSubtitle?.id == id
    }

    private func isSubtitleFocused(_ id: Int) -> Bool {
        guard let focusID = nearestSubtitleID else { return false }
        return shouldTrackFocus && focusID == id
    }

    private func scrollToActiveSubtitle(proxy: ScrollViewProxy, animate: Bool) {
        guard !viewModel.displayedSubtitles.isEmpty else { return }

        let targetID = viewModel.currentSubtitle?.id ?? nearestSubtitleID ?? viewModel.displayedSubtitles.first?.id
        guard let targetID else { return }

        let action = {
            proxy.scrollTo(targetID, anchor: .center)
        }

        if animate {
            withAnimation(.easeInOut(duration: 0.35)) {
                action()
            }
        } else {
            action()
        }
    }

    private func updateNearestSubtitle(with entries: [SubtitleOffsetEntry]) {
        guard shouldTrackFocus else { return }
        guard !entries.isEmpty else { return }

        if let closest = entries.min(by: { abs($0.offset) < abs($1.offset) }) {
            // 使用主线程更新，避免后台线程更新UI警告
            Task { @MainActor in
                nearestSubtitleID = closest.id
            }
        }
    }

    private func resolvedInitialSubtitleID() -> Int? {
        if let current = viewModel.currentSubtitle?.id {
            return current
        }
        if let initial = viewModel.initialSubtitleID {
            return initial
        }
        return viewModel.displayedSubtitles.first?.id
    }

    private var fadeMask: some View {
        let base = Color(.systemBackground)
        return LinearGradient(
            gradient: Gradient(stops: [
                .init(color: base.opacity(0.0), location: 0.0),
                .init(color: base.opacity(0.08), location: 0.08),
                .init(color: base.opacity(0.92), location: 0.22),
                .init(color: base.opacity(0.92), location: 0.78),
                .init(color: base.opacity(0.08), location: 0.92),
                .init(color: base.opacity(0.0), location: 1.0)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct SubtitleOffsetEntry: Equatable {
    let id: Int
    let offset: CGFloat
}

private struct SubtitleOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: [SubtitleOffsetEntry] = []

    static func reduce(value: inout [SubtitleOffsetEntry], nextValue: () -> [SubtitleOffsetEntry]) {
        value.append(contentsOf: nextValue())
    }
}

private struct SentenceWheelRow: View {
    let subtitle: SubtitleItem
    let containerHeight: CGFloat
    let isActive: Bool
    let isFocused: Bool
    let shouldTrackFocus: Bool
    let alignmentCompleted: Bool
    let appearance: SubtitleAppearance
    let basePointSize: CGFloat
    let onTap: () -> Void

    @State private var offset: CGFloat = .zero

    var body: some View {
        let radius = max(containerHeight / 2, 1)
        let effectiveOffset = alignmentCompleted ? offset : .zero
        let normalised = min(abs(effectiveOffset) / radius, 1)
        let baseScale = 1 - normalised * 0.22
        let baseOpacity = 1 - normalised * 0.55
        let rotation = Double(effectiveOffset / radius) * 35
        let clampedRotation = max(min(rotation, SentenceWheelRowConstants.maxRotationDegrees), -SentenceWheelRowConstants.maxRotationDegrees)

        let emphasized = isActive || isFocused
        let scale = emphasized ? max(1.04, baseScale) : max(0.86, baseScale)
        let opacity = emphasized ? 1.0 : max(0.3, baseOpacity)
        let fontSize = basePointSize + (emphasized ? 2 : -2)
        let weight: Font.Weight = emphasized ? .semibold : .medium
        let textColor = emphasized ? appearance.theme.activeTextColor : appearance.theme.inactiveTextColor.opacity(opacity)
        let background = emphasized ? appearance.theme.activeBackground : appearance.theme.inactiveBackground
        let shadowOpacity = emphasized ? 0.35 : 0.18

        Text(subtitle.text)
            .font(appearance.font.font(size: fontSize, weight: weight))
            .foregroundColor(textColor)
            .multilineTextAlignment(.center)
            .textSelection(.enabled)
            .padding(.vertical, emphasized ? 18 : 14)
            .padding(.horizontal, emphasized ? 22 : 18)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(background)
            )
            .shadow(color: appearance.theme.subtitleShadow.opacity(shadowOpacity), radius: emphasized ? 22 : 12, x: 0, y: emphasized ? 14 : 8)
            .scaleEffect(scale)
            .rotation3DEffect(
                .degrees(clampedRotation),
                axis: (x: 1, y: 0, z: 0),
                anchor: .center,
                perspective: 0.9
            )
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(
                            key: SubtitleOffsetPreferenceKey.self,
                            value: preferenceValue(for: computeOffset(in: geo))
                        )
                        .onAppear {
                            let initialOffset = computeOffset(in: geo)
                            updateOffsetIfNeeded(initialOffset)
                        }
                        .onChange(of: computeOffset(in: geo)) { _, newValue in
                            updateOffsetIfNeeded(newValue)
                        }
                }
            )
            .onTapGesture {
                onTap()
            }
            .animation(.easeInOut(duration: 0.2), value: emphasized)
            .animation(.easeInOut(duration: 0.2), value: offset)
    }
}

private extension SentenceWheelRow {
    func computeOffset(in geo: GeometryProxy) -> CGFloat {
        let frame = geo.frame(in: .named(SentenceWheelSubtitleView.coordinateSpaceName))
        let centerY = containerHeight / 2
        return frame.midY - centerY
    }

    func updateOffsetIfNeeded(_ newValue: CGFloat) {
        guard alignmentCompleted else {
            if offset != .zero {
                DispatchQueue.main.async {
                    offset = .zero
                }
            }
            return
        }
        guard newValue.isFinite else { return }
        // 使用適中的閾值，既能減少頻繁更新，又能保持流暢的轉動效果
        if abs(offset - newValue) > 0.5 {
            // 确保在主线程更新状态
            DispatchQueue.main.async { [newValue] in
                offset = newValue
            }
        }
    }

    func preferenceValue(for offsetValue: CGFloat) -> [SubtitleOffsetEntry] {
        guard shouldTrackFocus, alignmentCompleted else { return [] }
        return [SubtitleOffsetEntry(id: subtitle.id, offset: offsetValue)]
    }
}

private enum SentenceWheelRowConstants {
    static let maxRotationDegrees: Double = 80
}

private struct ScrollClipDisabledIfAvailable: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.scrollClipDisabled()
        } else {
            content
        }
    }
}

@MainActor
private struct SubtitlePreviewContainer: View {
    @StateObject private var viewModel = AudioPlayerViewModel()
    @StateObject private var containerViewModel: AudioPlayerViewModel

    init() {
        let containerVM = AudioPlayerViewModel()
        containerVM.totalDuration = 360.0
        containerVM.currentTime = 125.5
        containerVM.currentSubtitleText = "Learning English is fun!"
        _containerViewModel = StateObject(wrappedValue: containerVM)
    }

    var body: some View {
        VStack(spacing: 20) {
            SubtitleView(
                viewModel: viewModel,
                text: "Welcome to the storytelling series!",
                isActive: true
            )
            .padding()

            SubtitleView(
                viewModel: viewModel,
                text: "This is a longer subtitle that demonstrates how the text wraps when it's too long for a single line.",
                isActive: true
            )
            .padding()

            SubtitleView(
                viewModel: viewModel,
                text: "",
                isActive: false
            )
            .padding()

            SubtitleContainerView(viewModel: containerViewModel)
        }
    }
}

#Preview {
    SubtitlePreviewContainer()
}
