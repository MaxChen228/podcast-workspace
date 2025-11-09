//
//  ChapterListView.swift
//  audio-earning
//
//  Created by Codex on 2025/10/27.
//

import SwiftUI

@MainActor
struct ChapterListView: View {
    let book: Book
    @StateObject private var viewModel: ChapterListViewModel

    init(book: Book) {
        self.init(book: book, viewModel: ChapterListViewModel(book: book))
    }

    init(book: Book, viewModel: ChapterListViewModel) {
        self.book = book
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.chapters.isEmpty {
                ProgressView("Loading chapters...")
                    .padding()
            } else if let message = viewModel.errorMessage, viewModel.chapters.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("Unable to load chapters")
                        .font(.headline)
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("Reload") {
                        viewModel.loadChapters(force: true)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            } else {
                chapterList
            }
        }
        .navigationTitle(book.title.isEmpty ? book.id : book.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                refreshToolbarButton
            }
            ToolbarItem(placement: .topBarTrailing) {
                downloadToolbarButton
            }
        }
        .task {
            viewModel.loadChapters()
        }
        .onAppear {
            viewModel.refreshProgress()
        }
        .onReceive(NotificationCenter.default.publisher(for: .listeningProgressDidChange)) { notification in
            guard
                let userInfo = notification.userInfo,
                let bookID = userInfo["bookID"] as? String,
                bookID == book.id
            else { return }
            viewModel.refreshProgress()
        }
        .alert(item: $viewModel.bulkDownloadSummary) { summary in
            Alert(
                title: Text("批次下載完成"),
                message: Text(summary.message),
                dismissButton: .default(Text("知道了"))
            )
        }
        .alert(item: $viewModel.bulkDownloadFailure) { failure in
            Alert(
                title: Text("下載失敗"),
                message: Text(failure.message),
                dismissButton: .default(Text("好"), action: {
                    viewModel.bulkDownloadFailure = nil
                })
            )
        }
    }
}

private struct ChapterRow: View {
    let chapter: ChapterSummaryModel
    let onDownload: () -> Void
    let onCancel: () -> Void
    let onClearError: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(chapter.displayTitle)
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                Spacer()
                if !chapter.audioAvailable {
                    Text("Pending")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                DownloadControl(
                    state: chapter.downloadState,
                    onDownload: onDownload,
                    onCancel: onCancel,
                    onClearError: onClearError
                )
            }

            ChapterStatusStrip(chapter: chapter)

            ChapterProgressStrip(progress: chapter.progress)
        }
        .padding(.vertical, 10)
    }
}

private extension ChapterListView {
    @ViewBuilder
    var chapterList: some View {
        List {
            cacheBannerRow
            bulkDownloadStatusRow

            ForEach(viewModel.chapters) { chapter in
                NavigationLink(
                    destination: ChapterPlayerView(book: book, chapter: chapter)
                ) {
                    ChapterRow(
                        chapter: chapter,
                        onDownload: { viewModel.downloadChapter(chapterID: chapter.id) },
                        onCancel: { viewModel.cancelDownload(chapterID: chapter.id) },
                        onClearError: { viewModel.clearDownloadError(chapterID: chapter.id) }
                    )
                }
                .disabled(!chapter.audioAvailable)
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            viewModel.loadChapters(force: true)
        }
    }

    @ViewBuilder
    var cacheBannerRow: some View {
        if let lastSynced = viewModel.lastSyncedAt {
            CacheStatusBanner(
                lastSyncedAt: lastSynced,
                isOffline: viewModel.isOffline,
                showingCachedSnapshot: viewModel.showingCachedSnapshot,
                showingStaleCache: viewModel.showingStaleCache,
                isLoading: viewModel.isLoading
            )
            .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
            .listRowBackground(Color(.secondarySystemBackground))
            .listRowSeparator(.hidden)
        }
    }

    @ViewBuilder
    var bulkDownloadStatusRow: some View {
        if viewModel.isBulkDownloading, let progress = viewModel.bulkDownloadProgress {
            BulkDownloadStatusRow(progress: progress)
                .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
                .listRowBackground(Color(.secondarySystemBackground))
                .listRowSeparator(.hidden)
        }
    }

    var refreshToolbarButton: some View {
        Button {
            viewModel.loadChapters(force: true)
        } label: {
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
            } else {
                Image(systemName: "arrow.clockwise")
            }
        }
        .accessibilityLabel("重新整理章節列表")
    }

    var downloadToolbarButton: some View {
        Group {
            if viewModel.isBulkDownloading {
                Button {
                    viewModel.cancelBulkDownload()
                } label: {
                    if let progress = viewModel.bulkDownloadProgress {
                        ZStack {
                            Circle()
                                .stroke(Color.accentColor.opacity(0.25), lineWidth: 2)
                                .frame(width: 26, height: 26)
                            ProgressView(value: progress.fraction)
                                .progressViewStyle(.circular)
                                .frame(width: 24, height: 24)
                        }
                    } else {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .frame(width: 24, height: 24)
                    }
                }
                .accessibilityLabel("停止下載全部章節")
            } else if viewModel.chapters.contains(where: { chapter in
                chapter.audioAvailable && chapter.subtitlesAvailable && !(chapter.progress?.isCompleted ?? false)
            }) {
                Button {
                    viewModel.startBulkDownload()
                } label: {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 20, weight: .semibold))
                }
                .accessibilityIdentifier("downloadAllChaptersButton")
            }
        }
    }
}

private struct BulkDownloadStatusRow: View {
    let progress: BulkDownloadProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(Color.accentColor)
                Text("批次下載中")
                    .font(.subheadline.bold())
                Spacer()
                Text(progress.percentText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: progress.fraction)
                .progressViewStyle(.linear)

            Text(summaryLine)
                .font(.subheadline)
                .foregroundStyle(.primary)

            if let current = progress.currentTitle, !current.isEmpty {
                Text("目前章節：\(current)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var summaryLine: String {
        "共 \(progress.totalCount) 集 · 已完成 \(progress.completedCount) 集 · 剩餘時間：\(etaDescription)"
    }

    private var etaDescription: String {
        if progress.remainingCount == 0 {
            return "已完成"
        }
        guard let seconds = progress.estimatedRemainingSeconds else {
            return "計算中"
        }
        if seconds < 1 {
            return "即將完成"
        }
        return formattedDuration(seconds)
    }

    private func formattedDuration(_ seconds: TimeInterval) -> String {
        if seconds >= 3600 {
            let hours = Int(seconds / 3600)
            let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
            if minutes > 0 {
                return "約 \(hours) 小時 \(minutes) 分鐘"
            }
            return "約 \(hours) 小時"
        }

        if seconds >= 120 {
            let minutes = Int(round(seconds / 60))
            return "約 \(minutes) 分鐘"
        }

        if seconds >= 60 {
            return "約 1 分鐘"
        }

        let clampedSeconds = max(Int(seconds.rounded()), 1)
        return "約 \(clampedSeconds) 秒"
    }
}

private struct CacheStatusBanner: View {
    let lastSyncedAt: Date
    let isOffline: Bool
    let showingCachedSnapshot: Bool
    let showingStaleCache: Bool
    let isLoading: Bool

    private let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .foregroundColor(iconColor)
                Text(titleText)
                    .font(.caption)
                    .foregroundColor(iconColor)
                Spacer()
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.7)
                }
            }

            Text("最後同步：" + relativeFormatter.localizedString(for: lastSyncedAt, relativeTo: Date()))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var iconName: String {
        if isOffline { return "wifi.slash" }
        if showingStaleCache { return "exclamationmark.triangle" }
        if showingCachedSnapshot { return "clock" }
        return "checkmark.circle"
    }

    private var iconColor: Color {
        if isOffline { return .orange }
        if showingStaleCache { return .orange }
        if showingCachedSnapshot { return .accentColor }
        return .green
    }

    private var titleText: String {
        if isOffline {
            return "離線狀態，顯示快取"
        }
        if showingStaleCache {
            return "快取可能不是最新"
        }
        if showingCachedSnapshot {
            return "顯示快取內容"
        }
        return "資料為最新版本"
    }
}

private struct ChapterStatusStrip: View {
    let chapter: ChapterSummaryModel

    var body: some View {
        HStack(spacing: 20) {
            AvailabilityBadge(
                systemName: "waveform",
                fillSuffix: "circle",
                label: "Audio",
                active: chapter.audioAvailable,
                cached: chapter.cacheStatus.audioCached,
                activeColor: .accentColor
            )

            AvailabilityBadge(
                systemName: "captions.bubble",
                fillSuffix: "",
                label: "Subs",
                active: chapter.subtitlesAvailable,
                cached: chapter.cacheStatus.subtitlesCached,
                activeColor: .green
            )

            Spacer()
        }
    }
}

private struct AvailabilityBadge: View {
    let systemName: String
    let fillSuffix: String
    let label: String
    let active: Bool
    let cached: Bool
    let activeColor: Color

    var body: some View {
        HStack(spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                let activeSymbol = fillSuffix.isEmpty ? systemName : "\(systemName).\(fillSuffix).fill"
                let inactiveSymbol = fillSuffix.isEmpty ? systemName : "\(systemName).\(fillSuffix)"

                Image(systemName: active ? activeSymbol : inactiveSymbol)
                    .symbolRenderingMode(.monochrome)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(active ? activeColor : Color.secondary.opacity(0.35))
                if cached {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(activeColor)
                        .background(
                            Circle()
                                .fill(Color(.systemBackground))
                                .frame(width: 12, height: 12)
                        )
                        .offset(x: 2, y: 2)
                }
            }

            Text(label)
                .font(.caption)
                .foregroundStyle(active ? .primary : .secondary)
        }
        .animation(.easeInOut(duration: 0.2), value: active)
        .animation(.easeInOut(duration: 0.2), value: cached)
    }
}

private struct ChapterProgressStrip: View {
    let progress: ChapterProgress?

    @ViewBuilder
    var body: some View {
        if let progress, shouldDisplay(progress) {
            progressContent(for: progress)
        }
    }

    private func progressPercentage(_ fraction: Double) -> String {
        let clamped = min(max(fraction, 0), 1)
        let percent = Int(round(clamped * 100))
        return "\(percent)%"
    }

    private func clampedFraction(_ fraction: Double) -> Double {
        min(max(fraction, 0), 1)
    }

    private func shouldDisplay(_ progress: ChapterProgress) -> Bool {
        progress.isCompleted || clampedFraction(progress.fraction) > 0.0001
    }

    @ViewBuilder
    private func progressContent(for progress: ChapterProgress) -> some View {
        let fraction = clampedFraction(progress.fraction)
        let isCompleted = progress.isCompleted || fraction >= 0.999
        let labelText = isCompleted ? "已完成" : progressPercentage(fraction)
        let fillColor: Color = isCompleted ? .green : .accentColor

        HStack(spacing: 10) {
            CapsuleProgressBar(fraction: fraction, fillColor: fillColor)
                .frame(height: 8)
            Text(labelText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct CapsuleProgressBar: View {
    let fraction: Double
    let fillColor: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.tertiarySystemFill))
                Capsule()
                    .fill(fillColor)
                    .frame(width: max(geometry.size.width * fraction, 6))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: fraction)
    }
}

private struct DownloadControl: View {
    let state: ChapterDownloadState
    let onDownload: () -> Void
    let onCancel: () -> Void
    let onClearError: () -> Void

    var body: some View {
        downloadContent
            .buttonStyle(.borderless)
            .animation(.easeInOut(duration: 0.2), value: state)
    }

    @ViewBuilder
    private var downloadContent: some View {
        switch state {
        case .idle:
            Button(action: onDownload) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 18, weight: .semibold))
            }
            .accessibilityLabel("下載章節")
        case .enqueued:
            Button(action: onCancel) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.accentColor)
            }
            .accessibilityLabel("排隊中，點擊取消下載")
        case .downloading(let progress):
            Button(action: onCancel) {
                if let value = progress {
                    ProgressView(value: min(max(value, 0), 1))
                        .progressViewStyle(.circular)
                        .tint(.accentColor)
                } else {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.accentColor)
                }
            }
            .accessibilityLabel("下載中，點擊取消")
        case .downloaded:
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .accessibilityLabel("已下載")
        case .failed:
            Button {
                onClearError()
                onDownload()
            } label: {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.orange)
            }
            .accessibilityLabel("下載失敗，點擊重試")
        }
    }
}

#Preview {
    NavigationStack {
        ChapterListView(
            book: Book(id: "demo", title: "Demo Book", coverURL: nil)
        )
    }
}
