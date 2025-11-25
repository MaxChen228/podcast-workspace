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
        .frame(maxWidth: ArticleReaderStyle.maxReadingWidth)
        .padding(.horizontal, ArticleReaderStyle.horizontalPadding)
        .padding(.top, ArticleReaderStyle.topMargin)
        .padding(.bottom, ArticleReaderStyle.bottomMargin)
    }

    // MARK: - Title Section

    private var titleSection: some View {
        Text(content?.title ?? article.title)
            .font(appearance.titleFont.font(size: titleSize, weight: .bold))
            .lineSpacing(ArticleReaderStyle.titleLineSpacing)
            .tracking(ArticleReaderStyle.titleTracking)
            .multilineTextAlignment(.leading)
            .foregroundColor(.primary)
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
            ForEach(paragraphs.indices, id: \.self) { index in
                NewsParagraphView(
                    paragraph: paragraphs[index],
                    appearance: appearance,
                    bodySize: bodySize,
                    onExplainRequest: {
                        handleExplainRequest(for: index)
                    },
                    onHighlightToggle: {
                        handleHighlightToggle(for: index)
                    },
                    onNoteAdd: {
                        handleNoteAdd(for: index)
                    }
                )
            }
        }
    }

    // MARK: - Interaction Handlers

    private func handleExplainRequest(for index: Int) {
        guard index < paragraphs.count else { return }

        // Toggle explanation state
        if paragraphs[index].isExplanationExpanded {
            // Collapse
            paragraphs[index].explanationState = .collapsed
        } else {
            // Start loading
            paragraphs[index].explanationState = .loading

            // Fetch explanation
            Task {
                await fetchParagraphExplanation(for: index)
            }
        }
    }

    private func handleHighlightToggle(for index: Int) {
        guard index < paragraphs.count else { return }
        paragraphs[index].isHighlighted.toggle()

        // TODO: Persist highlight state to UserDefaults or CoreData
    }

    private func handleNoteAdd(for index: Int) {
        guard index < paragraphs.count else { return }

        // TODO: Show note editor sheet
        // For now, just add a sample note
        if paragraphs[index].hasNote {
            paragraphs[index].note = nil
        } else {
            paragraphs[index].note = "添加筆記..."
        }
    }

    private func fetchParagraphExplanation(for index: Int) async {
        guard index < paragraphs.count else { return }

        let paragraph = paragraphs[index]

        // TODO: Integrate with SentenceExplanationService
        // For now, simulate API call with mock data
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds

        // Mock explanation data
        let mockData = ParagraphExplanationData(
            overview: "這段描述了達拉斯自由隊在 2026 年 WNBA 選秀樂透中獲得第一順位選秀權的消息。",
            keyPoints: [
                "達拉斯自由隊贏得選秀樂透",
                "獲得 2026 年第一順位選秀權",
                "這發生在週日"
            ],
            vocabulary: [
                ParagraphVocabularyItem(
                    word: "draft lottery",
                    meaning: "選秀樂透 - 決定球隊選秀順序的抽籤活動",
                    note: "用於職業運動聯盟中分配新秀選秀權"
                ),
                ParagraphVocabularyItem(
                    word: "securing",
                    meaning: "確保、獲得",
                    note: "在此指確定獲得了某項權利"
                )
            ],
            chineseSummary: "達拉斯自由隊在週日贏得了 2026 年 WNBA 選秀樂透，確保了明年選秀的第一順位選秀權。"
        )

        paragraphs[index].explanationState = .expanded(data: mockData)
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
