//
//  SelectableSubtitleTextView.swift
//  audio-earning
//
//  Created by Claude on 2025/10/28.
//

import SwiftUI
import UIKit

/// Subtitle view backed by UITextView that supports selection and syncing highlights.
@available(iOS 17.0, *)
struct SelectableSubtitleTextView: UIViewRepresentable {
    @ObservedObject var viewModel: AudioPlayerViewModel
    let text: String
    var isActive: Bool
    var appearance: SubtitleAppearance

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var resolvedBasePointSize: CGFloat {
        SubtitleFontScaler.basePointSize(
            for: appearance.textSize,
            horizontalClass: horizontalSizeClass,
            dynamicType: dynamicTypeSize
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel, appearance: appearance)
    }

    func makeUIView(context: Context) -> DynamicTextView {
        let textView = DynamicTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.showsVerticalScrollIndicator = false
        textView.showsHorizontalScrollIndicator = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.adjustsFontForContentSizeCategory = true
        textView.dataDetectorTypes = []
        textView.tintColor = .systemBlue
        textView.delegate = context.coordinator

        context.coordinator.attach(textView: textView)
        context.coordinator.updateBasePointSize(resolvedBasePointSize)
        context.coordinator.updateAppearance(appearance)
        context.coordinator.update(text: text, isActive: isActive)
        return textView
    }

    func updateUIView(_ uiView: DynamicTextView, context: Context) {
        context.coordinator.viewModel = viewModel
        context.coordinator.updateBasePointSize(resolvedBasePointSize)
        context.coordinator.updateAppearance(appearance)
        context.coordinator.update(text: text, isActive: isActive)
    }

    /// UITextView subclass with dynamic height; scrolling is disabled so SwiftUI can size it.
    final class DynamicTextView: UITextView {
        override var intrinsicContentSize: CGSize {
            CGSize(width: UIView.noIntrinsicMetric, height: contentSize.height)
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            if !isScrollEnabled {
                invalidateIntrinsicContentSize()
            }
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UITextViewDelegate {
        weak var viewModel: AudioPlayerViewModel?
        private weak var textView: DynamicTextView?

        private var cachedText: String = ""
        private var cachedHighlights: Set<String> = []
        private var cachedIsActive: Bool = false
        private var cachedAppearance: SubtitleAppearance
        private var isUpdatingText = false
        private var pendingSelectionWorkItem: DispatchWorkItem?
        private var appearance: SubtitleAppearance
        private var basePointSize: CGFloat = 22

        private var highlightColor: UIColor {
            UIColor(Color.accentColor)
        }

        private var highlightBackground: UIColor {
            highlightColor.withAlphaComponent(0.18)
        }

        init(viewModel: AudioPlayerViewModel, appearance: SubtitleAppearance) {
            self.viewModel = viewModel
            self.appearance = appearance
            self.cachedAppearance = appearance
        }

        func updateBasePointSize(_ size: CGFloat) {
            guard abs(basePointSize - size) > 0.1 else { return }
            basePointSize = size
            rebuildAttributedText(for: cachedText, isActive: cachedIsActive)
        }

        func attach(textView: DynamicTextView) {
            self.textView = textView
        }

        func updateAppearance(_ appearance: SubtitleAppearance) {
            guard self.appearance != appearance else { return }
            self.appearance = appearance
        }

        func update(text: String, isActive: Bool) {
            guard let textView else { return }

            let highlights = viewModel?.highlightedWords ?? Set<String>()
            if cachedText != text || cachedHighlights != highlights || cachedAppearance != appearance || cachedIsActive != isActive {
                rebuildAttributedText(for: text, isActive: isActive)
            }

            if cachedIsActive != isActive {
                cachedIsActive = isActive
            }

            let tintAlpha: CGFloat = isActive ? 1.0 : 0.6
            textView.tintColor = highlightColor.withAlphaComponent(tintAlpha)

            cachedAppearance = appearance
        }

        private func rebuildAttributedText(for text: String, isActive: Bool) {
            guard let textView else { return }
            let highlights = viewModel?.highlightedWords ?? Set<String>()
            let attributed = NSMutableAttributedString(string: text)
            let fullRange = NSRange(location: 0, length: attributed.length)

            let weight: UIFont.Weight = isActive ? .semibold : .medium
            let baseFont = appearance.font.uiFont(size: basePointSize, weight: weight)
            let textColor = isActive ? UIColor(appearance.theme.activeTextColor) : UIColor(appearance.theme.inactiveTextColor)

            let paragraphStyle = paragraphStyle()

            attributed.addAttributes([
                .font: baseFont,
                .foregroundColor: textColor,
                .paragraphStyle: paragraphStyle
            ], range: fullRange)

            let nsText = text as NSString
            enumerateWordRanges(in: nsText, range: fullRange) { [self] word, range in
                guard let vm = viewModel else { return }
                let normalized = vm.normalizedWord(word)
                guard highlights.contains(normalized) else { return }

                attributed.addAttributes([
                    .foregroundColor: highlightColor,
                    .backgroundColor: highlightBackground
                ], range: range)
            }

            isUpdatingText = true
            let selectedRange = textView.selectedRange
            textView.attributedText = attributed
            textView.selectedRange = selectedRange
            isUpdatingText = false

            cachedText = text
            cachedHighlights = highlights
        }

        private func paragraphStyle() -> NSParagraphStyle {
            let style = NSMutableParagraphStyle()
            let multiplier: CGFloat
            switch appearance.textSize {
            case .small: multiplier = 1.18
            case .medium: multiplier = 1.24
            case .large: multiplier = 1.3
            }
            style.lineHeightMultiple = multiplier
            style.alignment = .natural
            style.paragraphSpacing = 6
            return style
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isUpdatingText else { return }
            guard textView.selectedRange.length > 0 else {
                pendingSelectionWorkItem?.cancel()
                pendingSelectionWorkItem = nil
                return
            }

            pendingSelectionWorkItem?.cancel()

            let range = textView.selectedRange
            let workItem = DispatchWorkItem { [weak self, weak textView] in
                guard let self, let textView else { return }
                guard range == textView.selectedRange else { return }
                self.handleSelection(range: range)
            }

            pendingSelectionWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: workItem)
        }

        private func handleSelection(range: NSRange) {
            guard let textView, let textStorage = textView.text as NSString?, let viewModel else { return }

            var processedTokens = Set<String>()

            enumerateWordRanges(in: textStorage, range: range) { word, _ in
                let normalized = viewModel.normalizedWord(word)
                guard !normalized.isEmpty, processedTokens.insert(normalized).inserted else { return }

                if viewModel.isWordHighlighted(word) {
                    viewModel.removeHighlight(word)
                } else {
                    viewModel.highlightWord(word)
                }
            }

            pendingSelectionWorkItem = nil
        }

        private func enumerateWordRanges(
            in text: NSString,
            range: NSRange,
            handler: @escaping (String, NSRange) -> Void
        ) {
            text.enumerateSubstrings(in: range, options: [.byWords, .localized]) { substring, substringRange, _, _ in
                guard let substring else { return }
                handler(substring, substringRange)
            }
        }
    }
}
