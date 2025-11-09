//
//  CatalogBookDetailView.swift
//  audio-earning
//
//  Created by Codex on 2025/11/09.
//

import SwiftUI

@MainActor
struct CatalogBookDetailView: View {
    @EnvironmentObject private var tabRouter: TabRouter
    @StateObject private var viewModel: CatalogBookDetailViewModel

    init(viewModel: CatalogBookDetailViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 16) {
                        BookCoverThumbnail(url: viewModel.book.coverURL)
                            .frame(width: 80, height: 120)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(viewModel.book.title.isEmpty ? viewModel.book.id : viewModel.book.title)
                                .font(.title3)
                                .bold()
                            Text(viewModel.book.id)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("要聆聽章節需先加入書庫，播放時會從後端串流音訊。")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                    }

                    if viewModel.isInLibrary {
                        Button {
                            tabRouter.selection = .library
                        } label: {
                            Label("前往書庫播放", systemImage: "books.vertical")
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button {
                            viewModel.addToLibrary()
                        } label: {
                            if viewModel.isProcessing {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Label("加入書庫", systemImage: "plus.circle.fill")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isProcessing)
                    }
                }
                .padding(.vertical, 4)
            }

            Section(header: Text("章節預覽")) {
                if viewModel.isLoading && viewModel.chapters.isEmpty {
                    ProgressView("載入章節…")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else if let message = viewModel.errorMessage, viewModel.chapters.isEmpty {
                    VStack(spacing: 8) {
                        Text("無法取得章節列表")
                            .font(.headline)
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical)
                } else if viewModel.chapters.isEmpty {
                    Text("此書暫無章節資料。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.chapters) { chapter in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(chapter.title.isEmpty ? chapter.id : chapter.title)
                                .font(.body)
                            HStack(spacing: 12) {
                                Label(chapter.audioAvailable ? "有音訊" : "無音訊", systemImage: "waveform")
                                    .font(.caption)
                                    .foregroundStyle(chapter.audioAvailable ? .green : .secondary)
                                Label(chapter.subtitlesAvailable ? "有字幕" : "無字幕", systemImage: "text.bubble")
                                    .font(.caption)
                                    .foregroundStyle(chapter.subtitlesAvailable ? .blue : .secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("書籍資訊")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadIfNeeded()
        }
    }
}

#Preview {
    let book = BookResponse(id: "demo", title: "Demo Book", coverURL: nil)
    NavigationStack {
        CatalogBookDetailView(viewModel: CatalogBookDetailViewModel(book: book))
            .environmentObject(TabRouter())
    }
}
