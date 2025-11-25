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
    let onExplainSelection: (String) -> Void

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()

        // Configure text view
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.delegate = context.coordinator

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

        // Add custom menu item
        setupCustomMenu(for: textView, coordinator: context.coordinator)

        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
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
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onExplainSelection: onExplainSelection)
    }

    private func setupCustomMenu(for textView: UITextView, coordinator: Coordinator) {
        // Store reference for coordinator to use
        coordinator.textView = textView
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UITextViewDelegate {
        let onExplainSelection: (String) -> Void
        weak var textView: UITextView?

        init(onExplainSelection: @escaping (String) -> Void) {
            self.onExplainSelection = onExplainSelection
            super.init()
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            // Only show custom menu when there's a selection
            guard let selectedRange = textView.selectedTextRange,
                  !selectedRange.isEmpty else {
                return
            }

            // Add custom menu item for AI explanation
            if UIMenuController.shared.menuItems?.contains(where: { $0.title == "AI 解釋" }) != true {
                let explainItem = UIMenuItem(
                    title: "AI 解釋",
                    action: #selector(explainSelection)
                )

                var menuItems = UIMenuController.shared.menuItems ?? []
                menuItems.insert(explainItem, at: 0)
                UIMenuController.shared.menuItems = menuItems
            }
        }

        @objc func explainSelection() {
            guard let textView = textView,
                  let selectedRange = textView.selectedTextRange,
                  let selectedText = textView.text(in: selectedRange) else {
                return
            }

            let trimmedText = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedText.isEmpty else { return }

            onExplainSelection(trimmedText)

            // Clear selection after action
            textView.selectedTextRange = nil
        }

        override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
            // Enable our custom action when text is selected
            if action == #selector(explainSelection) {
                return textView?.selectedTextRange?.isEmpty == false
            }

            // Allow default actions (copy, etc.)
            return super.canPerformAction(action, withSender: sender)
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            SelectableTextView(
                text: "The Dallas Wings won the 2026 WNBA draft lottery on Sunday, securing the No. 1 overall pick in next year's draft.",
                font: UIFont.systemFont(ofSize: 18, weight: .regular),
                textColor: .label,
                lineSpacing: 6,
                tracking: 0.3,
                isHighlighted: false,
                onExplainSelection: { selectedText in
                    print("Selected text: \(selectedText)")
                }
            )
            .frame(maxWidth: .infinity)
            .padding()

            SelectableTextView(
                text: "The Wings had the best odds at 44.2% after finishing with the league's worst record at 9-31 in 2025.",
                font: UIFont.systemFont(ofSize: 18, weight: .regular),
                textColor: .label,
                lineSpacing: 6,
                tracking: 0.3,
                isHighlighted: true,
                onExplainSelection: { selectedText in
                    print("Selected text: \(selectedText)")
                }
            )
            .frame(maxWidth: .infinity)
            .padding()
        }
    }
}
