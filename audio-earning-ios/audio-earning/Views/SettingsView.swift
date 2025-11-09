//
//  SettingsView.swift
//  audio-earning
//
//  Created by Claude Code on 2025/11/04.
//

import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var isShowingExportShare = false
    @State private var isShowingImportPicker = false
    @State private var exportedFileURL: URL?
    @State private var isProcessing = false
    @State private var alertConfig: AlertConfig?
    @State private var pendingBackupData: BackupData?
    @State private var isShowingImportConfirmation = false

    var body: some View {
        List {
            Section {
                NavigationLink {
                    BackendConfigurationView(viewModel: dependencies.makeBackendConfigurationViewModel())
                } label: {
                    Label {
                        Text("伺服器設定")
                    } icon: {
                        Image(systemName: "server.rack")
                            .foregroundColor(.purple)
                    }
                }
            } header: {
                Text("後端")
            } footer: {
                Text("調整 API 端點、測試連線並管理自訂伺服器清單。")
            }

            // Section 1: 資料管理
            Section {
                Button {
                    Task { await handleExport() }
                } label: {
                    Label {
                        Text("導出所有資料")
                    } icon: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.blue)
                    }
                }
                .disabled(isProcessing)

                Button {
                    isShowingImportPicker = true
                } label: {
                    Label {
                        Text("導入資料")
                    } icon: {
                        Image(systemName: "square.and.arrow.down")
                            .foregroundColor(.green)
                    }
                }
                .disabled(isProcessing)
            } header: {
                Text("資料管理")
            } footer: {
                Text("導出資料後可透過 AirDrop 或雲端儲存分享到其他裝置。導入會完全覆蓋現有資料。")
            }

            // Section 2: 快取管理
            Section {
                Button(role: .destructive) {
                    Task {
                        await clearCache()
                    }
                } label: {
                    Label("清除快取", systemImage: "trash")
                }
            } header: {
                Text("儲存空間")
            } footer: {
                Text("清除快取會刪除已下載的音頻和字幕檔案，但不會影響學習進度。")
            }

            // Section 4: 關於
            Section("關於") {
                HStack {
                    Text("版本")
                    Spacer()
                    Text(appVersion)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("設定")
        .overlay {
            if isProcessing {
                ProgressView("處理中...")
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(12)
            }
        }
        .sheet(isPresented: $isShowingExportShare) {
            if let url = exportedFileURL {
                ActivityView(activityItems: [url])
            }
        }
        .fileImporter(
            isPresented: $isShowingImportPicker,
            allowedContentTypes: [.json],
            onCompletion: handleImportSelection
        )
        .confirmationDialog(
            "確認導入資料？",
            isPresented: $isShowingImportConfirmation,
            presenting: pendingBackupData
        ) { backup in
            Button("導入並覆蓋現有資料", role: .destructive) {
                Task { await performImport(backup) }
            }
            Button("取消", role: .cancel) {
                pendingBackupData = nil
            }
        } message: { backup in
            Text("""
            將覆蓋所有現有資料：
            • 學習進度：\(backup.listeningProgress.count) 筆
            • 詞彙收藏：\(backup.savedLexiconEntries.count) 筆
            • 高亮單詞：\(backup.highlightedWords.count) 個

            備份建立時間：\(backup.createdAt.formatted(date: .long, time: .shortened))
            來源裝置：\(backup.deviceInfo.systemName)
            """)
        }
        .alert(
            alertConfig?.title ?? "",
            isPresented: Binding(
                get: { alertConfig != nil },
                set: { if !$0 { alertConfig = nil } }
            )
        ) {
            Button("確定", role: .cancel) {
                alertConfig = nil
            }
        } message: {
            Text(alertConfig?.message ?? "")
        }
    }

    // MARK: - Actions

    private func handleExport() async {
        isProcessing = true
        defer { isProcessing = false }

        do {
            // 導出資料
            let data = try await DataExportService.shared.exportAllData()

            // 創建臨時檔案
            let fileURL = try DataExportService.shared.createTemporaryFile(from: data)

            // 顯示分享 sheet
            await MainActor.run {
                exportedFileURL = fileURL
                isShowingExportShare = true
            }
        } catch {
            await MainActor.run {
                alertConfig = AlertConfig(
                    title: "導出失敗",
                    message: "無法導出資料：\(error.localizedDescription)"
                )
            }
        }
    }

    private func handleImportSelection(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            Task {
                await validateAndPrepareImport(from: url)
            }
        case .failure(let error):
            alertConfig = AlertConfig(
                title: "選擇檔案失敗",
                message: error.localizedDescription
            )
        }
    }

    private func validateAndPrepareImport(from url: URL) async {
        isProcessing = true
        defer { isProcessing = false }

        do {
            let scoped = url.startAccessingSecurityScopedResource()
            defer {
                if scoped {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            // 讀取檔案
            let data = try readData(from: url)

            // 驗證格式
            let backup = try DataImportService.shared.validateBackupData(data)

            // 顯示確認對話框
            await MainActor.run {
                pendingBackupData = backup
                isShowingImportConfirmation = true
            }
        } catch let error as DataImportService.ImportError {
            await MainActor.run {
                let errorMessage = error.errorDescription ?? "未知錯誤"
                alertConfig = AlertConfig(
                    title: "導入失敗",
                    message: errorMessage
                )
            }
        } catch {
            await MainActor.run {
                alertConfig = AlertConfig(
                    title: "導入失敗",
                    message: "無法讀取備份檔案：\(error.localizedDescription)"
                )
            }
        }
    }

    private func readData(from url: URL) throws -> Data {
        var coordinationError: NSError?
        var readError: Error?
        var resultData = Data()

        let coordinator = NSFileCoordinator()
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinatedURL in
            do {
                resultData = try Data(contentsOf: coordinatedURL)
            } catch {
                readError = error
            }
        }

        if let coordinationError {
            throw coordinationError
        }

        if let readError {
            throw readError
        }

        return resultData
    }

    private func performImport(_ backup: BackupData) async {
        isProcessing = true
        defer { isProcessing = false }

        do {
            try await DataImportService.shared.importData(backup)

            await MainActor.run {
                pendingBackupData = nil
                alertConfig = AlertConfig(
                    title: "導入成功",
                    message: "所有資料已成功導入並覆蓋"
                )
            }
        } catch {
            await MainActor.run {
                alertConfig = AlertConfig(
                    title: "導入失敗",
                    message: "導入過程中發生錯誤：\(error.localizedDescription)"
                )
            }
        }
    }

    private func clearCache() async {
        do {
            let summary = try await CacheManager.shared.clearAllCaches()
            await MainActor.run {
                alertConfig = AlertConfig(
                    title: "完成",
                    message: "快取已清除，共移除 \(summary.removedMediaFiles) 個媒體檔案"
                )
            }
        } catch {
            await MainActor.run {
                alertConfig = AlertConfig(
                    title: "錯誤",
                    message: "清除快取失敗：\(error.localizedDescription)"
                )
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
}

// MARK: - Alert Configuration

struct AlertConfig {
    let title: String
    let message: String
}

// MARK: - Activity View (Share Sheet)

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No update needed
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SettingsView()
    }
}
