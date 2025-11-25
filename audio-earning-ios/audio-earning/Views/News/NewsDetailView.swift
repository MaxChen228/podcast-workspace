//
//  NewsDetailView.swift
//  audio-earning
//
//  Elegant news article reader with Apple News + Medium inspired design
//

import SwiftUI

struct NewsDetailView: View {
    let article: NewsArticle
    @State private var content: NewsArticleContent?
    @State private var paragraphs: [NewsArticleParagraph] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showSettings = false
    @State private var appearance: NewsReaderAppearance = NewsReaderAppearance.loadFromUserDefaults()

    // Dynamic Type support with appearance-based sizing
    @ScaledMetric(relativeTo: .title) private var scaledTitleSize: CGFloat = 32
    @ScaledMetric(relativeTo: .body) private var scaledBodySize: CGFloat = 18
    @ScaledMetric(relativeTo: .caption) private var scaledCaptionSize: CGFloat = 14

    @Environment(\.colorScheme) var colorScheme

    // Computed sizes based on appearance settings
    private var titleSize: CGFloat {
        scaledTitleSize * (appearance.textSize.titleSize / ArticleReaderStyle.titleSize)
    }

    private var bodySize: CGFloat {
        scaledBodySize * (appearance.textSize.bodySize / ArticleReaderStyle.bodySize)
    }

    private var captionSize: CGFloat {
        scaledCaptionSize * (appearance.textSize.captionSize / ArticleReaderStyle.captionSize)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Header Image
                headerImageView

                // Content Container with constrained reading width
                contentContainer
            }
        }
        .background(ArticleReaderStyle.backgroundColor.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "textformat.size")
                        .font(.body.weight(.medium))
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            NewsReaderSettingsSheet(appearance: $appearance)
                .onChange(of: appearance) { _, newValue in
                    newValue.saveToUserDefaults()
                }
        }
        .task {
            loadContent()
        }
    }

    // MARK: - Header Image

    private var headerImageView: some View {
        Group {
            if let imageURL = article.imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: ArticleReaderStyle.headerImageHeight)
                            .clipped()
                    case .failure:
                        EmptyView()
                    case .empty:
                        Rectangle()
                            .fill(Color.gray.opacity(0.15))
                            .frame(height: ArticleReaderStyle.headerImageHeight)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
        }
    }

    // MARK: - Content Container

    private var contentContainer: some View {
        VStack(alignment: .leading, spacing: ArticleReaderStyle.sectionSpacing) {
            // Title Section
            titleSection

            // Metadata Section
            metadataSection

            Divider()
                .background(ArticleReaderStyle.dividerColor)
                .padding(.vertical, ArticleReaderStyle.metadataDividerSpacing)

            // Article Body
            articleBody
        }
        .padding(.horizontal, ArticleReaderStyle.horizontalPadding)
        .padding(.top, ArticleReaderStyle.topMargin)
        .padding(.bottom, ArticleReaderStyle.bottomMargin)
        .frame(maxWidth: ArticleReaderStyle.maxReadingWidth)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Title Section

    private var titleSection: some View {
        Text(content?.title ?? article.title)
            .font(appearance.titleFont.font(size: titleSize, weight: .bold))
            .lineSpacing(ArticleReaderStyle.titleLineSpacing)
            .tracking(ArticleReaderStyle.titleTracking)
            .multilineTextAlignment(.leading)
            .foregroundColor(.primary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Metadata Section

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Provider
                if let provider = content?.providerName ?? article.providerName {
                    Label {
                        Text(provider)
                            .font(.system(size: captionSize, weight: .medium))
                    } icon: {
                        Image(systemName: "newspaper")
                            .font(.system(size: captionSize))
                    }
                    .foregroundColor(ArticleReaderStyle.mutedTextColor)
                }

                Spacer()

                // Date
                let date = content?.datePublished ?? article.relativePublishedText
                if !date.isEmpty {
                    Text(date)
                        .font(.system(size: captionSize))
                        .foregroundColor(ArticleReaderStyle.mutedTextColor)
                }
            }

            // Author (if available)
            if let author = content?.author, !author.isEmpty {
                Text("作者：\(author)")
                    .font(.system(size: captionSize))
                    .foregroundColor(ArticleReaderStyle.mutedTextColor)
            }
        }
    }

    // MARK: - Article Body

    private var articleBody: some View {
        Group {
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(message: error)
            } else {
                paragraphsView
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("載入文章內容...")
                .font(.system(size: bodySize, design: .serif))
                .foregroundColor(ArticleReaderStyle.mutedTextColor)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)

            Text(message)
                .font(.system(size: bodySize, design: .serif))
                .multilineTextAlignment(.center)
                .foregroundColor(ArticleReaderStyle.mutedTextColor)

            Button("重試") {
                loadContent()
            }
            .font(.system(size: bodySize, weight: .semibold))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(ArticleReaderStyle.accentColor)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private var paragraphsView: some View {
        VStack(alignment: .leading, spacing: ArticleReaderStyle.paragraphSpacing) {
            ForEach(paragraphs) { paragraph in
                Text(paragraph.text)
                    .font(appearance.bodyFont.font(size: bodySize, weight: .regular))
                    .lineSpacing(ArticleReaderStyle.bodyLineSpacing)
                    .tracking(ArticleReaderStyle.bodyTracking)
                    .multilineTextAlignment(.leading)
                    .textSelection(.enabled)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Data Loading

    private func loadContent() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let loadedContent = try await NewsService.shared.fetchArticleContent(url: article.url)
                content = loadedContent

                // Parse content into paragraphs
                paragraphs = NewsArticleParagraph.parse(content: loadedContent.content)

                isLoading = false
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
