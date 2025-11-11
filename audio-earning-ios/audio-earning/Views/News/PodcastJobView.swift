import SwiftUI

struct PodcastJobView: View {
    @Environment(\.dependencies) private var dependencies
    @StateObject private var viewModel: PodcastJobViewModel

    init(viewModel: PodcastJobViewModel? = nil) {
        if let vm = viewModel {
            _viewModel = StateObject(wrappedValue: vm)
        } else {
            _viewModel = StateObject(wrappedValue: PodcastJobViewModel())
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            urlInputSection
            jobList
        }
        .padding()
        .navigationTitle("生成 Podcast")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { viewModel.refresh() }) {
                    if viewModel.isPolling {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(viewModel.isSubmitting)
            }
        }
        .onAppear {
            viewModel.startPolling()
        }
        .onDisappear {
            viewModel.stopPolling()
        }
        .alert("錯誤", isPresented: $viewModel.showErrorBanner, presenting: viewModel.errorMessage) { _ in
            Button("確定", role: .cancel) { }
        } message: { message in
            Text(message)
        }
        .task {
            if let vm = viewModel as? PodcastJobViewModel,
               viewModel === vm {
                vm.refresh()
            }
        }
    }

    private var urlInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("貼上想轉成 Podcast 的文章網址")
                .font(.headline)

            TextField("https://example.com/article", text: $viewModel.urlText)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .autocorrectionDisabled(true)
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                viewModel.submitJob()
            } label: {
                if viewModel.isSubmitting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Label("送出生成任務", systemImage: "paperplane.fill")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isSubmitting)

            if let error = viewModel.errorMessage, viewModel.showErrorBanner {
                Text(error)
                    .font(.footnote)
                    .foregroundColor(.red)
            }
        }
    }

    private var jobList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if viewModel.jobs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "waveform")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("尚無任務，貼上網址開始生成")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    ForEach(viewModel.jobs) { job in
                        PodcastJobCard(job: job)
                    }
                }
            }
        }
    }
}

private struct PodcastJobCard: View {
    let job: PodcastJob

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(statusText)
                    .font(.subheadline.bold())
                    .foregroundColor(statusColor)
                Spacer()
                Text(job.createdAt, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(job.payload.title)
                .font(.headline)
                .foregroundColor(.primary)
                .lineLimit(2)

            Text(job.payload.sourceValue)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)

            if let message = job.errorMessage, job.status == .failed {
                Text(message)
                    .font(.footnote)
                    .foregroundColor(.red)
            }

            if job.status == .succeeded, let chapter = job.resultPaths?.chapterDir {
                Text("完成：\(chapter)")
                    .font(.footnote)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private var statusText: String {
        switch job.status {
        case .queued:
            return "排隊中"
        case .running:
            return "處理中"
        case .succeeded:
            return "完成"
        case .failed:
            return "失敗"
        }
    }

    private var statusColor: Color {
        switch job.status {
        case .queued:
            return .gray
        case .running:
            return .orange
        case .succeeded:
            return .green
        case .failed:
            return .red
        }
    }
}
