import Foundation
import UIKit

@MainActor
final class PodcastJobViewModel: ObservableObject {
    @Published private(set) var jobs: [PodcastJob] = []
    @Published var urlText: String = ""
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var showErrorBanner = false
    @Published private(set) var isPolling = false

    private let service: APIServiceProtocol
    private var pollTask: Task<Void, Never>?
    private let defaultBookID = "user-news"
    private let defaultLanguage = "English"

    init(service: APIServiceProtocol = APIService.shared) {
        self.service = service
    }

    func submitJob() {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), !trimmed.isEmpty else {
            presentError("請輸入有效的文章網址")
            return
        }

        isSubmitting = true
        errorMessage = nil
        let payload = buildPayload(for: url)

        Task {
            defer { isSubmitting = false }
            do {
                let job = try await service.submitPodcastJob(payload)
                upsert(job)
                urlText = ""
            } catch {
                presentError(error.localizedDescription)
            }
        }
    }

    func startPolling() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            guard let self else { return }
            isPolling = true
            defer { Task { @MainActor in self.isPolling = false } }
            while !Task.isCancelled {
                await fetchJobs()
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
        isPolling = false
    }

    func refresh() {
        Task { await fetchJobs() }
    }

    private func fetchJobs() async {
        do {
            let response = try await service.fetchPodcastJobs(statuses: nil)
            await MainActor.run {
                jobs = response.items.sorted { $0.createdAt > $1.createdAt }
            }
        } catch {
            presentError(error.localizedDescription)
        }
    }

    private func upsert(_ job: PodcastJob) {
        if let index = jobs.firstIndex(where: { $0.id == job.id }) {
            jobs[index] = job
        } else {
            jobs.insert(job, at: 0)
        }
    }

    private func buildPayload(for url: URL) -> PodcastJobCreatePayload {
        let randomPart = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8))
        let chapterID = "chapter_" + randomPart
        let requestedBy = UIDevice.current.identifierForVendor?.uuidString ?? "ios-client"
        let title = url.host ?? "授權文章"

        return PodcastJobCreatePayload(
            sourceType: "url",
            sourceValue: url.absoluteString,
            language: defaultLanguage,
            bookID: defaultBookID,
            chapterID: chapterID,
            title: title,
            notes: nil,
            requestedBy: requestedBy,
            createBook: true
        )
    }

    private func presentError(_ message: String) {
        errorMessage = message
        showErrorBanner = true
    }
}
