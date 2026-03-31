import Combine
import Foundation

@MainActor
final class JournalStore: ObservableObject {
    @Published private(set) var entries: [JournalEntry]

    private let fileManager: FileManager
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.entries = []

        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        let applicationSupport = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fileManager.temporaryDirectory

        let directory = applicationSupport.appendingPathComponent("RealAWho", isDirectory: true)
        self.fileURL = directory.appendingPathComponent("journal_entries.json")

        load()
    }

    init(previewEntries: [JournalEntry]) {
        self.fileManager = .default
        self.fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("real-a-who-preview.json")
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.entries = previewEntries

        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    var sortedEntries: [JournalEntry] {
        entries.sorted { lhs, rhs in
            if Calendar.current.isDate(lhs.entryDate, inSameDayAs: rhs.entryDate) {
                return lhs.updatedAt > rhs.updatedAt
            }

            return lhs.entryDate > rhs.entryDate
        }
    }

    var favoritesCount: Int {
        entries.filter(\.isFavorite).count
    }

    var entriesThisWeek: Int {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: .now)) ?? .now

        return entries.filter { entry in
            calendar.startOfDay(for: entry.entryDate) >= cutoff
        }.count
    }

    var currentStreak: Int {
        let calendar = Calendar.current
        let uniqueDays = Set(entries.map { calendar.startOfDay(for: $0.entryDate) })

        guard !uniqueDays.isEmpty else { return 0 }

        let today = calendar.startOfDay(for: .now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today

        guard uniqueDays.contains(today) || uniqueDays.contains(yesterday) else { return 0 }

        var streak = 0
        var currentDay = uniqueDays.contains(today) ? today : yesterday

        while uniqueDays.contains(currentDay) {
            streak += 1
            currentDay = calendar.date(byAdding: .day, value: -1, to: currentDay) ?? currentDay
        }

        return streak
    }

    var mostCommonMood: ReflectionMood? {
        moodBreakdown.max(by: { $0.count < $1.count })?.mood
    }

    var moodBreakdown: [MoodBreakdownItem] {
        ReflectionMood.allCases.compactMap { mood in
            let count = entries.filter { $0.mood == mood }.count
            guard count > 0 else { return nil }
            return MoodBreakdownItem(mood: mood, count: count)
        }
    }

    var tagCounts: [(tag: String, count: Int)] {
        let counts = entries
            .flatMap(\.tags)
            .reduce(into: [String: Int]()) { partialResult, tag in
                partialResult[tag, default: 0] += 1
            }

        return counts
            .map { (tag: $0.key, count: $0.value) }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs.tag.localizedCaseInsensitiveCompare(rhs.tag) == .orderedAscending
                }

                return lhs.count > rhs.count
            }
    }

    var totalWordCount: Int {
        entries.reduce(into: 0) { total, entry in
            total += entry.body.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        }
    }

    var averageWordCount: Int {
        guard !entries.isEmpty else { return 0 }
        return totalWordCount / entries.count
    }

    func entry(id: UUID) -> JournalEntry? {
        entries.first { $0.id == id }
    }

    func save(draft: JournalDraft, editing existingEntry: JournalEntry?) {
        let now = Date()

        if let existingEntry,
           let index = entries.firstIndex(where: { $0.id == existingEntry.id }) {
            entries[index].title = draft.title.cleanedText
            entries[index].prompt = draft.prompt.cleanedText
            entries[index].body = draft.body.cleanedText
            entries[index].mood = draft.mood
            entries[index].isFavorite = draft.isFavorite
            entries[index].tags = draft.sanitizedTags
            entries[index].entryDate = draft.entryDate
            entries[index].updatedAt = now
        } else {
            entries.append(
                JournalEntry(
                    id: UUID(),
                    title: draft.title.cleanedText,
                    prompt: draft.prompt.cleanedText,
                    body: draft.body.cleanedText,
                    mood: draft.mood,
                    isFavorite: draft.isFavorite,
                    tags: draft.sanitizedTags,
                    entryDate: draft.entryDate,
                    createdAt: now,
                    updatedAt: now
                )
            )
        }

        persist()
    }

    func delete(_ entry: JournalEntry) {
        entries.removeAll { $0.id == entry.id }
        persist()
    }

    func toggleFavorite(_ entry: JournalEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index].isFavorite.toggle()
        entries[index].updatedAt = .now
        persist()
    }

    private func load() {
        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )

            guard fileManager.fileExists(atPath: fileURL.path) else {
                entries = []
                return
            }

            let data = try Data(contentsOf: fileURL)
            entries = try decoder.decode([JournalEntry].self, from: data)
        } catch {
            entries = []
        }
    }

    private func persist() {
        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            let data = try encoder.encode(entries)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            assertionFailure("Failed to save journal entries: \(error.localizedDescription)")
        }
    }
}

extension JournalStore {
    static let preview = JournalStore(previewEntries: JournalEntry.sampleEntries)
}
