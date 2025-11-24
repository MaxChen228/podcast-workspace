//
//  NewsDetailView.swift
//  audio-earning
//
//  Created by Codex on 2025/11/24.
//

import SwiftUI

struct NewsDetailView: View {
    let article: NewsArticle
    @State private var content: NewsArticleContent?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Image
                if let imageURL = article.imageURL {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 250)
                                .clipped()
                        case .failure:
                            EmptyView()
                        case .empty:
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 250)
                        @unknown default:
                            EmptyView()
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    Text(content?.title ?? article.title)
                        .font(.system(.title, design: .serif))
                        .fontWeight(.bold)
                        .multilineTextAlignment(.leading)

                    // Metadata
                    HStack {
                        if let provider = content?.providerName ?? article.providerName {
                            Label(provider, systemImage: "newspaper")
                        }
                        Spacer()
                        let date = content?.datePublished ?? article.relativePublishedText
                        if !date.isEmpty {
                            Text(date)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)

                    Divider()

                    // Content
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else if let error = errorMessage {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundColor(.orange)
                            Text(error)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                            Button("重試") {
                                loadContent()
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                    } else if let textContent = content?.content {
                        Text(textContent)
                            .font(.body)
                            .lineSpacing(4)
                            .textSelection(.enabled)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
        .edgesIgnoringSafeArea(.top)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            loadContent()
        }
    }

    private func loadContent() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                content = try await NewsService.shared.fetchArticleContent(url: article.url)
                isLoading = false
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
