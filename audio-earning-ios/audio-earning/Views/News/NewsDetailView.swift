//
//  NewsDetailView.swift
//  audio-earning
//
//  Created by Codex on 2025/11/24.
//

import SwiftUI
import WebKit

struct NewsDetailView: View {
    let article: NewsArticle
    @State private var content: NewsArticleContent?
    @State private var isLoading = true
    @State private var errorMessage: String?

    @State private var webViewHeight: CGFloat = .zero

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
                    } else if let htmlContent = content?.content {
                        HTMLTextView(htmlContent: htmlContent, dynamicHeight: $webViewHeight)
                            .frame(height: webViewHeight)
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

// Helper to render HTML content safely
struct HTMLTextView: UIViewRepresentable {
    let htmlContent: String
    @Binding var dynamicHeight: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: HTMLTextView

        init(_ parent: HTMLTextView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("document.body.scrollHeight") { (result, error) in
                if let height = result as? CGFloat {
                    DispatchQueue.main.async {
                        self.parent.dynamicHeight = height
                    }
                }
            }
        }
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        let css = """
        <style>
            body {
                font-family: -apple-system, system-ui, sans-serif;
                font-size: 110%;
                line-height: 1.6;
                color: #333;
                padding: 0;
                margin: 0;
            }
            @media (prefers-color-scheme: dark) {
                body {
                    color: #eee;
                }
            }
            img {
                max-width: 100%;
                height: auto;
                border-radius: 8px;
                margin: 10px 0;
            }
            p {
                margin-bottom: 1.2em;
            }
            h1, h2, h3, h4, h5, h6 {
                margin-top: 1.5em;
                margin-bottom: 0.5em;
            }
        </style>
        """
        
        let fullHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            \(css)
        </head>
        <body>
            \(htmlContent)
        </body>
        </html>
        """
        
        uiView.loadHTMLString(fullHTML, baseURL: nil)
    }
}
