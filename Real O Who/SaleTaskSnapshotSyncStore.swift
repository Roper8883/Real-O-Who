import Combine
import Foundation

@MainActor
final class SaleTaskSnapshotSyncStore: ObservableObject {
    @Published private var statesByViewerID: [String: SaleTaskSnapshotViewerState] = [:]
    @Published private var loadedViewerIDs: Set<String> = []

    private let syncService: any MarketplaceTaskSnapshotStateSyncing
    private let isEphemeral: Bool
    private let remoteSyncEnabled: Bool
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let storageKey = "RealOWho.SeenUrgentTaskSnapshotStates"

    init(
        launchConfiguration: AppLaunchConfiguration,
        syncService: any MarketplaceTaskSnapshotStateSyncing,
        remoteSyncEnabled: Bool,
        defaults: UserDefaults = .standard
    ) {
        self.syncService = syncService
        self.isEphemeral = launchConfiguration.isScreenshotMode
        self.remoteSyncEnabled = remoteSyncEnabled
        self.defaults = defaults

        if !isEphemeral {
            load()
        }
    }

    static func viewerID(forUser userID: UUID) -> String {
        "user:\(userID.uuidString)"
    }

    static func viewerID(forInvite inviteID: UUID) -> String {
        "invite:\(inviteID.uuidString)"
    }

    func refresh(for viewerID: String?) async {
        guard let normalizedViewerID = normalizeViewerID(viewerID) else {
            return
        }

        if statesByViewerID[normalizedViewerID] != nil {
            loadedViewerIDs.insert(normalizedViewerID)
        }

        guard remoteSyncEnabled else {
            loadedViewerIDs.insert(normalizedViewerID)
            return
        }

        do {
            let remoteState = try await syncService.fetchState(for: normalizedViewerID)
            statesByViewerID[normalizedViewerID] = remoteState
            loadedViewerIDs.insert(normalizedViewerID)
            persist()
        } catch {
            loadedViewerIDs.insert(normalizedViewerID)
        }
    }

    func refresh(for viewerIDs: [String]) async {
        let normalizedViewerIDs = Array(
            Set(
                viewerIDs.compactMap { normalizeViewerID($0) }
            )
        )
        .sorted()

        for viewerID in normalizedViewerIDs {
            await refresh(for: viewerID)
        }
    }

    func removeState(for viewerID: String?) {
        guard let normalizedViewerID = normalizeViewerID(viewerID) else {
            return
        }

        statesByViewerID.removeValue(forKey: normalizedViewerID)
        loadedViewerIDs.remove(normalizedViewerID)
        persist()
    }

    func shouldEmphasizeUrgentSnapshot(
        _ snapshot: SaleTaskLiveSnapshot,
        messageID: String,
        viewerID: String?,
        taskID: String? = nil
    ) -> Bool {
        guard snapshot.needsUrgentViewerAttention,
              let normalizedViewerID = normalizeViewerID(viewerID),
              loadedViewerIDs.contains(normalizedViewerID) else {
            return false
        }

        let snapshotKey = snapshot.viewerSnapshotKey
        let state = statesByViewerID[normalizedViewerID]
        if let normalizedTaskID = normalizeTaskID(taskID),
           state?.seenUrgentSnapshotKeysByTaskID[normalizedTaskID] == snapshotKey {
            return false
        }

        return state?.seenUrgentSnapshotKeysByMessageID[messageID] != snapshotKey
    }

    func markUrgentSnapshotSeen(
        _ snapshot: SaleTaskLiveSnapshot,
        messageID: String? = nil,
        viewerID: String?,
        taskID: String? = nil
    ) {
        guard snapshot.needsUrgentViewerAttention,
              let normalizedViewerID = normalizeViewerID(viewerID) else {
            return
        }

        let snapshotKey = snapshot.viewerSnapshotKey
        let normalizedMessageID = normalizeMessageID(messageID)
        let normalizedTaskID = normalizeTaskID(taskID)
        let seenAt = Int64(Date().timeIntervalSince1970 * 1000)
        var state = statesByViewerID[normalizedViewerID] ??
            SaleTaskSnapshotViewerState(
                viewerID: normalizedViewerID,
                seenUrgentSnapshotKeysByMessageID: [:],
                seenUrgentSnapshotKeysByTaskID: [:],
                seenUrgentSnapshotSeenAtByMessageID: [:],
                seenUrgentSnapshotSeenAtByTaskID: [:]
            )

        let hasSeenMessageSnapshot = normalizedMessageID.map {
            state.seenUrgentSnapshotKeysByMessageID[$0] == snapshotKey
        } ?? true
        let hasSeenTaskSnapshot = normalizedTaskID.map {
            state.seenUrgentSnapshotKeysByTaskID[$0] == snapshotKey
        } ?? true

        if hasSeenMessageSnapshot && hasSeenTaskSnapshot {
            loadedViewerIDs.insert(normalizedViewerID)
            return
        }

        if let normalizedMessageID {
            state.seenUrgentSnapshotKeysByMessageID[normalizedMessageID] = snapshotKey
            state.seenUrgentSnapshotSeenAtByMessageID[normalizedMessageID] = seenAt
        }
        if let normalizedTaskID {
            state.seenUrgentSnapshotKeysByTaskID[normalizedTaskID] = snapshotKey
            state.seenUrgentSnapshotSeenAtByTaskID[normalizedTaskID] = seenAt
        }
        statesByViewerID[normalizedViewerID] = state
        loadedViewerIDs.insert(normalizedViewerID)
        persist()

        guard remoteSyncEnabled else {
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                let syncedState = try await self.syncService.upsertState(state)
                self.statesByViewerID[normalizedViewerID] = syncedState
                self.loadedViewerIDs.insert(normalizedViewerID)
                self.persist()
            } catch {
                return
            }
        }
    }

    func audienceStatus(
        for snapshot: SaleTaskLiveSnapshot,
        messageID: String? = nil,
        taskID: String? = nil,
        audience: [SaleTaskSnapshotAudienceMember]
    ) -> SaleTaskAudienceStatus? {
        guard snapshot.needsUrgentViewerAttention, !audience.isEmpty else {
            return nil
        }

        let snapshotKey = snapshot.viewerSnapshotKey
        let normalizedMessageID = normalizeMessageID(messageID)
        let normalizedTaskID = normalizeTaskID(taskID)

        var seenBy: [String] = []
        var waitingOn: [String] = []
        var pending: [String] = []
        var seenEntries: [SaleTaskAudienceSeenEntry] = []

        for member in audience {
            guard let normalizedViewerID = normalizeViewerID(member.viewerID) else {
                continue
            }

            guard loadedViewerIDs.contains(normalizedViewerID) else {
                pending.append(member.label)
                continue
            }

            let state = statesByViewerID[normalizedViewerID]
            let hasSeenTask = normalizedTaskID.map {
                state?.seenUrgentSnapshotKeysByTaskID[$0] == snapshotKey
            } ?? false
            let hasSeenMessage = normalizedMessageID.map {
                state?.seenUrgentSnapshotKeysByMessageID[$0] == snapshotKey
            } ?? false
            let seenAt = normalizedTaskID.flatMap {
                state?.seenUrgentSnapshotSeenAtByTaskID[$0]
            } ?? normalizedMessageID.flatMap {
                state?.seenUrgentSnapshotSeenAtByMessageID[$0]
            }

            if hasSeenTask || hasSeenMessage {
                seenBy.append(member.label)
                if let seenAt {
                    seenEntries.append(
                        SaleTaskAudienceSeenEntry(
                            label: member.label,
                            seenAt: Date(timeIntervalSince1970: TimeInterval(seenAt) / 1000)
                        )
                    )
                }
            } else {
                waitingOn.append(member.label)
            }
        }

        if seenBy.isEmpty, waitingOn.isEmpty, pending.isEmpty {
            return nil
        }

        return SaleTaskAudienceStatus(
            seenBy: seenBy,
            waitingOn: waitingOn,
            pending: pending,
            seenEntries: seenEntries.sorted { $0.seenAt > $1.seenAt }
        )
    }

    func reminderNotificationContext(
        for snapshot: SaleTaskLiveSnapshot?,
        taskID: String?,
        audience: [SaleTaskSnapshotAudienceMember],
        now: Date = .now
    ) -> String? {
        guard let snapshot,
              let status = audienceStatus(
                for: snapshot,
                messageID: nil,
                taskID: taskID,
                audience: audience
              ) else {
            return nil
        }

        if let latestSeenEntry = status.seenEntries.first {
            let relativeTime = relativeDateFormatter.localizedString(for: latestSeenEntry.seenAt, relativeTo: now)
            if status.waitingOn.isEmpty {
                return "Seen \(relativeTime) by \(latestSeenEntry.label)."
            }
            return "Seen \(relativeTime) by \(latestSeenEntry.label). Waiting on \(joinedLabelList(status.waitingOn))."
        }

        if !status.waitingOn.isEmpty {
            return "Waiting on \(joinedLabelList(status.waitingOn))."
        }

        if !status.pending.isEmpty {
            return "Checking \(joinedLabelList(status.pending))."
        }

        if !status.seenBy.isEmpty {
            return "Seen by everyone."
        }

        return nil
    }

    func notificationFingerprint(for viewerIDs: [String]) -> String {
        let normalizedViewerIDs = viewerIDs
            .compactMap { normalizeViewerID($0) }
            .sorted()

        return normalizedViewerIDs.map { viewerID in
            let loadedMarker = loadedViewerIDs.contains(viewerID) ? "loaded" : "pending"
            let state = statesByViewerID[viewerID]
            let messageKeys = state?.seenUrgentSnapshotKeysByMessageID
                .sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: ",") ?? ""
            let taskKeys = state?.seenUrgentSnapshotKeysByTaskID
                .sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: ",") ?? ""
            let messageTimes = state?.seenUrgentSnapshotSeenAtByMessageID
                .sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: ",") ?? ""
            let taskTimes = state?.seenUrgentSnapshotSeenAtByTaskID
                .sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: ",") ?? ""

            return [
                viewerID,
                loadedMarker,
                messageKeys,
                taskKeys,
                messageTimes,
                taskTimes
            ]
            .joined(separator: "~")
        }
        .joined(separator: "|")
    }

    private var relativeDateFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }

    private func joinedLabelList(_ labels: [String]) -> String {
        labels.joined(separator: ", ")
    }

    private func normalizeViewerID(_ viewerID: String?) -> String? {
        guard let normalizedViewerID = viewerID?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !normalizedViewerID.isEmpty else {
            return nil
        }

        return normalizedViewerID
    }

    private func normalizeMessageID(_ messageID: String?) -> String? {
        guard let normalizedMessageID = messageID?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !normalizedMessageID.isEmpty else {
            return nil
        }

        return normalizedMessageID
    }

    private func normalizeTaskID(_ taskID: String?) -> String? {
        guard let normalizedTaskID = taskID?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !normalizedTaskID.isEmpty else {
            return nil
        }

        return normalizedTaskID
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey) else {
            return
        }

        if let decoded = try? decoder.decode([String: SaleTaskSnapshotViewerState].self, from: data) {
            statesByViewerID = decoded
            loadedViewerIDs = Set(decoded.keys)
        }
    }

    private func persist() {
        guard !isEphemeral,
              let data = try? encoder.encode(statesByViewerID) else {
            return
        }

        defaults.set(data, forKey: storageKey)
    }
}

private extension SaleTaskLiveSnapshot {
    var viewerSnapshotKey: String {
        "\(tone.rawValue)|\(summary)"
    }

    var needsUrgentViewerAttention: Bool {
        let normalizedSummary = summary.lowercased()
        return tone == .critical ||
            normalizedSummary.contains("overdue") ||
            normalizedSummary.contains("follow-up") ||
            normalizedSummary.contains("follow up")
    }
}
