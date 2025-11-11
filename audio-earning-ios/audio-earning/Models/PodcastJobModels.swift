import Foundation

struct PodcastJobPayload: Decodable, Encodable {
    let sourceType: String
    let sourceValue: String
    let language: String
    let bookID: String
    let chapterID: String
    let title: String
    let notes: String?
    let createBook: Bool?

    enum CodingKeys: String, CodingKey {
        case sourceType = "source_type"
        case sourceValue = "source_value"
        case language
        case bookID = "book_id"
        case chapterID = "chapter_id"
        case title
        case notes
        case createBook = "create_book"
    }
}

struct PodcastJobResultPaths: Decodable {
    let chapterDir: String?
    let scriptFile: String?
    let audioWav: String?
    let audioMp3: String?
    let metadata: String?
    let subtitles: String?

    enum CodingKeys: String, CodingKey {
        case chapterDir = "chapter_dir"
        case scriptFile = "script_file"
        case audioWav = "audio_wav"
        case audioMp3 = "audio_mp3"
        case metadata
        case subtitles
    }
}

enum PodcastJobStatus: String, Decodable, CaseIterable {
    case queued
    case running
    case succeeded
    case failed
}

struct PodcastJob: Decodable, Identifiable {
    let id: String
    let status: PodcastJobStatus
    let requestedBy: String?
    let payload: PodcastJobPayload
    let resultPaths: PodcastJobResultPaths?
    let errorMessage: String?
    let progress: Int?
    let logExcerpt: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case status
        case requestedBy = "requested_by"
        case payload
        case resultPaths = "result_paths"
        case errorMessage = "error_message"
        case progress
        case logExcerpt = "log_excerpt"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct PodcastJobListResponse: Decodable {
    let items: [PodcastJob]
    let total: Int
}

struct PodcastJobCreatePayload: Encodable {
    let sourceType: String
    let sourceValue: String
    let language: String
    let bookID: String
    let chapterID: String
    let title: String
    let notes: String?
    let requestedBy: String?
    let createBook: Bool

    enum CodingKeys: String, CodingKey {
        case sourceType = "source_type"
        case sourceValue = "source_value"
        case language
        case bookID = "book_id"
        case chapterID = "chapter_id"
        case title
        case notes
        case requestedBy = "requested_by"
        case createBook = "create_book"
    }
}
