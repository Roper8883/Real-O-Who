import Foundation
import SwiftUI

struct SaleTaskAudienceStatusRow: View {
    @EnvironmentObject private var taskSnapshots: SaleTaskSnapshotSyncStore

    let snapshot: SaleTaskLiveSnapshot
    let messageID: String?
    let taskID: String?
    let audience: [SaleTaskSnapshotAudienceMember]
    let currentViewerID: String?
    var markAsSeenOnAppear = false

    private var status: SaleTaskAudienceStatus? {
        taskSnapshots.audienceStatus(
            for: snapshot,
            messageID: messageID,
            taskID: taskID,
            audience: audience
        )
    }

    private var trackingKey: String {
        [
            snapshot.tone.rawValue,
            snapshot.summary,
            messageID ?? "no-message",
            taskID ?? "no-task",
            currentViewerID ?? "no-viewer",
            markAsSeenOnAppear ? "mark" : "read-only"
        ]
        .joined(separator: "|")
    }

    var body: some View {
        if let status {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: statusSymbolName(for: status))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusTint(for: status))
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 2) {
                    Text(primaryLine(for: status))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(statusTint(for: status))

                    if let secondaryLine = secondaryLine(for: status) {
                        Text(secondaryLine)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .task(id: trackingKey) {
                guard markAsSeenOnAppear,
                      snapshotNeedsUrgentViewerAttention,
                      currentViewerID != nil else {
                    return
                }

                taskSnapshots.markUrgentSnapshotSeen(
                    snapshot,
                    messageID: messageID,
                    viewerID: currentViewerID,
                    taskID: taskID
                )
            }
        }
    }

    private func primaryLine(for status: SaleTaskAudienceStatus) -> String {
        if !status.pending.isEmpty, status.seenBy.isEmpty, status.waitingOn.isEmpty {
            return "Checking \(joinedLabelList(status.pending))"
        }

        if status.waitingOn.isEmpty, !status.seenBy.isEmpty {
            return "Seen by everyone"
        }

        if status.seenBy.isEmpty {
            return "Not seen yet"
        }

        return "Seen by \(joinedLabelList(status.seenBy))"
    }

    private func secondaryLine(for status: SaleTaskAudienceStatus) -> String? {
        var details: [String] = []

        if let latestSeenEntry = status.seenEntries.first {
            details.append(lastSeenLine(for: latestSeenEntry))
        }

        if !status.waitingOn.isEmpty {
            details.append("Waiting on \(joinedLabelList(status.waitingOn))")
        }

        if !status.pending.isEmpty {
            details.append("Checking \(joinedLabelList(status.pending))")
        }

        if details.isEmpty, status.waitingOn.isEmpty, !status.seenBy.isEmpty {
            return joinedLabelList(status.seenBy)
        }

        return details.isEmpty ? nil : details.joined(separator: " • ")
    }

    private func lastSeenLine(for entry: SaleTaskAudienceSeenEntry) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        let relativeTime = formatter.localizedString(for: entry.seenAt, relativeTo: Date())
        return "Last seen by \(entry.label) \(relativeTime)"
    }

    private func statusSymbolName(for status: SaleTaskAudienceStatus) -> String {
        if !status.pending.isEmpty, status.seenBy.isEmpty, status.waitingOn.isEmpty {
            return "arrow.triangle.2.circlepath"
        }

        if status.waitingOn.isEmpty, !status.seenBy.isEmpty {
            return "eye.fill"
        }

        if status.seenBy.isEmpty {
            return "eye.slash"
        }

        return "eye.badge.clock"
    }

    private func statusTint(for status: SaleTaskAudienceStatus) -> Color {
        if !status.waitingOn.isEmpty || status.seenBy.isEmpty {
            return snapshot.tone == .critical ? .orange : Color(red: 0.0, green: 0.45, blue: 0.56)
        }

        return .green
    }

    private func joinedLabelList(_ labels: [String]) -> String {
        labels.joined(separator: ", ")
    }

    private var snapshotNeedsUrgentViewerAttention: Bool {
        let normalizedSummary = snapshot.summary.lowercased()
        return snapshot.tone == .critical ||
            normalizedSummary.contains("overdue") ||
            normalizedSummary.contains("follow-up") ||
            normalizedSummary.contains("follow up")
    }
}

struct SaleTaskAudienceCompactBadge: View {
    private struct CompactSummary {
        let text: String
        let symbolName: String
        let tint: Color
        let background: Color
    }

    @EnvironmentObject private var taskSnapshots: SaleTaskSnapshotSyncStore

    let snapshot: SaleTaskLiveSnapshot
    let messageID: String?
    let taskID: String?
    let audience: [SaleTaskSnapshotAudienceMember]

    private var status: SaleTaskAudienceStatus? {
        taskSnapshots.audienceStatus(
            for: snapshot,
            messageID: messageID,
            taskID: taskID,
            audience: audience
        )
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            if let status, let summary = compactSummary(for: status, now: context.date) {
                Label(summary.text, systemImage: summary.symbolName)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(summary.background)
                    )
                    .foregroundStyle(summary.tint)
            }
        }
    }

    private func compactSummary(for status: SaleTaskAudienceStatus, now: Date) -> CompactSummary? {
        if let latestSeenEntry = status.seenEntries.first {
            let seenLine = "Seen \(relativeTimeString(for: latestSeenEntry.seenAt, now: now)) by \(latestSeenEntry.label)"
            if status.waitingOn.isEmpty {
                return CompactSummary(
                    text: seenLine,
                    symbolName: "eye.fill",
                    tint: .green,
                    background: Color.green.opacity(0.14)
                )
            }

            let tint = attentionTint(for: status)
            return CompactSummary(
                text: seenLine,
                symbolName: "eye.badge.clock",
                tint: tint,
                background: tint.opacity(0.14)
            )
        }

        if !status.waitingOn.isEmpty {
            let tint = attentionTint(for: status)
            return CompactSummary(
                text: "Waiting on \(joinedLabelList(status.waitingOn))",
                symbolName: "eye.slash",
                tint: tint,
                background: tint.opacity(0.14)
            )
        }

        if !status.pending.isEmpty {
            return CompactSummary(
                text: "Checking \(joinedLabelList(status.pending))",
                symbolName: "arrow.triangle.2.circlepath",
                tint: Color.secondary,
                background: Color.secondary.opacity(0.12)
            )
        }

        if !status.seenBy.isEmpty {
            return CompactSummary(
                text: "Seen by everyone",
                symbolName: "eye.fill",
                tint: .green,
                background: Color.green.opacity(0.14)
            )
        }

        return nil
    }

    private func relativeTimeString(for date: Date, now: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: now)
    }

    private func attentionTint(for status: SaleTaskAudienceStatus) -> Color {
        if !status.waitingOn.isEmpty || status.seenBy.isEmpty {
            return snapshot.tone == .critical ? .orange : Color(red: 0.0, green: 0.45, blue: 0.56)
        }

        return .green
    }

    private func joinedLabelList(_ labels: [String]) -> String {
        labels.joined(separator: ", ")
    }
}
