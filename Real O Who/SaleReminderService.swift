import Combine
import Foundation
import UserNotifications

struct SaleReminderNavigationTarget: Hashable, Codable, Sendable {
    let listingID: UUID
    let offerID: UUID
    let checklistItemID: String

    static func saleTask(
        listingID: UUID,
        offerID: UUID,
        checklistItemID: String
    ) -> Self {
        Self(
            listingID: listingID,
            offerID: offerID,
            checklistItemID: checklistItemID
        )
    }

    var routingKey: String {
        "\(listingID.uuidString)|\(offerID.uuidString)|\(checklistItemID)"
    }

    var notificationActionTitle: String {
        switch checklistItemID {
        case "buyer-representative":
            "Choose Buyer Legal Rep"
        case "seller-representative":
            "Choose Seller Legal Rep"
        case "contract-packet":
            "Open Contract Packet"
        case "workspace-invites":
            "Manage Legal Invites"
        case "workspace-active":
            "Open Legal Workspace"
        case "legal-review-pack":
            "Open Legal Review"
        case "contract-signatures":
            "Open Contract Signing"
        case "settlement-statement":
            "Open Settlement Statement"
        default:
            "Open Sale Task"
        }
    }

    var notificationCategoryIdentifier: String {
        "real-o-who.sale.reminder.category.\(checklistItemID)"
    }
}

struct SaleReminderQuickCompletionRequest: Hashable, Sendable {
    let target: SaleReminderNavigationTarget
    let activityTitle: String
}

struct SaleReminderSnoozeRequest: Hashable, Sendable {
    let target: SaleReminderNavigationTarget
    let snoozedUntil: Date
}

struct SaleReminderActionFeedback: Hashable, Sendable {
    let title: String
    let body: String
}

@MainActor
final class SaleReminderService: NSObject, ObservableObject {
    struct ReminderActivityEntry: Identifiable, Codable, Hashable, Sendable {
        var id: UUID
        var createdAt: Date
        var title: String

        init(id: UUID = UUID(), createdAt: Date = .now, title: String) {
            self.id = id
            self.createdAt = createdAt
            self.title = title
        }
    }

    private struct ScheduledReminder: Hashable {
        var identifier: String
        var target: SaleReminderNavigationTarget
        var title: String
        var subtitle: String
        var body: String
        var actionTitle: String
        var categoryIdentifier: String
        var completionActionTitle: String?
        var completionActivityTitle: String?
        var triggerDate: Date
        var priority: Int
    }

    @Published private(set) var openedNavigationTarget: SaleReminderNavigationTarget?

    private let center: UNUserNotificationCenter
    private let defaults: UserDefaults
    var quickCompletionHandler: (@MainActor @Sendable (SaleReminderQuickCompletionRequest) async -> SaleReminderActionFeedback?)?
    var quickSnoozeHandler: (@MainActor @Sendable (SaleReminderSnoozeRequest) async -> SaleReminderActionFeedback?)?
    nonisolated private static let identifierPrefix = "real-o-who.sale.reminder."
    nonisolated private static let feedbackIdentifierPrefix = "real-o-who.sale.reminder.feedback."
    nonisolated private static let fingerprintKey = "real-o-who.sale.reminder.fingerprint"
    nonisolated private static let snoozeMapKey = "real-o-who.sale.reminder.snoozes"
    nonisolated private static let activityMapKey = "real-o-who.sale.reminder.activity"
    nonisolated private static let listingIDUserInfoKey = "listing_id"
    nonisolated private static let offerIDUserInfoKey = "offer_id"
    nonisolated private static let checklistItemIDUserInfoKey = "checklist_item_id"
    nonisolated private static let completionActivityTitleUserInfoKey = "completion_activity_title"
    nonisolated private static let openActionIdentifier = "real-o-who.sale.reminder.action.open"
    nonisolated private static let completeActionIdentifier = "real-o-who.sale.reminder.action.complete"
    nonisolated private static let snoozeActionIdentifier = "real-o-who.sale.reminder.action.snooze"

    init(
        center: UNUserNotificationCenter = .current(),
        defaults: UserDefaults = .standard
    ) {
        self.center = center
        self.defaults = defaults
        super.init()
        center.delegate = self
        center.setNotificationCategories([])
    }

    func syncReminders(
        isAuthenticated: Bool,
        currentUser: UserProfile?,
        offers: [OfferRecord],
        listings: [PropertyListing],
        taskSnapshots: SaleTaskSnapshotSyncStore
    ) async {
        guard isAuthenticated, let currentUser else {
            await clearAllReminders()
            return
        }

        removeExpiredSnoozes()
        let listingsByID = Dictionary(uniqueKeysWithValues: listings.map { ($0.id, $0) })
        let reminders = offers
            .filter { $0.buyerID == currentUser.id || $0.sellerID == currentUser.id }
            .flatMap { offer in
                reminderPayloads(
                    for: offer,
                    listing: listingsByID[offer.listingID],
                    currentUser: currentUser,
                    taskSnapshots: taskSnapshots
                )
            }
            .sorted { left, right in
                if left.priority == right.priority {
                    return left.triggerDate < right.triggerDate
                }
                return left.priority < right.priority
            }
            .prefix(6)

        let fingerprint = Self.fingerprint(for: currentUser.id, reminders: Array(reminders))
        let pendingIDs = await pendingReminderIdentifiers()

        guard defaults.string(forKey: Self.fingerprintKey) != fingerprint ||
                Set(pendingIDs) != Set(reminders.map(\.identifier)) else {
            return
        }

        guard await ensureAuthorization() else {
            defaults.removeObject(forKey: Self.fingerprintKey)
            await removePendingReminders()
            return
        }

        await removePendingReminders()
        center.setNotificationCategories(Self.notificationCategories(for: Array(reminders)))

        for reminder in reminders {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.subtitle = reminder.subtitle
            content.body = reminder.body
            content.sound = .default
            content.threadIdentifier = "real-o-who.sale.reminders"
            content.categoryIdentifier = reminder.categoryIdentifier
            content.userInfo = [
                Self.listingIDUserInfoKey: reminder.target.listingID.uuidString,
                Self.offerIDUserInfoKey: reminder.target.offerID.uuidString,
                Self.checklistItemIDUserInfoKey: reminder.target.checklistItemID,
                Self.completionActivityTitleUserInfoKey: reminder.completionActivityTitle ?? ""
            ]

            let interval = reminder.triggerDate.timeIntervalSinceNow
            let trigger: UNNotificationTrigger
            if interval <= 60 {
                trigger = UNTimeIntervalNotificationTrigger(
                    timeInterval: max(5, interval),
                    repeats: false
                )
            } else {
                let components = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute, .second],
                    from: reminder.triggerDate
                )
                trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            }

            let request = UNNotificationRequest(
                identifier: reminder.identifier,
                content: content,
                trigger: trigger
            )

            do {
                try await center.add(request)
            } catch {
                continue
            }
        }

        defaults.set(fingerprint, forKey: Self.fingerprintKey)
    }

    func clearAllReminders() async {
        defaults.removeObject(forKey: Self.fingerprintKey)
        await removePendingReminders()
    }

    func clearReminder(
        for target: SaleReminderNavigationTarget,
        actionTitle: String? = nil
    ) async {
        let identifier = Self.identifier(for: target)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
        updateSnoozeMap { snoozes in
            snoozes.removeValue(forKey: identifier)
        }
        if let actionTitle {
            appendActivityEntry(
                ReminderActivityEntry(title: actionTitle),
                for: identifier
            )
        }
        defaults.removeObject(forKey: Self.fingerprintKey)
    }

    func snoozeReminder(
        for target: SaleReminderNavigationTarget,
        duration: TimeInterval,
        title: String = "Snoozed for 24 hours",
        snoozedUntil explicitDate: Date? = nil
    ) async {
        let identifier = Self.identifier(for: target)
        let snoozedUntil = explicitDate ?? Date().addingTimeInterval(duration)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
        updateSnoozeMap { snoozes in
            snoozes[identifier] = snoozedUntil
        }
        appendActivityEntry(
            ReminderActivityEntry(
                title: "\(title) until \(snoozedUntil.formatted(date: .abbreviated, time: .shortened))"
            ),
            for: identifier
        )
        defaults.removeObject(forKey: Self.fingerprintKey)
    }

    func reminderActivity(for target: SaleReminderNavigationTarget) -> [ReminderActivityEntry] {
        let identifier = Self.identifier(for: target)
        return activityMap()[identifier, default: []]
            .sorted { $0.createdAt > $1.createdAt }
    }

    func snoozedUntil(for target: SaleReminderNavigationTarget) -> Date? {
        let identifier = Self.identifier(for: target)
        guard let snoozedUntil = snoozeMap()[identifier],
              snoozedUntil > .now else {
            return nil
        }

        return snoozedUntil
    }

    private func reminderPayloads(
        for offer: OfferRecord,
        listing: PropertyListing?,
        currentUser: UserProfile,
        taskSnapshots: SaleTaskSnapshotSyncStore
    ) -> [ScheduledReminder] {
        let listingTitle = listing?.title ?? "Private sale workspace"
        let snoozes = snoozeMap()

        return offer.settlementChecklist.compactMap { item in
            guard item.status != .completed else {
                return nil
            }

            let target = SaleReminderNavigationTarget(
                listingID: offer.listingID,
                offerID: offer.id,
                checklistItemID: item.id
            )
            let identifier = Self.identifier(for: target)
            if let snoozedUntil = snoozes[identifier], snoozedUntil > .now {
                return nil
            }

            let triggerDate: Date?
            if item.isOverdue || item.reminderSummary != nil {
                triggerDate = .now.addingTimeInterval(15)
            } else if let targetDate = item.targetDate {
                triggerDate = max(targetDate, .now.addingTimeInterval(15))
            } else if item.isDueSoon {
                triggerDate = .now.addingTimeInterval(60 * 30)
            } else {
                triggerDate = nil
            }

            guard let triggerDate else {
                return nil
            }

            let audienceContext = taskSnapshots.reminderNotificationContext(
                for: offer.liveTaskSnapshot(for: item.id),
                taskID: offer.taskSnapshotID(for: item.id),
                audience: offer.taskSnapshotAudienceMembers
            )
            let body = item.reminderSummary ?? item.nextActionSummary ?? item.detail
            let trailingContext = audienceContext ?? item.ownerSummary
            let actionTitle = reminderActionTitle(
                for: item,
                offer: offer,
                currentUser: currentUser
            )
            let completionAction = reminderQuickCompletionDescriptor(
                for: item,
                offer: offer,
                currentUser: currentUser
            )

            return ScheduledReminder(
                identifier: identifier,
                target: target,
                title: item.title,
                subtitle: listingTitle,
                body: "\(body) \(trailingContext)",
                actionTitle: actionTitle,
                categoryIdentifier: "\(identifier).category",
                completionActionTitle: completionAction?.actionTitle,
                completionActivityTitle: completionAction?.activityTitle,
                triggerDate: triggerDate,
                priority: priority(for: item)
            )
        }
    }

    private func priority(for item: SaleChecklistItem) -> Int {
        if item.isOverdue { return 0 }
        if item.reminderSummary != nil { return 1 }
        if item.isDueSoon { return 2 }
        switch item.status {
        case .inProgress:
            return 3
        case .pending:
            return 4
        case .completed:
            return 5
        }
    }

    private func ensureAuthorization() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .badge, .sound])
            } catch {
                return false
            }
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    private func pendingReminderIdentifiers() async -> [String] {
        let requests = await center.pendingRequests()
        return requests
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.identifierPrefix) }
    }

    private func removePendingReminders() async {
        let identifiers = await pendingReminderIdentifiers()
        guard !identifiers.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private static func fingerprint(
        for userID: UUID,
        reminders: [ScheduledReminder]
    ) -> String {
        let payload = reminders.map { reminder in
            [
                reminder.identifier,
                reminder.title,
                reminder.subtitle,
                reminder.body,
                reminder.actionTitle,
                String(Int(reminder.triggerDate.timeIntervalSince1970))
            ]
            .joined(separator: "~")
        }
        .joined(separator: "|")

        return "\(userID.uuidString)|\(payload)"
    }

    private static func identifier(for target: SaleReminderNavigationTarget) -> String {
        "\(identifierPrefix)\(target.offerID.uuidString).\(target.checklistItemID)"
    }

    private func snoozeMap() -> [String: Date] {
        guard let data = defaults.data(forKey: Self.snoozeMapKey),
              let decoded = try? JSONDecoder().decode([String: Date].self, from: data) else {
            return [:]
        }

        return decoded
    }

    private func updateSnoozeMap(_ update: (inout [String: Date]) -> Void) {
        var current = snoozeMap()
        update(&current)
        if let data = try? JSONEncoder().encode(current) {
            defaults.set(data, forKey: Self.snoozeMapKey)
        }
    }

    private func removeExpiredSnoozes() {
        updateSnoozeMap { snoozes in
            snoozes = snoozes.filter { $0.value > .now }
        }
    }

    private func activityMap() -> [String: [ReminderActivityEntry]] {
        guard let data = defaults.data(forKey: Self.activityMapKey),
              let decoded = try? JSONDecoder().decode([String: [ReminderActivityEntry]].self, from: data) else {
            return [:]
        }

        return decoded
    }

    private func appendActivityEntry(
        _ entry: ReminderActivityEntry,
        for identifier: String
    ) {
        var activity = activityMap()
        var entries = activity[identifier, default: []]
        entries.insert(entry, at: 0)
        activity[identifier] = Array(entries.prefix(6))
        if let data = try? JSONEncoder().encode(activity) {
            defaults.set(data, forKey: Self.activityMapKey)
        }
    }

    private func reminderActionTitle(
        for item: SaleChecklistItem,
        offer: OfferRecord,
        currentUser: UserProfile
    ) -> String {
        let viewerIsBuyer = currentUser.id == offer.buyerID || (
            currentUser.id != offer.sellerID && currentUser.role == .buyer
        )
        let needsFollowUp = item.isOverdue || item.reminderSummary != nil
        let ownInviteRole: LegalInviteRole = viewerIsBuyer ? .buyerRepresentative : .sellerRepresentative
        let counterpartInviteRole: LegalInviteRole = viewerIsBuyer ? .sellerRepresentative : .buyerRepresentative
        let ownInvite = latestInvite(for: ownInviteRole, in: offer)
        let counterpartInvite = latestInvite(for: counterpartInviteRole, in: offer)
        let hasReviewedContract = offer.documents.contains { $0.kind == .reviewedContractPDF }
        let hasSettlementAdjustment = offer.documents.contains { $0.kind == .settlementAdjustmentPDF }
        let hasSettlementStatement = offer.documents.contains { $0.kind == .settlementStatementPDF }
        let hasSignedContract = offer.documents.contains { $0.kind == .signedContractPDF }

        switch item.id {
        case "buyer-representative":
            if viewerIsBuyer {
                return offer.buyerLegalSelection == nil ? "Choose Your Legal Rep" : "Review Your Legal Rep"
            }
            return offer.buyerLegalSelection == nil
                ? (needsFollowUp ? "Follow Up With Buyer" : "Check Buyer Legal Rep")
                : "Review Buyer Legal Rep"

        case "seller-representative":
            if !viewerIsBuyer {
                return offer.sellerLegalSelection == nil ? "Choose Your Legal Rep" : "Review Your Legal Rep"
            }
            return offer.sellerLegalSelection == nil
                ? (needsFollowUp ? "Follow Up With Seller" : "Check Seller Legal Rep")
                : "Review Seller Legal Rep"

        case "contract-packet":
            if offer.contractPacket != nil {
                return "Review Contract Packet"
            }
            return needsFollowUp ? "Follow Up On Contract Packet" : "Check Contract Packet Status"

        case "workspace-invites":
            if let ownInvite {
                if ownInvite.isUnavailable {
                    return "Refresh Your Legal Invite"
                }
                if !ownInvite.hasBeenShared {
                    return "Send Your Legal Invite"
                }
                if ownInvite.needsFollowUp {
                    return "Follow Up With Your Legal Rep"
                }
            }
            if let counterpartInvite {
                if counterpartInvite.isUnavailable {
                    return viewerIsBuyer ? "Check Seller Rep Invite" : "Check Buyer Rep Invite"
                }
                if !counterpartInvite.hasBeenShared {
                    return viewerIsBuyer ? "Check Seller Rep Invite" : "Check Buyer Rep Invite"
                }
                if counterpartInvite.needsFollowUp {
                    return viewerIsBuyer ? "Follow Up With Seller Rep" : "Follow Up With Buyer Rep"
                }
            }
            return "Manage Legal Invites"

        case "workspace-active":
            if let ownInvite {
                if ownInvite.isActivated == false {
                    return "Follow Up With Your Legal Rep"
                }
                if ownInvite.isAcknowledged == false {
                    return "Check Your Rep Receipt"
                }
            }
            if let counterpartInvite {
                if counterpartInvite.isActivated == false {
                    return viewerIsBuyer ? "Follow Up With Seller Rep" : "Follow Up With Buyer Rep"
                }
                if counterpartInvite.isAcknowledged == false {
                    return viewerIsBuyer ? "Check Seller Rep Receipt" : "Check Buyer Rep Receipt"
                }
            }
            return "Open Legal Workspace"

        case "legal-review-pack":
            if hasReviewedContract && hasSettlementAdjustment {
                return "Review Legal Review Pack"
            }
            return needsFollowUp ? "Follow Up On Legal Review" : "Check Legal Review Pack"

        case "contract-signatures":
            guard let packet = offer.contractPacket else {
                return "Check Signing Status"
            }
            if packet.isFullySigned {
                return "Review Signed Contract"
            }
            if viewerIsBuyer {
                if packet.buyerSignedAt == nil {
                    return "Sign Contract Now"
                }
                if packet.sellerSignedAt == nil {
                    return needsFollowUp ? "Follow Up With Seller" : "Check Seller Signature"
                }
            } else {
                if packet.sellerSignedAt == nil {
                    return "Sign Contract Now"
                }
                if packet.buyerSignedAt == nil {
                    return needsFollowUp ? "Follow Up With Buyer" : "Check Buyer Signature"
                }
            }
            return "Open Contract Signing"

        case "settlement-statement":
            if hasSettlementStatement {
                return "Review Settlement Statement"
            }
            if offer.contractPacket?.isFullySigned == true || hasSignedContract {
                return needsFollowUp ? "Follow Up On Settlement" : "Check Settlement Status"
            }
            return "Open Settlement Step"

        default:
            return "Open Sale Task"
        }
    }

    private func latestInvite(
        for role: LegalInviteRole,
        in offer: OfferRecord
    ) -> SaleWorkspaceInvite? {
        offer.invites
            .filter { $0.role == role }
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }

    private func reminderInviteFocusParty(
        offer: OfferRecord,
        currentUser: UserProfile
    ) -> String {
        let viewerIsBuyer = currentUser.id == offer.buyerID || (
            currentUser.id != offer.sellerID && currentUser.role == .buyer
        )
        let ownRole: LegalInviteRole = viewerIsBuyer ? .buyerRepresentative : .sellerRepresentative
        let counterpartRole: LegalInviteRole = viewerIsBuyer ? .sellerRepresentative : .buyerRepresentative

        let ownInvite = latestInvite(for: ownRole, in: offer)
        if let ownInvite,
           ownInvite.isUnavailable || ownInvite.hasBeenShared == false || ownInvite.needsFollowUp {
            return viewerIsBuyer ? "Buyer" : "Seller"
        }

        let counterpartInvite = latestInvite(for: counterpartRole, in: offer)
        if let counterpartInvite,
           counterpartInvite.isUnavailable || counterpartInvite.hasBeenShared == false || counterpartInvite.needsFollowUp {
            return viewerIsBuyer ? "Seller" : "Buyer"
        }

        return viewerIsBuyer ? "Buyer" : "Seller"
    }

    private func reminderWorkspaceFocusParty(
        offer: OfferRecord,
        currentUser: UserProfile
    ) -> String {
        let viewerIsBuyer = currentUser.id == offer.buyerID || (
            currentUser.id != offer.sellerID && currentUser.role == .buyer
        )
        let ownRole: LegalInviteRole = viewerIsBuyer ? .buyerRepresentative : .sellerRepresentative
        let counterpartRole: LegalInviteRole = viewerIsBuyer ? .sellerRepresentative : .buyerRepresentative

        let ownInvite = latestInvite(for: ownRole, in: offer)
        if let ownInvite,
           ownInvite.isActivated == false || ownInvite.isAcknowledged == false {
            return viewerIsBuyer ? "Buyer" : "Seller"
        }

        let counterpartInvite = latestInvite(for: counterpartRole, in: offer)
        if let counterpartInvite,
           counterpartInvite.isActivated == false || counterpartInvite.isAcknowledged == false {
            return viewerIsBuyer ? "Seller" : "Buyer"
        }

        return viewerIsBuyer ? "Buyer" : "Seller"
    }

    private func reminderSignatureFocusParty(
        offer: OfferRecord,
        currentUser: UserProfile
    ) -> String {
        let viewerIsBuyer = currentUser.id == offer.buyerID || (
            currentUser.id != offer.sellerID && currentUser.role == .buyer
        )
        guard let packet = offer.contractPacket else {
            return viewerIsBuyer ? "Buyer" : "Seller"
        }

        switch (viewerIsBuyer, packet.buyerSignedAt != nil, packet.sellerSignedAt != nil) {
        case (true, true, false):
            return "Seller"
        case (false, false, true):
            return "Buyer"
        case (true, _, _):
            return "Buyer"
        default:
            return "Seller"
        }
    }

    private func reminderQuickCompletionDescriptor(
        for item: SaleChecklistItem,
        offer: OfferRecord,
        currentUser: UserProfile
    ) -> (actionTitle: String, activityTitle: String)? {
        let viewerIsBuyer = currentUser.id == offer.buyerID || (
            currentUser.id != offer.sellerID && currentUser.role == .buyer
        )
        let ownInviteRole: LegalInviteRole = viewerIsBuyer ? .buyerRepresentative : .sellerRepresentative
        let counterpartInviteRole: LegalInviteRole = viewerIsBuyer ? .sellerRepresentative : .buyerRepresentative
        let ownInvite = latestInvite(for: ownInviteRole, in: offer)
        let counterpartInvite = latestInvite(for: counterpartInviteRole, in: offer)
        let inviteParty = reminderInviteFocusParty(offer: offer, currentUser: currentUser)
        let workspaceParty = reminderWorkspaceFocusParty(offer: offer, currentUser: currentUser)
        let signatureParty = reminderSignatureFocusParty(offer: offer, currentUser: currentUser)

        switch item.id {
        case "buyer-representative", "seller-representative":
            let party = item.id == "buyer-representative" ? "Buyer" : "Seller"
            return ("Mark \(party) Rep Follow-Up Done", "Representative follow-up completed")

        case "contract-packet":
            guard offer.contractPacket == nil, offer.isLegallyCoordinated else {
                return nil
            }
            return ("Mark Contract Packet Follow-Up Done", "Contract packet follow-up completed")

        case "workspace-invites":
            if ownInvite?.isUnavailable == true {
                return nil
            }
            if ownInvite != nil && ownInvite?.hasBeenShared == false {
                return ("Mark \(inviteParty) Rep Invite Sent", "Invite sent")
            }
            return ("Mark \(inviteParty) Rep Invite Follow-Up Done", "Invite follow-up completed")

        case "workspace-active":
            if let ownInvite {
                if ownInvite.isActivated == false {
                    return ("Mark \(workspaceParty) Rep Access Follow-Up Done", "Workspace access follow-up completed")
                }
                if ownInvite.isAcknowledged == false {
                    return ("Mark \(workspaceParty) Rep Receipt Follow-Up Done", "Workspace receipt follow-up completed")
                }
            }
            if let counterpartInvite {
                if counterpartInvite.isActivated == false {
                    return ("Mark \(workspaceParty) Rep Access Follow-Up Done", "Workspace access follow-up completed")
                }
                if counterpartInvite.isAcknowledged == false {
                    return ("Mark \(workspaceParty) Rep Receipt Follow-Up Done", "Workspace receipt follow-up completed")
                }
            }
            return nil

        case "legal-review-pack":
            if !offer.documents.contains(where: { $0.kind == .reviewedContractPDF }) {
                return ("Mark Reviewed Contract Follow-Up Done", "Reviewed contract follow-up completed")
            }
            if !offer.documents.contains(where: { $0.kind == .settlementAdjustmentPDF }) {
                return ("Mark Settlement Adjustment Follow-Up Done", "Settlement adjustment follow-up completed")
            }
            return ("Mark Review Follow-Up Done", "Legal review follow-up completed")

        case "contract-signatures":
            guard let packet = offer.contractPacket else {
                return nil
            }
            if viewerIsBuyer, packet.buyerSignedAt == nil {
                return ("Mark Buyer Signature Confirmed", "Signature confirmed")
            }
            if !viewerIsBuyer, packet.sellerSignedAt == nil {
                return ("Mark Seller Signature Confirmed", "Signature confirmed")
            }
            return ("Mark \(signatureParty) Signature Follow-Up Done", "Signature follow-up completed")

        case "settlement-statement":
            if offer.documents.contains(where: { $0.kind == .settlementStatementPDF }) == false {
                return ("Mark Settlement Statement Follow-Up Done", "Settlement statement follow-up completed")
            }
            return ("Mark Settlement Follow-Up Done", "Settlement follow-up completed")

        default:
            return nil
        }
    }

    func clearOpenedNavigationTarget() {
        openedNavigationTarget = nil
    }

    nonisolated private static func navigationTarget(
        from request: UNNotificationRequest
    ) -> SaleReminderNavigationTarget? {
        let userInfo = request.content.userInfo
        guard
            let listingIDValue = userInfo[listingIDUserInfoKey] as? String,
            let offerIDValue = userInfo[offerIDUserInfoKey] as? String,
            let checklistItemID = userInfo[checklistItemIDUserInfoKey] as? String,
            let listingID = UUID(uuidString: listingIDValue),
            let offerID = UUID(uuidString: offerIDValue)
        else {
            return nil
        }

        return SaleReminderNavigationTarget(
            listingID: listingID,
            offerID: offerID,
            checklistItemID: checklistItemID
        )
    }

    nonisolated private static func quickCompletionRequest(
        from request: UNNotificationRequest
    ) -> SaleReminderQuickCompletionRequest? {
        guard
            let target = navigationTarget(from: request),
            let activityTitle = request.content.userInfo[completionActivityTitleUserInfoKey] as? String,
            activityTitle.isEmpty == false
        else {
            return nil
        }

        return SaleReminderQuickCompletionRequest(
            target: target,
            activityTitle: activityTitle
        )
    }

    private func postActionFeedback(
        for request: UNNotificationRequest,
        title: String,
        body: String
    ) async {
        guard let target = Self.navigationTarget(from: request) else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = request.content.subtitle
        content.body = body
        content.threadIdentifier = "real-o-who.sale.reminder.feedback"
        content.userInfo = [
            Self.listingIDUserInfoKey: target.listingID.uuidString,
            Self.offerIDUserInfoKey: target.offerID.uuidString,
            Self.checklistItemIDUserInfoKey: target.checklistItemID
        ]

        let feedbackRequest = UNNotificationRequest(
            identifier: "\(Self.feedbackIdentifierPrefix)\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        try? await center.add(feedbackRequest)
    }
}

extension SaleReminderService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        if notification.request.identifier.hasPrefix(Self.identifierPrefix) {
            return [.banner, .badge, .sound, .list]
        }

        if notification.request.identifier.hasPrefix(Self.feedbackIdentifierPrefix) {
            return [.banner, .list]
        }

        return []
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let target = Self.navigationTarget(from: response.notification.request) else {
            return
        }

        switch response.actionIdentifier {
        case Self.completeActionIdentifier:
            guard let request = Self.quickCompletionRequest(from: response.notification.request) else {
                return
            }
            let handler = await MainActor.run { quickCompletionHandler }
            let feedback: SaleReminderActionFeedback? = if let handler {
                await handler(request)
            } else {
                nil
            }
            if let feedback {
                await self.clearReminder(
                    for: request.target,
                    actionTitle: request.activityTitle
                )
                await self.postActionFeedback(
                    for: response.notification.request,
                    title: feedback.title,
                    body: feedback.body
                )
            }
        case Self.snoozeActionIdentifier:
            let snoozedUntil = Date().addingTimeInterval(60 * 60 * 24)
            let handler = await MainActor.run { quickSnoozeHandler }
            let feedback: SaleReminderActionFeedback? = if let handler {
                await handler(
                    SaleReminderSnoozeRequest(
                        target: target,
                        snoozedUntil: snoozedUntil
                    )
                )
            } else {
                nil
            }
            await self.snoozeReminder(
                for: target,
                duration: 60 * 60 * 24,
                title: "Snoozed for 24 hours from notification",
                snoozedUntil: snoozedUntil
            )
            if let feedback {
                await self.postActionFeedback(
                    for: response.notification.request,
                    title: feedback.title,
                    body: feedback.body
                )
            }
        case Self.openActionIdentifier, UNNotificationDefaultActionIdentifier:
            await MainActor.run {
                openedNavigationTarget = target
            }
        default:
            return
        }
    }
}

private extension SaleReminderService {
    private static func notificationCategories(for reminders: [ScheduledReminder]) -> Set<UNNotificationCategory> {
        return Set(
            reminders.map { reminder in
                return UNNotificationCategory(
                    identifier: reminder.categoryIdentifier,
                    actions: [
                        UNNotificationAction(
                            identifier: openActionIdentifier,
                            title: reminder.actionTitle,
                            options: [.foreground]
                        ),
                    ] + (
                        reminder.completionActionTitle.map { title in
                            [
                                UNNotificationAction(
                                    identifier: completeActionIdentifier,
                                    title: title,
                                    options: []
                                )
                            ]
                        } ?? []
                    ) + [
                        UNNotificationAction(
                            identifier: snoozeActionIdentifier,
                            title: "Snooze 24h",
                            options: []
                        )
                    ],
                    intentIdentifiers: [],
                    options: [.customDismissAction]
                )
            }
        )
    }
}

private extension UNUserNotificationCenter {
    func pendingRequests() async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
