import SwiftUI

struct LexiconListView: View {
    @ObservedObject var store: SavedLexiconStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if store.entries.isEmpty {
                        emptyState
                    } else {
                        ForEach(store.entries) { entry in
                            NavigationLink {
                                LexiconDetailView(entry: entry, store: store)
                            } label: {
                                LexiconListCard(entry: entry)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("字詞庫")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") { dismiss() }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark.slash")
                .font(.system(size: 36, weight: .semibold))
                .foregroundColor(.accentColor)
                .padding()
                .background(
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                )
            Text("尚未收藏任何字詞")
                .font(.headline)
            Text("在 AI 解釋中點選「存入字詞庫」即可快速收藏")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.accentColor.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 14, y: 8)
    }
}

private struct LexiconListCard: View {
    let entry: SavedLexiconEntry

    private var subtitleText: String {
        let trimmed = entry.chineseMeaning?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            return trimmed
        }
        return entry.subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                Text(subtitleText)
                    .font(.subheadline)
                    .foregroundStyle(Color.primary.opacity(0.7))
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.caption.weight(.semibold))
                Text(entry.createdAt, format: .dateTime.year().month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.accentColor.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 12, y: 6)
    }
}

private struct LexiconDetailView: View {
    let entry: SavedLexiconEntry
    @ObservedObject var store: SavedLexiconStore
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingDeleteAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                overviewSection
                keyPointsSection
                vocabularySection
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(entry.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    isShowingDeleteAlert = true
                } label: {
                    Label("刪除", systemImage: "trash")
                }
                .accessibilityIdentifier("lexiconDeleteButton")
            }
        }
        .alert("要刪除此收藏嗎？", isPresented: $isShowingDeleteAlert) {
            Button("刪除", role: .destructive) {
                deleteEntry()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("刪除後無法復原。")
        }
    }

    private var header: some View {
        let subtitleText: String = {
            let trimmed = entry.chineseMeaning?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let trimmed, !trimmed.isEmpty {
                return trimmed
            }
            return entry.subtitle
        }()

        return VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text("中文意思")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(subtitleText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text("原句：\n\(entry.sourceSentence)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("說明")
                .font(.headline)
            Text(entry.overview)
                .font(.body)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var keyPointsSection: some View {
        Group {
            if entry.keyPoints.isEmpty {
                EmptyView()
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("重點整理")
                        .font(.headline)
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(entry.keyPoints, id: \.self) { point in
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                Text(point)
                            }
                            .font(.body)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardBackground)
            }
        }
    }

    private var vocabularySection: some View {
        Group {
            if entry.vocabulary.isEmpty {
                EmptyView()
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("詞彙說明")
                        .font(.headline)
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(entry.vocabulary.enumerated()), id: \.offset) { _, vocab in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(vocab.word)
                                    .font(.body.weight(.semibold))
                                Text(vocab.meaning)
                                    .font(.body)
                                if let note = vocab.note, !note.isEmpty {
                                    Text(note)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(cardBackground)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardBackground)
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 10, y: 5)
    }
}

private extension LexiconDetailView {
    func deleteEntry() {
        store.remove(entry.id)
        dismiss()
    }
}
