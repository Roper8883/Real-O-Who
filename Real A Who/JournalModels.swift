import Foundation
import SwiftUI

enum ReflectionMood: String, CaseIterable, Identifiable, Codable {
    case grounded
    case hopeful
    case calm
    case curious
    case proud
    case tired
    case stressed

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }

    var symbol: String {
        switch self {
        case .grounded:
            return "leaf.fill"
        case .hopeful:
            return "sunrise.fill"
        case .calm:
            return "drop.fill"
        case .curious:
            return "sparkle.magnifyingglass"
        case .proud:
            return "star.fill"
        case .tired:
            return "moon.zzz.fill"
        case .stressed:
            return "bolt.heart.fill"
        }
    }

    var tint: Color {
        switch self {
        case .grounded:
            return Color(red: 0.19, green: 0.52, blue: 0.39)
        case .hopeful:
            return Color(red: 0.93, green: 0.55, blue: 0.17)
        case .calm:
            return Color(red: 0.16, green: 0.52, blue: 0.77)
        case .curious:
            return Color(red: 0.46, green: 0.34, blue: 0.77)
        case .proud:
            return Color(red: 0.90, green: 0.67, blue: 0.08)
        case .tired:
            return Color(red: 0.36, green: 0.42, blue: 0.58)
        case .stressed:
            return Color(red: 0.80, green: 0.30, blue: 0.32)
        }
    }

    var insightLine: String {
        switch self {
        case .grounded:
            return "You tend to write when you feel settled."
        case .hopeful:
            return "Optimism is showing up often in your notes."
        case .calm:
            return "Your reflections skew toward steadiness."
        case .curious:
            return "Questions and exploration are a recurring pattern."
        case .proud:
            return "You are capturing a lot of forward movement."
        case .tired:
            return "Energy may be worth paying closer attention to."
        case .stressed:
            return "Pressure is a noticeable theme in recent entries."
        }
    }
}

struct ReflectionPrompt: Identifiable, Equatable {
    let id: Int
    let title: String
    let followUp: String
}

enum PromptLibrary {
    static let quickPrompt = ReflectionPrompt(
        id: 10_000,
        title: "What do I want to remember about today?",
        followUp: "A few honest lines are enough."
    )

    static let prompts: [ReflectionPrompt] = [
        ReflectionPrompt(id: 1, title: "What felt most real today?", followUp: "Name the moment, person, or choice that grounded you."),
        ReflectionPrompt(id: 2, title: "Where did I surprise myself today?", followUp: "Notice effort, restraint, courage, or honesty."),
        ReflectionPrompt(id: 3, title: "What am I carrying that needs a name?", followUp: "Stress, hope, grief, anticipation, or relief all count."),
        ReflectionPrompt(id: 4, title: "What gave me energy today?", followUp: "Think about people, routines, food, movement, or progress."),
        ReflectionPrompt(id: 5, title: "What drained me more than it should have?", followUp: "A clear pattern today can become a better decision tomorrow."),
        ReflectionPrompt(id: 6, title: "What do I need more of right now?", followUp: "Be practical: rest, support, focus, quiet, momentum, or play."),
        ReflectionPrompt(id: 7, title: "What conversation is still echoing for me?", followUp: "Write what mattered, not just what was said."),
        ReflectionPrompt(id: 8, title: "Which version of me showed up today?", followUp: "Protective, brave, patient, scattered, generous, or something else."),
        ReflectionPrompt(id: 9, title: "What am I avoiding, and why?", followUp: "Even a half-answer can make the next step clearer."),
        ReflectionPrompt(id: 10, title: "What deserves more credit than I gave it?", followUp: "Look for quiet wins and almost-invisible progress."),
        ReflectionPrompt(id: 11, title: "What would I like tomorrow to feel like?", followUp: "Describe the mood first, then the plan."),
        ReflectionPrompt(id: 12, title: "What did I learn about myself this week?", followUp: "Small truths matter more than perfect insights."),
        ReflectionPrompt(id: 13, title: "When did I feel most like myself today?", followUp: "That moment is probably telling you something important."),
        ReflectionPrompt(id: 14, title: "What do I need to stop pretending is fine?", followUp: "Write the most direct sentence you can manage."),
        ReflectionPrompt(id: 15, title: "What is getting better, even slowly?", followUp: "Progress counts even when it is quiet and uneven."),
        ReflectionPrompt(id: 16, title: "What am I grateful for that feels specific?", followUp: "Skip the generic answer and find the real one."),
        ReflectionPrompt(id: 17, title: "What boundary would make life easier right now?", followUp: "Think in terms of time, attention, energy, or access."),
        ReflectionPrompt(id: 18, title: "What worry shrank once I looked at it clearly?", followUp: "Sometimes naming a fear is enough to reduce it."),
        ReflectionPrompt(id: 19, title: "What deserves a second chance from me?", followUp: "An idea, a habit, a person, or even yourself."),
        ReflectionPrompt(id: 20, title: "What do I want future me to remember?", followUp: "Capture the lesson before the day smooths it over.")
    ]

    static func prompt(for date: Date = .now, calendar: Calendar = .current) -> ReflectionPrompt {
        let dayNumber = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        return prompts[dayNumber % prompts.count]
    }
}

struct JournalEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var prompt: String
    var body: String
    var mood: ReflectionMood
    var isFavorite: Bool
    var tags: [String]
    var entryDate: Date
    var createdAt: Date
    var updatedAt: Date

    var displayTitle: String {
        let cleanTitle = title.cleanedText
        if !cleanTitle.isEmpty {
            return cleanTitle
        }

        if let firstLine = body
            .split(whereSeparator: { $0.isNewline })
            .first
            .map({ String($0).trimmingCharacters(in: .whitespacesAndNewlines) }),
           !firstLine.isEmpty {
            return String(firstLine.prefix(56))
        }

        return prompt
    }

    var summary: String {
        let condensed = body.cleanedText.replacingOccurrences(of: "\n", with: " ")
        return condensed.isEmpty ? "No text saved." : String(condensed.prefix(110))
    }

    var shareText: String {
        var lines = [displayTitle, "", "Prompt: \(prompt)", "", body.cleanedText]

        if !tags.isEmpty {
            lines.append("")
            lines.append("Tags: \(tags.joined(separator: ", "))")
        }

        return lines.joined(separator: "\n")
    }
}

struct JournalDraft {
    var title: String
    var prompt: String
    var body: String
    var mood: ReflectionMood
    var isFavorite: Bool
    var tagsText: String
    var entryDate: Date

    init(prompt: String) {
        title = ""
        self.prompt = prompt
        body = ""
        mood = .grounded
        isFavorite = false
        tagsText = ""
        entryDate = .now
    }

    init(entry: JournalEntry) {
        title = entry.title
        prompt = entry.prompt
        body = entry.body
        mood = entry.mood
        isFavorite = entry.isFavorite
        tagsText = entry.tags.joined(separator: ", ")
        entryDate = entry.entryDate
    }

    var sanitizedTags: [String] {
        tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .uniquedPreservingOrder()
    }

    var isSaveable: Bool {
        !title.cleanedText.isEmpty || !body.cleanedText.isEmpty
    }
}

struct MoodBreakdownItem: Identifiable {
    let mood: ReflectionMood
    let count: Int

    var id: ReflectionMood { mood }
}

extension String {
    var cleanedText: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension Array where Element == String {
    func uniquedPreservingOrder() -> [String] {
        var seen = Set<String>()

        return compactMap { item in
            let normalized = item.cleanedText
            guard !normalized.isEmpty else { return nil }

            let lowered = normalized.lowercased()
            guard seen.insert(lowered).inserted else { return nil }
            return normalized
        }
    }
}

extension JournalEntry {
    static let sampleEntries: [JournalEntry] = [
        JournalEntry(
            id: UUID(),
            title: "The meeting felt lighter than expected",
            prompt: PromptLibrary.prompts[0].title,
            body: "I was bracing for conflict, but I stayed calm and asked better questions. That shifted the whole tone of the conversation.",
            mood: .proud,
            isFavorite: true,
            tags: ["work", "communication"],
            entryDate: .now,
            createdAt: .now,
            updatedAt: .now
        ),
        JournalEntry(
            id: UUID(),
            title: "I need more quiet in the evenings",
            prompt: PromptLibrary.prompts[5].title,
            body: "I keep pushing late into the night and then wondering why the next morning feels rushed. A softer finish to the day would help.",
            mood: .tired,
            isFavorite: false,
            tags: ["rest", "routine"],
            entryDate: Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now,
            createdAt: Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now,
            updatedAt: Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now
        )
    ]
}
