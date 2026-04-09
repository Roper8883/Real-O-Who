import Foundation

nonisolated enum MarketplaceSafetyReportReason: String, CaseIterable, Codable, Identifiable, Sendable {
    case harassment
    case threats
    case fraud
    case spam
    case inappropriate
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .harassment:
            return "Harassment"
        case .threats:
            return "Threats or intimidation"
        case .fraud:
            return "Fraud or scam concern"
        case .spam:
            return "Spam"
        case .inappropriate:
            return "Inappropriate content"
        case .other:
            return "Other"
        }
    }
}

nonisolated struct ConversationSafetyReport: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var conversationID: UUID
    var listingID: UUID
    var reporterID: UUID
    var reportedUserID: UUID
    var messageID: UUID?
    var reason: MarketplaceSafetyReportReason
    var notes: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        conversationID: UUID,
        listingID: UUID,
        reporterID: UUID,
        reportedUserID: UUID,
        messageID: UUID? = nil,
        reason: MarketplaceSafetyReportReason,
        notes: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.conversationID = conversationID
        self.listingID = listingID
        self.reporterID = reporterID
        self.reportedUserID = reportedUserID
        self.messageID = messageID
        self.reason = reason
        self.notes = notes
        self.createdAt = createdAt
    }
}

nonisolated struct MarketplaceContentModerationIssue: LocalizedError, Hashable, Sendable {
    var errorDescription: String?

    init(_ errorDescription: String) {
        self.errorDescription = errorDescription
    }
}

nonisolated enum MarketplaceSafetyPolicy {
    private static let blockedPhrases = [
        "kill you",
        "kill yourself",
        "rape",
        "rapist",
        "nazi",
        "whore",
        "slut",
        "faggot",
        "retard"
    ]

    static let filteredMessagePlaceholder =
        "Message hidden by the Real O Who safety filter. Use Report if you need us to review it."

    static func moderationIssue(for text: String) -> MarketplaceContentModerationIssue? {
        let normalizedText = normalize(text)
        guard !normalizedText.isEmpty else { return nil }

        if blockedPhrases.contains(where: { normalizedText.contains($0) }) {
            return MarketplaceContentModerationIssue(
                "That text looks abusive, threatening, or inappropriate, so it can’t be posted in Real O Who."
            )
        }

        return nil
    }

    static func shouldHideMessage(_ text: String) -> Bool {
        moderationIssue(for: text) != nil
    }

    private static func normalize(_ text: String) -> String {
        text
            .lowercased()
            .components(separatedBy: .punctuationCharacters)
            .joined(separator: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
