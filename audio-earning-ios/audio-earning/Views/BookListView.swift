//
//  BookListView.swift
//  audio-earning
//
//  Created by Codex on 2025/10/27.
//

import SwiftUI

@MainActor
struct BookListView: View {
    @StateObject private var viewModel: BookListViewModel
    @State private var isShowingCacheDialog = false
    @State private var isClearingCache = false
    @State private var isShowingCacheResult = false
    @State private var cacheResultTitle = ""
    @State private var cacheResultMessage = ""
    @State private var isShowingBackendSheet = false

    init() {
        self.init(viewModel: BookListViewModel())
    }

    init(viewModel: BookListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.books.isEmpty {
                ProgressView("Loading books...")
                    .padding()
            } else if let message = viewModel.errorMessage, viewModel.books.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.largeTitle)
                    Text("Failed to load")
                        .font(.headline)
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("Reload") {
                        viewModel.loadBooks(force: true)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                List(viewModel.books) { book in
                    NavigationLink(destination: ChapterListView(book: book)) {
                        HStack(alignment: .center, spacing: 14) {
                            BookCoverThumbnail(url: book.coverURL)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(book.title.isEmpty ? book.id : book.title)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(book.id)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 6)
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
        .navigationTitle("Choose Book")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingCacheDialog = true
                } label: {
                    Label("Clear Cache", systemImage: "trash")
                }
                .disabled(isClearingCache)
                .accessibilityIdentifier("clearCacheButton")
            }
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    isShowingBackendSheet = true
                } label: {
                    Label("Server Settings", systemImage: "gearshape")
                }
                .accessibilityIdentifier("serverSettingsButton")
            }
        }
        .confirmationDialog("Clear cached content?", isPresented: $isShowingCacheDialog, titleVisibility: .visible) {
            Button("Clear Cache", role: .destructive) {
                isShowingCacheDialog = false
                isClearingCache = true
                Task {
                    await clearCache()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("這會刪除已下載的音訊、字幕與章節快取，但保留聆聽進度與收藏。")
        }
        .alert(cacheResultTitle, isPresented: $isShowingCacheResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(cacheResultMessage)
        }
        .overlay {
            if isClearingCache {
                ProgressView("Clearing cache…")
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .onAppear {
            viewModel.loadBooks()
        }
        .sheet(isPresented: $isShowingBackendSheet) {
            BackendConfigurationSheet(isPresented: $isShowingBackendSheet, viewModel: viewModel)
        }
    }

    @MainActor
    private func handleCacheClearSuccess(_ summary: CacheClearSummary) {
        isClearingCache = false
        cacheResultTitle = "Cache Cleared"
        cacheResultMessage = cacheResultDescription(for: summary)
        isShowingCacheResult = true
        viewModel.loadBooks(force: true)
    }

    @MainActor
    private func handleCacheClearFailure(_ error: Error) {
        isClearingCache = false
        cacheResultTitle = "Unable to Clear Cache"
        cacheResultMessage = error.localizedDescription
        isShowingCacheResult = true
    }

    private func clearCache() async {
        do {
            let summary = try await viewModel.clearCaches()
            handleCacheClearSuccess(summary)
        } catch {
            handleCacheClearFailure(error)
        }
    }

    private func cacheResultDescription(for summary: CacheClearSummary) -> String {
        if summary.removedMediaFiles > 0 {
            return "已移除 \(summary.removedMediaFiles) 個媒體快取檔案，章節資料已重整。聆聽進度已保留。"
        } else {
            return "未找到可刪除的媒體快取，章節資料已重整。聆聽進度已保留。"
        }
    }
}

#Preview {
    NavigationStack {
        BookListView()
    }
}

private struct BackendConfigurationSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject var viewModel: BookListViewModel

    @State private var testStatuses: [UUID: TestStatus] = [:]
    @State private var editorName: String = ""
    @State private var editorURL: String = ""
    @State private var editorErrorMessage: String?
    @State private var isPresentingEditor = false
    @State private var editingEndpoint: BackendEndpoint?
    @State private var pendingDeletion: BackendEndpoint?
    @FocusState private var editorFocusedField: Field?

    var body: some View {
        NavigationStack {
            List {
                if viewModel.endpoints.isEmpty {
                    Section {
                        Label("尚未設定任何後端", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 4)
                    }
                } else {
                    Section {
                        ForEach(viewModel.endpoints) { endpoint in
                            EndpointRow(
                                endpoint: endpoint,
                                isSelected: endpoint.id == viewModel.selectedEndpointID,
                                status: testStatuses[endpoint.id] ?? .idle,
                                onSelect: { viewModel.selectEndpoint(endpoint) },
                                onTest: { runHealthCheck(for: endpoint) },
                                onEdit: { presentEditor(for: endpoint) },
                                onDelete: { pendingDeletion = endpoint },
                                canDelete: viewModel.canDeleteEndpoint(endpoint)
                            )
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("伺服器設定")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        presentEditor(for: nil)
                    } label: {
                        Label("新增後端", systemImage: "plus")
                    }
                    .accessibilityIdentifier("addBackendButton")
                }
            }
            .onChange(of: viewModel.endpoints) { oldValue, newValue in
                let ids = Set(newValue.map(\.id))
                testStatuses = testStatuses.filter { ids.contains($0.key) }
            }
        }
        .sheet(isPresented: $isPresentingEditor) {
            NavigationStack {
                Form {
                    Section {
                        TextField("顯示名稱（可留空）", text: $editorName)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .focused($editorFocusedField, equals: .name)

                        TextField("https://example.com", text: $editorURL)
                            .keyboardType(.URL)
                            .textContentType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .focused($editorFocusedField, equals: .url)

                        if let editorErrorMessage {
                            Text(editorErrorMessage)
                                .font(.footnote)
                                .foregroundColor(.red)
                        }
                    }
                }
                .navigationTitle(editingEndpoint == nil ? "新增後端" : "編輯後端")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") {
                            closeEditor()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(editingEndpoint == nil ? "新增" : "儲存") {
                            submitEditor()
                        }
                        .disabled(editorURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .onAppear {
                    DispatchQueue.main.async {
                        editorFocusedField = .url
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .alert("刪除後端？", isPresented: Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        )) {
            if let endpoint = pendingDeletion {
                Button("刪除", role: .destructive) {
                    deleteEndpoint(endpoint)
                }
            }
            Button("取消", role: .cancel) {
                pendingDeletion = nil
            }
        } message: {
            if let endpoint = pendingDeletion {
                Text("確定要刪除「\(endpoint.name)」連結嗎？")
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func presentEditor(for endpoint: BackendEndpoint?) {
        editingEndpoint = endpoint
        editorName = endpoint?.name ?? ""
        editorURL = endpoint?.url.absoluteString ?? ""
        editorErrorMessage = nil
        isPresentingEditor = true
    }

    private func closeEditor() {
        isPresentingEditor = false
        editorFocusedField = nil
    }

    private func submitEditor() {
        if let endpoint = editingEndpoint {
            editorErrorMessage = viewModel.updateEndpoint(endpoint, name: editorName, urlString: editorURL)
        } else {
            editorErrorMessage = viewModel.addEndpoint(name: editorName, urlString: editorURL)
        }

        if editorErrorMessage == nil {
            closeEditor()
        }
    }

    private func deleteEndpoint(_ endpoint: BackendEndpoint) {
        viewModel.deleteEndpoint(endpoint)
        testStatuses[endpoint.id] = nil
        pendingDeletion = nil
    }

    private func runHealthCheck(for endpoint: BackendEndpoint) {
        Task {
            await MainActor.run {
                testStatuses[endpoint.id] = .testing
            }

            let result = await viewModel.testEndpoint(endpoint)

            await MainActor.run {
                switch result {
                case .success:
                    testStatuses[endpoint.id] = .success(Date())
                case .failure(let error):
                    testStatuses[endpoint.id] = .failure(error.localizedDescription)
                }
            }
        }
    }

    private enum Field {
        case name
        case url
    }

    private enum TestStatus: Equatable {
        case idle
        case testing
        case success(Date)
        case failure(String)

        var labelText: String {
            switch self {
            case .idle:
                return "尚未測試"
            case .testing:
                return "測試中…"
            case .success:
                return "連線正常"
            case .failure:
                return "連線失敗"
            }
        }

        var icon: String {
            switch self {
            case .idle:
                return "waveform"
            case .testing:
                return "hourglass"
            case .success:
                return "checkmark.circle.fill"
            case .failure:
                return "exclamationmark.triangle.fill"
            }
        }

        var tint: Color {
            switch self {
            case .idle:
                return .secondary
            case .testing:
                return .secondary
            case .success:
                return .green
            case .failure:
                return .orange
            }
        }

        var buttonTitle: String {
            switch self {
            case .idle:
                return "測試"
            case .testing:
                return "測試中"
            case .success:
                return "重新測試"
            case .failure:
                return "重試"
            }
        }

        var buttonIcon: String {
            switch self {
            case .idle:
                return "bolt.horizontal.circle"
            case .testing:
                return "hourglass"
            case .success, .failure:
                return "arrow.clockwise"
            }
        }
    }

    private struct EndpointRow: View {
        let endpoint: BackendEndpoint
        let isSelected: Bool
        let status: TestStatus
        let onSelect: () -> Void
        let onTest: () -> Void
        let onEdit: () -> Void
        let onDelete: () -> Void
        let canDelete: Bool

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(endpoint.name.isEmpty ? "未命名" : endpoint.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(endpoint.url.absoluteString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    if isSelected {
                        Label("使用中", systemImage: "checkmark.circle.fill")
                            .labelStyle(.titleAndIcon)
                            .font(.caption.bold())
                            .foregroundStyle(Color.accentColor)
                    }
                }

                HStack(spacing: 12) {
                    Label(status.labelText, systemImage: status.icon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(status.tint)

                    Spacer()

                    Button(action: onTest) {
                        if status == .testing {
                            ProgressView()
                                .progressViewStyle(.circular)
                        } else {
                            Label(status.buttonTitle, systemImage: status.buttonIcon)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(status == .testing)

                    Button(action: onEdit) {
                        Image(systemName: "square.and.pencil")
                            .font(.body)
                    }
                    .buttonStyle(.borderless)

                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .font(.body)
                    }
                    .buttonStyle(.borderless)
                    .disabled(!canDelete)
                    .opacity(canDelete ? 1 : 0.4)
                }

                if case .failure(let message) = status {
                    Text(message)
                        .font(.caption2)
                        .foregroundColor(.red)
                } else if case .success(let date) = status {
                    Text("最後成功於 " + date.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(rowBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .onTapGesture {
                onSelect()
            }
        }

        private var rowBackground: some View {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(.secondarySystemBackground))
        }
    }
}

private struct BookCoverThumbnail: View {
    let url: URL?

    private static let placeholderGradient = LinearGradient(
        colors: [
            Color(red: 0.92, green: 0.88, blue: 0.95),
            Color(red: 0.82, green: 0.86, blue: 0.96)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        ZStack {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        placeholder
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(.circular)
                            )
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholderIcon
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholderIcon
            }
        }
        .frame(width: 64, height: 92)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.4), lineWidth: 0.5)
        )
        .shadow(color: PlayerPalette.shadow.opacity(0.35), radius: 8, y: 4)
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Self.placeholderGradient)
    }

    private var placeholderIcon: some View {
        placeholder
            .overlay(
                Image(systemName: "book.closed")
                    .font(.title2)
                    .foregroundStyle(PlayerPalette.accent.opacity(0.75))
            )
    }
}
