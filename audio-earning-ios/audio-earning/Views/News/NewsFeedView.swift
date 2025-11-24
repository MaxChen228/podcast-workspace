//
//  NewsFeedView.swift
//  audio-earning
//
//  Created by Codex on 2025/11/09.
//

import SwiftUI

struct NewsFeedView: View {
    @Environment(\.dependencies) private var dependencies
    @StateObject var viewModel: NewsFeedViewModel

    private var marketBinding: Binding<String> {
        Binding(
            get: { viewModel.selectedMarket },
            set: { viewModel.updateMarket($0) }
        )
    }

    var body: some View {
        List {
            filterSection

            Section {
                ForEach(viewModel.articles) { article in
                    NavigationLink {
                        NewsDetailView(article: article)
                            .onAppear {
                                viewModel.recordAction(.open, for: article)
                            }
                    } label: {
                        NewsArticleRow(article: article)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay(overlayView)
        .navigationTitle(viewModel.isShowingSearchResults ? "搜尋結果" : "新聞")
        .toolbar { toolbarContent }
        .searchable(text: $viewModel.searchText, prompt: "搜尋最新新聞")
        .onSubmit(of: .search) {
            viewModel.submitSearch()
        }
        .onChange(of: viewModel.searchText) { _, newValue in
            if newValue.isEmpty {
                viewModel.clearSearch()
            }
        }
        .refreshable {
            viewModel.refresh()
        }
        .task {
            viewModel.loadIfNeeded()
        }
    }

    private var filterSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(NewsCategoryFilter.allCases) { filter in
                        Button {
                            viewModel.select(filter: filter)
                        } label: {
                            Text(filter.title)
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(filter == viewModel.selectedFilter ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            VStack(alignment: .leading, spacing: 4) {
                Text("推薦分類")
                if let updated = viewModel.lastUpdatedAt {
                    Text("更新於 \(updated, style: .time)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var overlayView: some View {
        if viewModel.articles.isEmpty {
            VStack(spacing: 12) {
                if viewModel.isLoading {
                    ProgressView("載入中...")
                } else if let error = viewModel.errorMessage {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    Button("再試一次") {
                        viewModel.refresh()
                    }
                } else {
                    Image(systemName: "newspaper")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("暫無內容")
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Picker("市場", selection: marketBinding) {
                    ForEach(viewModel.marketOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
            } label: {
                Label("市場", systemImage: "globe")
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                viewModel.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(viewModel.isLoading)
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            NavigationLink {
                PodcastJobView(viewModel: dependencies.makePodcastJobViewModel())
            } label: {
                Image(systemName: "plus.circle")
            }
        }
    }
}

struct NewsArticleRow: View {
    let article: NewsArticle

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let imageURL = article.imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        placeholder
                    case .empty:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
                .frame(width: 90, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(article.title)
                    .font(.headline)
                    .foregroundColor(.primary)

                if let summary = article.summary {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }

                HStack(spacing: 8) {
                    if let provider = article.providerName {
                        Text(provider)
                    }
                    if !article.relativePublishedText.isEmpty {
                        Text(article.relativePublishedText)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.gray.opacity(0.2))
            .overlay(Image(systemName: "photo").foregroundColor(.gray))
    }
}

#Preview {
    NavigationStack {
        NewsFeedView(viewModel: NewsFeedViewModel())
    }
}
