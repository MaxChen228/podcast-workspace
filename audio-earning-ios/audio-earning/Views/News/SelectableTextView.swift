//
//  SelectableTextView.swift
//  audio-earning
//
//  UITextView wrapper with custom text selection and AI explanation menu
//

import SwiftUI
import UIKit

struct SelectableTextView: UIViewRepresentable {
    let text: String
    let font: UIFont
    let textColor: UIColor
    let lineSpacing: CGFloat
    let tracking: CGFloat
    let isHighlighted: Bool
    @Binding var selectedText: String?
    @Binding var selectionRect: CGRect?
    let onExplainSelection: (String) -> Void

    func makeUIView(context: Context) -> SelfSizingTextView {
        let textView = SelfSizingTextView()

        // Configure text view
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.delegate = context.coordinator

        // Important: Set content compression resistance
        textView.setContentCompressionResistancePriority(.required, for: .vertical)
        textView.setContentHuggingPriority(.required, for: .vertical)

        // Configure text attributes
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        paragraphStyle.alignment = .left

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle,
            .kern: tracking
        ]

        textView.attributedText = NSAttributedString(string: text, attributes: attributes)

        return textView
    }

    func updateUIView(_ textView: SelfSizingTextView, context: Context) {
        // Update text attributes if needed
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        paragraphStyle.alignment = .left

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle,
            .kern: tracking
        ]

        textView.attributedText = NSAttributedString(string: text, attributes: attributes)

        // Update background for highlight
        if isHighlighted {
            textView.backgroundColor = UIColor(Color.accentColor.opacity(0.12))
            textView.layer.cornerRadius = 8
            textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        } else {
            textView.backgroundColor = .clear
            textView.textContainerInset = .zero
        }

        // Invalidate intrinsic content size after update
        textView.invalidateIntrinsicContentSize()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onExplainSelection: onExplainSelection,
            selectedText: $selectedText,
            selectionRect: $selectionRect
        )
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UITextViewDelegate {
        let onExplainSelection: (String) -> Void
        let selectedText: Binding<String?>
        let selectionRect: Binding<CGRect?>
        weak var textView: UITextView?
        private var selectionDebounceTimer: Timer?

        init(
            onExplainSelection: @escaping (String) -> Void,
            selectedText: Binding<String?>,
            selectionRect: Binding<CGRect?>
        ) {
            self.onExplainSelection = onExplainSelection
            self.selectedText = selectedText
            self.selectionRect = selectionRect
            super.init()
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            self.textView = textView

            // Cancel previous timer
            selectionDebounceTimer?.invalidate()

            // Check if there's a selection
            guard let selectedRange = textView.selectedTextRange,
                  !selectedRange.isEmpty else {
                // Clear selection
                DispatchQueue.main.async {
                    self.selectedText.wrappedValue = nil
                    self.selectionRect.wrappedValue = nil
                }
                return
            }

            // Debounce: wait 0.2s before processing selection
            selectionDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { [weak self] _ in
                self?.processSelection(textView: textView, selectedRange: selectedRange)
            }
        }

        private func processSelection(textView: UITextView, selectedRange: UITextRange) {
            guard let text = textView.text(in: selectedRange) else {
                clearSelection()
                return
            }

            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                clearSelection()
                return
            }

            // Get selection rect
            let selectionRects = textView.selectionRects(for: selectedRange)
            guard let firstRect = selectionRects.first else {
                clearSelection()
                return
            }

            // Update bindings on main thread
            DispatchQueue.main.async {
                self.selectedText.wrappedValue = trimmed
                self.selectionRect.wrappedValue = firstRect.rect
            }
        }

        private func clearSelection() {
            DispatchQueue.main.async {
                self.selectedText.wrappedValue = nil
                self.selectionRect.wrappedValue = nil
            }
        }
    }
}

// MARK: - Self-Sizing TextView

/// UITextView subclass that properly reports its intrinsic content size
class SelfSizingTextView: UITextView {
    override var intrinsicContentSize: CGSize {
        // Calculate the size needed to display all text
        let size = sizeThatFits(CGSize(width: bounds.width, height: .greatestFiniteMagnitude))
        return CGSize(width: UIView.noIntrinsicMetric, height: size.height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Invalidate intrinsic content size when layout changes
        invalidateIntrinsicContentSize()
    }

    override var text: String! {
        didSet {
            invalidateIntrinsicContentSize()
        }
    }

    override var attributedText: NSAttributedString! {
        didSet {
            invalidateIntrinsicContentSize()
        }
    }

    override var font: UIFont? {
        didSet {
            invalidateIntrinsicContentSize()
        }
    }

    override var textContainerInset: UIEdgeInsets {
        didSet {
            invalidateIntrinsicContentSize()
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var selectedText1: String?
        @State private var selectionRect1: CGRect?
        @State private var selectedText2: String?
        @State private var selectionRect2: CGRect?

        var body: some View {
            ScrollView {
                VStack(spacing: 20) {
                    SelectableTextView(
                        text: "The Dallas Wings won the 2026 WNBA draft lottery on Sunday, securing the No. 1 overall pick in next year's draft.",
                        font: UIFont.systemFont(ofSize: 18, weight: .regular),
                        textColor: .label,
                        lineSpacing: 6,
                        tracking: 0.3,
                        isHighlighted: false,
                        selectedText: $selectedText1,
                        selectionRect: $selectionRect1,
                        onExplainSelection: { selectedText in
                            print("Selected text: \(selectedText)")
                        }
                    )
                    .padding()

                    SelectableTextView(
                        text: "The Wings had the best odds at 44.2% after finishing with the league's worst record at 9-31 in 2025.",
                        font: UIFont.systemFont(ofSize: 18, weight: .regular),
                        textColor: .label,
                        lineSpacing: 6,
                        tracking: 0.3,
                        isHighlighted: true,
                        selectedText: $selectedText2,
                        selectionRect: $selectionRect2,
                        onExplainSelection: { selectedText in
                            print("Selected text: \(selectedText)")
                        }
                    )
                    .padding()
                }
            }
        }
    }

    return PreviewWrapper()
}
