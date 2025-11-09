//
//  HighlightedWordsListView.swift
//  audio-earning
//
//  Created by Claude on 2025/10/27.
//

import SwiftUI

/// Highlighted words list view.
struct HighlightedWordsListView: View {
    @ObservedObject var viewModel: AudioPlayerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if viewModel.highlightedWordsSorted.isEmpty {
                    Label("No highlighted words yet", systemImage: "bookmark")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(viewModel.highlightedWordsSorted, id: \.self) { word in
                        HStack {
                            Text(word.capitalized)
                            Spacer()
                            Button(role: .destructive) {
                                viewModel.removeHighlight(word)
                            } label: {
                                Text("Unhighlight")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
            .navigationTitle("Highlighted Words")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if !viewModel.highlightedWordsSorted.isEmpty {
                        Button("Clear All", role: .destructive) {
                            viewModel.clearAllHighlightedWords()
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    HighlightedWordsListView(viewModel: AudioPlayerViewModel())
}
