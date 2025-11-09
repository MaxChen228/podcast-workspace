//
//  ChapterPlayerView.swift
//  audio-earning
//
//  Created by Codex on 2025/10/27.
//

import SwiftUI

@MainActor
struct ChapterPlayerView: View {
    let book: Book
    let chapter: ChapterSummaryModel

    @StateObject private var viewModel: ChapterPlayerViewModel
    @State private var isShowingReloadConfirmation = false

    init(book: Book, chapter: ChapterSummaryModel) {
        self.init(book: book, chapter: chapter, viewModel: ChapterPlayerViewModel(book: book, chapter: chapter))
    }

    init(book: Book, chapter: ChapterSummaryModel, viewModel: ChapterPlayerViewModel) {
        self.book = book
        self.chapter = chapter
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        content
            .navigationTitle(viewModel.resolvedTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
            .task {
                viewModel.loadIfNeeded()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingReloadConfirmation = true
                    } label: {
                        Label("重新下載", systemImage: "arrow.clockwise.circle")
                    }
                    .disabled(viewModel.isWorking)
                    .accessibilityIdentifier("chapterReloadButton")
                }
            }
            .confirmationDialog("要重新下載本章資料嗎？", isPresented: $isShowingReloadConfirmation, titleVisibility: .visible) {
                Button("重新下載", role: .destructive) {
                    viewModel.reloadChapter()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("這會刪除本章儲存的音訊、字幕與收聽進度，並立即嘗試重新從伺服器抓取。")
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            VStack(spacing: 16) {
                ProgressView()
                Text("Loading chapter...")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loading(let cached, let message):
            VStack(spacing: 20) {
                ProgressView()
                Text(message)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)

                if cached != nil {
                    Text("已有本地快取，可立即播放。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Button {
                        viewModel.useCachedChapter()
                    } label: {
                        Label("立即使用本地資料", systemImage: "play.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Text("尚未有本地資料，需等待連線完成。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()

        case .noAudio:
            VStack(spacing: 12) {
                Image(systemName: "waveform.slash")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("Audio unavailable")
                    .font(.headline)
                Text("This chapter has not generated audio yet. Please try again later.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .error(let message):
            VStack(spacing: 12) {
                Image(systemName: "xmark.octagon")
                    .font(.largeTitle)
                    .foregroundColor(.red)
                Text("Failed to load")
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Button("Try Again") {
                    viewModel.retry()
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()

        case .ready(let payload, let offlineNotice):
            ZStack(alignment: .top) {
                AudioPlayerView(
                    audioURL: payload.localAudioURL,
                    subtitleContent: payload.subtitleContent,
                    bookID: book.id,
                    chapterID: chapter.id,
                    chapterTitle: chapter.title,
                    initialMetrics: payload.metrics ?? chapter.metrics,
                    initialProgress: payload.progress ?? chapter.progress
                )

                if let notice = offlineNotice {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.slash")
                        Text(notice)
                    }
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.top, 12)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ChapterPlayerView(
            book: Book(id: "demo", title: "Demo Book", coverURL: nil),
            chapter: ChapterSummaryModel(
                id: "chapter0",
                title: "chapter0",
                audioAvailable: true,
                subtitlesAvailable: true,
                metrics: nil,
                progress: nil,
                cacheStatus: .empty,
                downloadState: .idle
            )
        )
    }
}
