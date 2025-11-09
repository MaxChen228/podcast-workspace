import Foundation

@MainActor
final class SavedLexiconStore: ObservableObject {
    static let shared = SavedLexiconStore()

    @Published private(set) var entries: [SavedLexiconEntry] = [] {
        didSet {
            persist()
        }
    }

    private let defaultsKey = "saved.lexicon.entries"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        load()
    }

    func add(_ entry: SavedLexiconEntry) {
        entries.insert(entry, at: 0)
    }

    func remove(_ id: UUID) {
        entries.removeAll { $0.id == id }
    }

    func clearAll() {
        entries.removeAll()
    }

    // MARK: - Backup & Restore

    /// 導出所有詞彙條目（用於備份）
    func exportEntries() -> [SavedLexiconEntry] {
        return entries
    }

    /// 導入詞彙條目（完全覆蓋現有資料）
    func importEntries(_ newEntries: [SavedLexiconEntry]) {
        entries = newEntries
        // didSet 會自動觸發 persist()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return }
        do {
            let decoded = try decoder.decode([SavedLexiconEntry].self, from: data)
            entries = decoded
        } catch {
#if DEBUG
            print("⚠️ Failed to load saved lexicon entries: \(error.localizedDescription)")
#endif
            entries = []
        }
    }

    private func persist() {
        do {
            let data = try encoder.encode(entries)
            UserDefaults.standard.set(data, forKey: defaultsKey)
        } catch {
#if DEBUG
            print("⚠️ Failed to persist saved lexicon entries: \(error.localizedDescription)")
#endif
        }
    }
}
