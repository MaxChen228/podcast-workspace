//
//  BookCatalogView.swift
//  audio-earning
//
//  Created by Codex on 2025/11/09.
//

import SwiftUI

@MainActor
struct BookCatalogView: View {
    @Environment(\.dependencies) private var dependencies
    @EnvironmentObject private var tabRouter: TabRouter
    @StateObject private var viewModel: BookCatalogViewModel

    init(viewModel: BookCatalogViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        content
        .navigationTitle("書城")
        .onAppear {
            viewModel.loadBooks()
        }
    }
}

@MainActor
private extension BookCatalogView {
    @ViewBuilder
    var content: some View {
        if viewModel.isLoading && viewModel.books.isEmpty {
            ProgressView("載入書城…")
                .padding()
        } else if let message = viewModel.errorMessage, viewModel.books.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.largeTitle)
                Text("無法載入書城")
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button {
                    viewModel.loadBooks(force: true)
                } label: {
                    Label("重新整理", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        } else {
            List(viewModel.books) { book in
                NavigationLink {
                    CatalogBookDetailView(
                        viewModel: CatalogBookDetailViewModel(
                            book: book,
                            service: dependencies.apiService,
                            libraryManager: dependencies.bookLibraryManager
                        )
                    )
                    } label: {
                        CatalogBookRow(
                            book: book,
                            isInLibrary: viewModel.isBookInLibrary(book.id),
                            isProcessing: viewModel.isProcessingBookID == book.id,
                            addAction: { viewModel.addToLibrary(book) },
                            goToLibraryAction: { tabRouter.selection = .library }
                        )
                    }
                }
            .listStyle(.insetGrouped)
            .refreshable {
                await Task {
                    viewModel.loadBooks(force: true)
                }.value
            }
        }
    }
}

#Preview {
    NavigationStack {
        BookCatalogView(viewModel: BookCatalogViewModel())
    }
    .environmentObject(TabRouter())
}

private struct CatalogBookRow: View {
    let book: BookResponse
    let isInLibrary: Bool
    let isProcessing: Bool
    let addAction: () -> Void
    let goToLibraryAction: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            BookCoverThumbnail(url: book.coverURL)
                .frame(width: 54, height: 80)

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title.isEmpty ? book.id : book.title)
                    .font(.headline)
                Text(book.id)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isInLibrary {
                Button {
                    goToLibraryAction()
                } label: {
                    Label("前往書庫", systemImage: "arrowshape.turn.up.right.circle")
                }
                .buttonStyle(.bordered)
            } else {
                Button {
                    addAction()
                } label: {
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Text("加入書庫")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isProcessing)
            }
        }
        .padding(.vertical, 6)
    }
}
