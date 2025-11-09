import Foundation

struct SavedLexiconEntry: Identifiable, Codable, Equatable, Hashable {
    struct Vocabulary: Codable, Equatable, Hashable {
        let word: String
        let meaning: String
        let note: String?
    }

    let id: UUID
    let createdAt: Date
    let title: String
    let subtitle: String
    let chineseMeaning: String?
    let overview: String
    let keyPoints: [String]
    let vocabulary: [Vocabulary]
    let sourceSentence: String
    let sourceBookID: String?
    let sourceChapterID: String?
    let sourceSubtitleID: Int
}
