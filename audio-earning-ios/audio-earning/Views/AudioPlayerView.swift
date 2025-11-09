//
//  AudioPlayerView.swift
//  audio-earning
//
//  Created by Claude on 2025/10/27.
//

import SwiftUI

/// Main audio player view integrating waveform, subtitles, and playback controls.
@MainActor
struct AudioPlayerView: View {
    @StateObject private var viewModel: AudioPlayerViewModel

    let audioURL: URL
    let subtitleContent: String?
    let chapterTitle: String
    init(
        audioURL: URL,
        subtitleContent: String?,
        bookID: String,
        chapterID: String,
        chapterTitle: String,
        initialMetrics: ChapterPlaybackMetrics? = nil,
        initialProgress: ChapterProgress? = nil
    ) {
        self.init(
            audioURL: audioURL,
            subtitleContent: subtitleContent,
            chapterTitle: chapterTitle,
            viewModel: AudioPlayerViewModel(
                bookID: bookID,
                chapterID: chapterID,
                initialMetrics: initialMetrics,
                initialProgress: initialProgress
            )
        )
    }

    init(
        audioURL: URL,
        subtitleContent: String?,
        chapterTitle: String,
        viewModel: AudioPlayerViewModel
    ) {
        self.audioURL = audioURL
        self.subtitleContent = subtitleContent
        self.chapterTitle = chapterTitle
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 24) {
                Text(chapterTitle)
                    .font(.title2.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                SubtitleContainerView(viewModel: viewModel)
                    .frame(minHeight: 100)
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(.top, 24)
            .padding(.horizontal, 24)

            Spacer(minLength: 16)

            VStack(spacing: 16) {
                // Playback controls
                PlayerControlsView(viewModel: viewModel)

                // Status indicator
                stateIndicator
                    .padding(.bottom, 12)
            }
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemBackground))
        .onAppear {
            viewModel.loadAudio(audioURL: audioURL, subtitleContent: subtitleContent)
        }
        .sheet(item: $viewModel.sentenceDetail, onDismiss: {
            viewModel.dismissSentenceDetail()
        }) { _ in
            SentenceDetailView(viewModel: viewModel)
                .presentationDetents([.medium, .large])
        }
        .onDisappear {
            viewModel.persistListeningPosition()
        }
    }

    @ViewBuilder
    private var stateIndicator: some View {
        switch viewModel.playerState {
        case .loading:
            HStack {
                ProgressView()
                Text("Loading...")
                    .foregroundColor(.secondary)
            }
        case .error(let message):
            Text("Error: \(message)")
                .foregroundColor(.red)
                .font(.caption)
        default:
            EmptyView()
        }
    }
}

/// Demo preview view.
struct AudioPlayerDemoView: View {
    var body: some View {
        if let audioURL = Bundle.main.url(forResource: "sample_audio", withExtension: "wav"),
           let subtitleURL = Bundle.main.url(forResource: "sample_subtitle", withExtension: "srt") {
            let subtitleContent = try? String(contentsOf: subtitleURL, encoding: .utf8)
            AudioPlayerView(
                audioURL: audioURL,
                subtitleContent: subtitleContent,
                bookID: "demo-book",
                chapterID: "chapter-1",
                chapterTitle: "Sample Chapter"
            )
        } else {
            VStack {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)
                Text("Sample assets not found")
                    .font(.headline)
                    .padding()
                Text("Please add the sample audio and subtitle files to Copy Bundle Resources.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding()
        }
    }
}

#Preview {
    AudioPlayerDemoView()
}
