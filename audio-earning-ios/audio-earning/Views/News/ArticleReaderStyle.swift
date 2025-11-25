//
//  ArticleReaderStyle.swift
//  audio-earning
//
//  Design system for elegant news article reading experience
//  Inspired by Apple News and Medium
//

import SwiftUI

enum ArticleReaderStyle {
    // MARK: - Font Sizes (Base values for @ScaledMetric)

    /// Large title for article headlines (32pt)
    static let titleSize: CGFloat = 32

    /// Body text size optimized for long-form reading (18pt)
    static let bodySize: CGFloat = 18

    /// Metadata and captions (14pt)
    static let captionSize: CGFloat = 14

    // MARK: - Line Spacing

    /// Extra space between title lines (4pt)
    static let titleLineSpacing: CGFloat = 4

    /// Extra space between body lines (~0.44x body size = 8pt)
    /// Target line-height ratio: 1.47 (26pt / 18pt)
    static let bodyLineSpacing: CGFloat = 8

    /// Extra space between caption lines
    static let captionLineSpacing: CGFloat = 3

    // MARK: - Letter Spacing (Tracking)

    /// Subtle letter spacing for body text improves readability
    static let bodyTracking: CGFloat = 0.2

    /// Tighter tracking for titles
    static let titleTracking: CGFloat = -0.3

    // MARK: - Paragraph & Section Spacing

    /// Space between paragraphs (1.5x line-height)
    static let paragraphSpacing: CGFloat = 20

    /// Space between major sections
    static let sectionSpacing: CGFloat = 32

    // MARK: - Reading Width

    /// Maximum reading width for optimal readability (55-66 chars/line)
    /// Reference: Medium uses 680-700px
    static let maxReadingWidth: CGFloat = 680

    /// Horizontal padding for content
    static let horizontalPadding: CGFloat = 24

    /// Minimum side margin on larger screens
    static let minimumSideMargin: CGFloat = 32

    // MARK: - Vertical Spacing

    /// Top margin before article content
    static let topMargin: CGFloat = 20

    /// Bottom margin after article content
    static let bottomMargin: CGFloat = 60

    /// Space between header image and content
    static let imageBottomSpacing: CGFloat = 24

    /// Space between title and metadata
    static let titleMetadataSpacing: CGFloat = 12

    /// Space between metadata and divider
    static let metadataDividerSpacing: CGFloat = 16

    // MARK: - Header Image

    /// Standard header image height
    static let headerImageHeight: CGFloat = 280

    /// Image corner radius (only bottom corners)
    static let imageCornerRadius: CGFloat = 0

    // MARK: - Colors

    /// Background color (system grouped background)
    static let backgroundColor = Color(.systemGroupedBackground)

    /// Card background color
    static let cardBackground = Color(.systemBackground)

    /// Secondary background for subtle elements
    static let secondaryBackground = Color(.secondarySystemBackground)

    /// Accent color for highlights and interactive elements
    static let accentColor = Color.accentColor

    /// Muted text color for secondary information
    static let mutedTextColor = Color.primary.opacity(0.6)

    /// Divider color
    static let dividerColor = Color.primary.opacity(0.1)

    // MARK: - Paragraph Highlight Colors

    /// Background color for highlighted paragraphs
    static let highlightBackground = Color.yellow.opacity(0.15)

    /// Dark mode highlight background (needs to be more visible)
    static let highlightBackgroundDark = Color.yellow.opacity(0.25)

    /// Indicator color for paragraphs with notes
    static let noteIndicatorColor = Color.blue

    // MARK: - AI Explanation Card

    /// Background tint for AI explanation cards
    static let aiCardBackground = Color.blue.opacity(0.05)

    /// Border color for AI cards
    static let aiCardBorder = Color.blue.opacity(0.2)

    /// Corner radius for AI cards
    static let aiCardCornerRadius: CGFloat = 16

    /// Padding inside AI cards
    static let aiCardPadding: CGFloat = 16

    // MARK: - Animation

    /// Standard spring animation for expand/collapse
    static let springAnimation = Animation.spring(response: 0.4, dampingFraction: 0.8)

    /// Quick fade animation
    static let fadeAnimation = Animation.easeInOut(duration: 0.2)

    // MARK: - Interactive Feedback

    /// Long press minimum duration (800ms recommended for secondary actions)
    static let longPressDuration: Double = 0.8

    /// Background opacity for pressed state
    static let pressedBackgroundOpacity: Double = 0.1
}

// MARK: - Helper Extensions

extension ArticleReaderStyle {
    /// Returns highlight background color adapted for current color scheme
    static func highlightBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? highlightBackgroundDark : highlightBackground
    }

    /// Calculate optimal reading width based on screen size
    static func adaptiveReadingWidth(screenWidth: CGFloat) -> CGFloat {
        let availableWidth = screenWidth - (horizontalPadding * 2)
        return min(availableWidth, maxReadingWidth)
    }
}
