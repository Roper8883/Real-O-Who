//
//  Real_O_WhoApp.swift
//  Real O Who
//
//  Created by Aaron Roper on 31/3/2026.
//

import SwiftUI

@main
struct Real_O_WhoApp: App {
    @StateObject private var store: MarketplaceStore
    @StateObject private var messaging: EncryptedMessagingService
    @StateObject private var taskSnapshots: SaleTaskSnapshotSyncStore
    @StateObject private var reminders = SaleReminderService()

    init() {
        let launchConfiguration = AppLaunchConfiguration.shared
        let backendConfiguration = MarketplaceBackendConfiguration.launchDefault(launchConfiguration: launchConfiguration)
        let services = MarketplaceServiceFactory.makeLiveServices(launchConfiguration: launchConfiguration)
        let storageModeSummary =
            backendConfiguration.mode == .remotePreferred
            ? "Backend + local fallback"
            : "Local only"
        let backendEndpointSummary = backendConfiguration.baseURL?.absoluteString ?? "No backend URL"
        let remoteSyncEnabled =
            backendConfiguration.mode == .remotePreferred &&
            backendConfiguration.baseURL != nil

        _store = StateObject(
            wrappedValue: MarketplaceStore(
                launchConfiguration: launchConfiguration,
                authService: services.authService,
                listingSync: services.listingSync,
                userStateSync: services.userStateSync,
                legalProfessionalSearch: services.legalProfessionalSearch,
                saleSync: services.saleSync,
                storageModeSummary: storageModeSummary,
                backendEndpointSummary: backendEndpointSummary,
                remoteSyncEnabled: remoteSyncEnabled
            )
        )
        _messaging = StateObject(
            wrappedValue: EncryptedMessagingService(
                launchConfiguration: launchConfiguration,
                remoteSync: services.conversationSync
            )
        )
        _taskSnapshots = StateObject(
            wrappedValue: SaleTaskSnapshotSyncStore(
                launchConfiguration: launchConfiguration,
                syncService: services.taskSnapshotStateSync,
                remoteSyncEnabled: remoteSyncEnabled
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if store.legalWorkspaceSession != nil {
                    LegalWorkspaceView()
                } else if store.isAuthenticated {
                    ContentView()
                } else {
                    AuthenticationView()
                }
            }
                .environmentObject(store)
                .environmentObject(messaging)
                .environmentObject(taskSnapshots)
                .environmentObject(reminders)
                .onOpenURL { url in
                    Task {
                        await store.handleLegalWorkspaceDeepLink(url)
                    }
                }
                .task(id: taskSnapshotRefreshKey) {
                    await taskSnapshots.refresh(for: trackedTaskSnapshotViewerIDs)
                }
                .task(id: reminderSyncKey) {
                    await reminders.syncReminders(
                        isAuthenticated: store.isAuthenticated,
                        currentUser: store.isAuthenticated ? store.currentUser : nil,
                        offers: store.offers,
                        listings: store.listings,
                        taskSnapshots: taskSnapshots
                    )
                }
                .task {
                    reminders.quickCompletionHandler = { request in
                        await processQuickReminderCompletion(request)
                    }
                    reminders.quickSnoozeHandler = { request in
                        await processQuickReminderSnooze(request)
                    }
                }
                .task(id: reminders.openedNavigationTarget?.routingKey) {
                    guard let target = reminders.openedNavigationTarget else {
                        return
                    }

                    await store.handleSaleReminderTarget(target)
                    reminders.clearOpenedNavigationTarget()
                }
        }
    }

    @MainActor
    private func processQuickReminderCompletion(
        _ request: SaleReminderQuickCompletionRequest
    ) async -> SaleReminderActionFeedback? {
        guard store.isAuthenticated else {
            return nil
        }

        if store.offer(id: request.target.offerID) == nil {
            await store.handleSaleReminderTarget(request.target)
            store.consumeInboundSaleReminderTarget()
        }

        guard let outcome = store.recordReminderTimelineActivity(
            offerID: request.target.offerID,
            checklistItemID: request.target.checklistItemID,
            actionTitle: request.activityTitle,
            triggeredBy: store.currentUserID
        ),
        let listing = store.listing(id: outcome.offer.listingID),
        let buyer = store.user(id: outcome.offer.buyerID),
        let seller = store.user(id: outcome.offer.sellerID) else {
            return nil
        }

        let sender = store.currentUserID == buyer.id ? buyer : seller
        let recipient = sender.id == buyer.id ? seller : buyer
        messaging.sendMessage(
            listing: listing,
            from: sender,
            to: recipient,
            body: outcome.threadMessage,
            isSystem: true,
            saleTaskTarget: request.target
        )
        return reminderCompletionFeedback(
            for: request.target,
            activityTitle: request.activityTitle,
            offer: outcome.offer,
            currentUser: sender
        )
    }

    @MainActor
    private func processQuickReminderSnooze(
        _ request: SaleReminderSnoozeRequest
    ) async -> SaleReminderActionFeedback? {
        guard store.isAuthenticated else {
            return nil
        }

        if store.offer(id: request.target.offerID) == nil {
            await store.handleSaleReminderTarget(request.target)
            store.consumeInboundSaleReminderTarget()
        }

        guard let outcome = store.recordReminderTimelineActivity(
            offerID: request.target.offerID,
            checklistItemID: request.target.checklistItemID,
            actionTitle: "Snoozed from notification",
            snoozedUntil: request.snoozedUntil,
            triggeredBy: store.currentUserID
        ),
        let listing = store.listing(id: outcome.offer.listingID),
        let buyer = store.user(id: outcome.offer.buyerID),
        let seller = store.user(id: outcome.offer.sellerID) else {
            return nil
        }

        let sender = store.currentUserID == buyer.id ? buyer : seller
        let recipient = sender.id == buyer.id ? seller : buyer
        messaging.sendMessage(
            listing: listing,
            from: sender,
            to: recipient,
            body: outcome.threadMessage,
            isSystem: true,
            saleTaskTarget: request.target
        )
        return reminderSnoozeFeedback(
            for: request.target,
            snoozedUntil: request.snoozedUntil,
            offer: outcome.offer,
            currentUser: sender
        )
    }

    private func reminderCompletionFeedback(
        for target: SaleReminderNavigationTarget,
        activityTitle: String,
        offer: OfferRecord,
        currentUser: UserProfile
    ) -> SaleReminderActionFeedback {
        let viewerIsBuyer = currentUser.id == offer.buyerID || (
            currentUser.id != offer.sellerID && currentUser.role == .buyer
        )
        let viewerParty = viewerIsBuyer ? "Buyer" : "Seller"
        let counterpartParty = viewerIsBuyer ? "Seller" : "Buyer"

        switch target.checklistItemID {
        case "buyer-representative":
            return SaleReminderActionFeedback(
                title: "Buyer legal rep follow-up recorded",
                body: "Buyer-side legal rep progress is now visible in the deal timeline and secure messages."
            )
        case "seller-representative":
            return SaleReminderActionFeedback(
                title: "Seller legal rep follow-up recorded",
                body: "Seller-side legal rep progress is now visible in the deal timeline and secure messages."
            )
        case "contract-packet":
            if activityTitle.caseInsensitiveCompare("Contract packet follow-up completed") == .orderedSame {
                return SaleReminderActionFeedback(
                    title: "Contract packet follow-up recorded",
                    body: "Contract packet progress is now visible in the deal timeline and secure messages."
                )
            }
            return SaleReminderActionFeedback(
                title: "Contract packet issue follow-up recorded",
                body: "Contract packet progress is now visible in the deal timeline and secure messages."
            )
        case "workspace-invites":
            let inviteParty = reminderInviteFocusParty(
                offer: offer,
                currentUser: currentUser
            )
            if activityTitle.caseInsensitiveCompare("Invite sent") == .orderedSame {
                return SaleReminderActionFeedback(
                    title: "\(inviteParty) rep invite sent recorded",
                    body: "\(inviteParty)-side legal invite progress is now visible in the deal timeline and secure messages."
                )
            }
            return SaleReminderActionFeedback(
                title: "\(inviteParty) rep invite follow-up recorded",
                body: "\(inviteParty)-side legal invite progress is now visible in the deal timeline and secure messages."
            )
        case "workspace-active":
            let workspaceParty = reminderWorkspaceFocusParty(
                offer: offer,
                currentUser: currentUser
            )
            if activityTitle.caseInsensitiveCompare("Workspace access follow-up completed") == .orderedSame {
                return SaleReminderActionFeedback(
                    title: "\(workspaceParty) rep workspace access follow-up recorded",
                    body: "\(workspaceParty)-side legal workspace access is now visible in the deal timeline and secure messages."
                )
            }
            if activityTitle.caseInsensitiveCompare("Workspace receipt follow-up completed") == .orderedSame {
                return SaleReminderActionFeedback(
                    title: "\(workspaceParty) rep receipt follow-up recorded",
                    body: "\(workspaceParty)-side legal workspace acknowledgement is now visible in the deal timeline and secure messages."
                )
            }
            return SaleReminderActionFeedback(
                title: "\(workspaceParty) rep workspace follow-up recorded",
                body: "\(workspaceParty)-side legal workspace progress is now visible in the deal timeline and secure messages."
            )
        case "legal-review-pack":
            if activityTitle.caseInsensitiveCompare("Reviewed contract follow-up completed") == .orderedSame {
                return SaleReminderActionFeedback(
                    title: "Reviewed contract follow-up recorded",
                    body: "Reviewed contract progress is now visible in the deal timeline and secure messages."
                )
            }
            if activityTitle.caseInsensitiveCompare("Settlement adjustment follow-up completed") == .orderedSame {
                return SaleReminderActionFeedback(
                    title: "Settlement adjustment follow-up recorded",
                    body: "Settlement adjustment progress is now visible in the deal timeline and secure messages."
                )
            }
            let reviewPackFocus = reminderReviewPackFocus(offer: offer)
            return SaleReminderActionFeedback(
                title: "\(reviewPackFocus.title) follow-up recorded",
                body: "\(reviewPackFocus.body) is now visible in the deal timeline and secure messages."
            )
        case "contract-signatures":
            let signingParty: String
            if let packet = offer.contractPacket {
                if activityTitle.caseInsensitiveCompare("Signature confirmed") == .orderedSame {
                    if viewerIsBuyer, packet.buyerSignedAt == nil {
                        signingParty = "Buyer"
                    } else if !viewerIsBuyer, packet.sellerSignedAt == nil {
                        signingParty = "Seller"
                    } else {
                        signingParty = viewerParty
                    }
                    return SaleReminderActionFeedback(
                        title: "\(signingParty) signature confirmation recorded",
                        body: "\(signingParty) signing progress is now visible in the deal timeline and secure messages."
                    )
                }

                if viewerIsBuyer, packet.buyerSignedAt != nil, packet.sellerSignedAt == nil {
                    signingParty = counterpartParty
                } else if !viewerIsBuyer, packet.sellerSignedAt != nil, packet.buyerSignedAt == nil {
                    signingParty = counterpartParty
                } else {
                    signingParty = viewerParty
                }
            } else {
                signingParty = viewerParty
            }

            return SaleReminderActionFeedback(
                title: "\(signingParty) signature follow-up recorded",
                body: "\(signingParty) signing progress is now visible in the deal timeline and secure messages."
            )
        case "settlement-statement":
            if activityTitle.caseInsensitiveCompare("Settlement statement follow-up completed") == .orderedSame {
                return SaleReminderActionFeedback(
                    title: "Settlement statement follow-up recorded",
                    body: "Settlement statement progress is now visible in the deal timeline and secure messages."
                )
            }
            return SaleReminderActionFeedback(
                title: "Settlement statement upload follow-up recorded",
                body: "Settlement statement progress is now visible in the deal timeline and secure messages."
            )
        default:
            return SaleReminderActionFeedback(
                title: "Recorded in sale timeline",
                body: "\(activityTitle). Buyer and seller can now see this update in the deal timeline and secure messages."
            )
        }
    }

    private func reminderSnoozeFeedback(
        for target: SaleReminderNavigationTarget,
        snoozedUntil: Date,
        offer: OfferRecord,
        currentUser: UserProfile
    ) -> SaleReminderActionFeedback {
        let untilSummary = snoozedUntil.formatted(date: .abbreviated, time: .shortened)

        let title: String
        switch target.checklistItemID {
        case "buyer-representative":
            title = "Buyer legal rep follow-up snoozed"
        case "seller-representative":
            title = "Seller legal rep follow-up snoozed"
        case "workspace-invites":
            title = "\(reminderInviteFocusParty(offer: offer, currentUser: currentUser)) rep invite follow-up snoozed"
        case "workspace-active":
            title = "\(reminderWorkspaceFocusParty(offer: offer, currentUser: currentUser)) rep workspace follow-up snoozed"
        case "contract-signatures":
            title = "\(reminderSignatureFocusParty(offer: offer, currentUser: currentUser)) signature follow-up snoozed"
        case "settlement-statement":
            title = "Settlement statement upload follow-up snoozed"
        case "legal-review-pack":
            title = "\(reminderReviewPackFocus(offer: offer).title) follow-up snoozed"
        case "contract-packet":
            title = "Contract packet issue follow-up snoozed"
        default:
            title = "Reminder snoozed"
        }

        return SaleReminderActionFeedback(
            title: title,
            body: "Snoozed until \(untilSummary). This follow-up remains visible in the deal timeline and secure messages."
        )
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

    private func reminderReviewPackFocus(offer: OfferRecord) -> (title: String, body: String) {
        let hasReviewedContract = offer.documents.contains { $0.kind == .reviewedContractPDF }
        let hasSettlementAdjustment = offer.documents.contains { $0.kind == .settlementAdjustmentPDF }

        switch (hasReviewedContract, hasSettlementAdjustment) {
        case (false, true):
            return ("Reviewed contract upload", "Reviewed contract upload progress")
        case (true, false):
            return ("Settlement adjustment upload", "Settlement adjustment upload progress")
        case (false, false):
            return ("Legal review pack", "Legal review pack progress")
        case (true, true):
            return ("Legal review pack", "Legal review pack progress")
        }
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

        if viewerIsBuyer, packet.buyerSignedAt != nil, packet.sellerSignedAt == nil {
            return "Seller"
        }
        if !viewerIsBuyer, packet.sellerSignedAt != nil, packet.buyerSignedAt == nil {
            return "Buyer"
        }
        return viewerIsBuyer ? "Buyer" : "Seller"
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

    private var reminderSyncKey: String {
        guard store.isAuthenticated else {
            return "signed-out"
        }

        let relevantOffers = store.offers
            .filter { $0.buyerID == store.currentUserID || $0.sellerID == store.currentUserID }
            .sorted { left, right in
                if left.createdAt == right.createdAt {
                    return left.id.uuidString > right.id.uuidString
                }
                return left.createdAt > right.createdAt
            }

        let offerValue = relevantOffers.map { offer in
            let checklistValue = offer.settlementChecklist.map { item in
                [
                    item.id,
                    item.status.rawValue,
                    item.ownerLabel,
                    item.targetDate.map { String(Int($0.timeIntervalSince1970)) } ?? "none",
                    item.nextAction ?? "",
                    item.reminder ?? ""
                ]
                .joined(separator: "~")
            }
            .joined(separator: "^")

            return "\(offer.id.uuidString)#\(Int(offer.createdAt.timeIntervalSince1970))#\(checklistValue)"
        }
        .joined(separator: "|")

        let snapshotFingerprint = taskSnapshots.notificationFingerprint(for: trackedTaskSnapshotViewerIDs)
        return "\(store.currentUserID.uuidString)|\(offerValue)|\(snapshotFingerprint)"
    }

    private var activeTaskSnapshotViewerID: String? {
        if let session = store.legalWorkspaceSession {
            return SaleTaskSnapshotSyncStore.viewerID(forInvite: session.inviteID)
        }

        if store.isAuthenticated {
            return SaleTaskSnapshotSyncStore.viewerID(forUser: store.currentUserID)
        }

        return nil
    }

    private var trackedTaskSnapshotViewerIDs: [String] {
        var viewerIDs = Set<String>()

        if let activeTaskSnapshotViewerID {
            viewerIDs.insert(activeTaskSnapshotViewerID)
        }

        let relevantOffers: [OfferRecord]
        if let session = store.legalWorkspaceSession,
           let legalOffer = store.offer(id: session.offerID) {
            relevantOffers = [legalOffer]
        } else if store.isAuthenticated {
            relevantOffers = store.offers.filter {
                $0.buyerID == store.currentUserID || $0.sellerID == store.currentUserID
            }
        } else {
            relevantOffers = []
        }

        for offer in relevantOffers {
            for viewer in offer.taskSnapshotAudienceMembers {
                viewerIDs.insert(viewer.viewerID)
            }
        }

        return viewerIDs.sorted()
    }

    private var taskSnapshotRefreshKey: String {
        trackedTaskSnapshotViewerIDs.joined(separator: "|")
    }
}
