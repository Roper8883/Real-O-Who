import SwiftUI
import UniformTypeIdentifiers

struct LegalWorkspaceView: View {
    @EnvironmentObject private var store: MarketplaceStore
    @EnvironmentObject private var messaging: EncryptedMessagingService

    @State private var preparedDocument: PreparedSaleDocument?
    @State private var notice: String?
    @State private var pendingUploadKind: SaleDocumentKind?

    var body: some View {
        NavigationStack {
            ScrollView {
                if let session = store.legalWorkspaceSession,
                   let listing = store.legalWorkspaceListing,
                   let offer = store.legalWorkspaceOffer,
                   let invite = store.legalWorkspaceInvite {
                    VStack(alignment: .leading, spacing: 20) {
                        headerCard(session: session, listing: listing, invite: invite)
                        propertyCard(listing: listing, offer: offer)
                        inviteStatusCard(invite: invite)
                        checklistCard(offer: offer)
                        actionsCard(listing: listing, offer: offer, invite: invite)
                        documentsCard(listing: listing, offer: offer)
                        updatesCard(offer: offer)
                    }
                    .padding(20)
                } else {
                    missingWorkspaceCard
                        .padding(20)
                }
            }
            .background(
                AppTheme.pageBackground
                .ignoresSafeArea()
            )
            .navigationTitle("Legal Workspace")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Exit") {
                        store.closeLegalWorkspace()
                    }
                }
            }
            .sheet(item: $preparedDocument) { document in
                SaleDocumentPreviewSheet(document: document)
            }
            .fileImporter(
                isPresented: Binding(
                    get: { pendingUploadKind != nil },
                    set: { isPresented in
                        if !isPresented {
                            pendingUploadKind = nil
                        }
                    }
                ),
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                handleImportedPDF(result)
            }
            .safeAreaInset(edge: .bottom) {
                if let notice {
                    Text(notice)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color(red: 0.05, green: 0.34, blue: 0.39))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(red: 0.90, green: 0.97, blue: 0.97))
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                }
            }
        }
    }

    private func headerCard(
        session: LegalWorkspaceSession,
        listing: PropertyListing,
        invite: SaleWorkspaceInvite
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(session.professionalName)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
            Text(invite.role.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.92))
            Text(listing.address.fullLine)
                .font(.footnote)
                .foregroundStyle(Color.white.opacity(0.88))

            HStack(spacing: 10) {
                legalTag(invite.shareCode)
                legalTag(invite.professionalSpecialty)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.04, green: 0.22, blue: 0.32),
                            Color(red: 0.10, green: 0.58, blue: 0.57),
                            Color(red: 0.39, green: 0.80, blue: 0.93)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    private func propertyCard(
        listing: PropertyListing,
        offer: OfferRecord
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sale summary")
                .font(.headline)
            Text(listing.title)
                .font(.title3.weight(.semibold))
            Text(listing.summary)
                .foregroundStyle(.secondary)
            Divider()
            workspaceMetric(label: "Offer", value: legalCurrency(offer.amount))
            workspaceMetric(label: "Status", value: offer.listingStatus.title)
            workspaceMetric(label: "Conditions", value: offer.conditions)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(workspacePanel)
    }

    private func inviteStatusCard(invite: SaleWorkspaceInvite) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Workspace status")
                .font(.headline)
            Text("Invite created \(legalShortDate(invite.createdAt)) by \(invite.generatedByName).")
                .foregroundStyle(.secondary)
            if let activatedAt = invite.activatedAt {
                Text("First opened \(legalShortDate(activatedAt))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(red: 0.07, green: 0.46, blue: 0.48))
            }
            if let revokedAt = invite.revokedAt {
                Text("Invite revoked \(legalShortDate(revokedAt))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
            }
            if let acknowledgedAt = invite.acknowledgedAt {
                Text("Acknowledged \(legalShortDate(acknowledgedAt))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(red: 0.07, green: 0.46, blue: 0.48))
            } else {
                Text("Waiting for acknowledgement")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(
                invite.isRevoked
                    ? "Invite access has been revoked. Request a fresh invite from the buyer or seller."
                    : invite.isExpired
                    ? "Invite expired \(legalShortDate(invite.expiresAt)). Request a fresh invite from the buyer or seller."
                    : "Invite valid until \(legalShortDate(invite.expiresAt))."
            )
            .font(.footnote.weight(.medium))
            .foregroundStyle(invite.isUnavailable ? Color.red : .secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(workspacePanel)
    }

    private func actionsCard(
        listing: PropertyListing,
        offer: OfferRecord,
        invite: SaleWorkspaceInvite
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Legal actions")
                .font(.headline)
            Text("Acknowledge the handoff, then upload the reviewed contract or settlement adjustments back into the shared sale workspace.")
                .foregroundStyle(.secondary)

            Button(invite.isAcknowledged ? "Receipt Recorded" : "Acknowledge Receipt") {
                guard let outcome = store.acknowledgeLegalWorkspaceInvite() else { return }
                relayLegalUpdate(outcome: outcome, listing: listing, offer: offer, invite: invite)
                notice = outcome.noticeMessage
            }
            .buttonStyle(.borderedProminent)
            .disabled(invite.isAcknowledged || invite.isUnavailable)

            Button("Attach Reviewed Contract PDF") {
                pendingUploadKind = .reviewedContractPDF
            }
            .buttonStyle(.bordered)
            .disabled(invite.isUnavailable)

            Button("Attach Settlement Adjustment PDF") {
                pendingUploadKind = .settlementAdjustmentPDF
            }
            .buttonStyle(.bordered)
            .disabled(invite.isUnavailable)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(workspacePanel)
    }

    private func checklistCard(offer: OfferRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settlement checklist")
                .font(.headline)
            Text("The buyer, seller, and both legal reps can all work from the same live milestone list.")
                .foregroundStyle(.secondary)
            SaleChecklistContent(items: offer.settlementChecklist)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(workspacePanel)
    }

    private func documentsCard(
        listing: PropertyListing,
        offer: OfferRecord
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shared sale documents")
                .font(.headline)
            Text("Contract, rates, ID, and legal review PDFs stay attached to this sale so every party works from the latest version.")
                .foregroundStyle(.secondary)

            ForEach(store.saleDocuments(for: offer.id)) { document in
                VStack(alignment: .leading, spacing: 10) {
                    Text(document.title)
                        .font(.subheadline.weight(.semibold))
                    Text(document.summary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("\(document.fileName) • Added \(legalShortDate(document.createdAt)) by \(document.uploadedByName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Preview PDF") {
                        previewDocument(listing: listing, offer: offer, document: document)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AppTheme.cardBackground)
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(workspacePanel)
    }

    private func updatesCard(offer: OfferRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sale timeline")
                .font(.headline)

            ForEach(offer.updates.prefix(6)) { update in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label(update.kind.badgeTitle, systemImage: update.kind.symbolName)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(update.kind == .reminder ? Color.orange.opacity(0.14) : Color(red: 0.0, green: 0.45, blue: 0.56).opacity(0.14))
                            )
                            .foregroundStyle(update.kind == .reminder ? Color.orange : Color(red: 0.0, green: 0.45, blue: 0.56))

                        if let checklistItemID = update.checklistItemID,
                           let liveSnapshot = offer.liveTaskSnapshot(for: checklistItemID) {
                            SaleTaskAudienceCompactBadge(
                                snapshot: liveSnapshot,
                                messageID: nil,
                                taskID: offer.taskSnapshotID(for: checklistItemID),
                                audience: offer.taskSnapshotAudienceMembers
                            )
                        }

                        Spacer(minLength: 0)
                    }
                    Text(update.title)
                        .font(.subheadline.weight(.semibold))
                    Text(update.body)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if let checklistItemID = update.checklistItemID,
                       let liveSnapshot = offer.liveTaskSnapshot(for: checklistItemID),
                       let session = store.legalWorkspaceSession {
                        SaleTaskAudienceStatusRow(
                            snapshot: liveSnapshot,
                            messageID: nil,
                            taskID: offer.taskSnapshotID(for: checklistItemID),
                            audience: offer.taskSnapshotAudienceMembers,
                            currentViewerID: SaleTaskSnapshotSyncStore.viewerID(forInvite: session.inviteID),
                            markAsSeenOnAppear: true
                        )
                    }
                    Text(legalRelativeDate(update.createdAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AppTheme.cardBackground)
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(workspacePanel)
    }

    private var missingWorkspaceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Legal workspace unavailable")
                .font(.headline)
            Text("This invite is no longer active in the current app session. Return to the start screen and reopen it with the invite code.")
                .foregroundStyle(.secondary)
            Button("Return to Start") {
                store.closeLegalWorkspace()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(workspacePanel)
    }

    private var workspacePanel: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(AppTheme.cardBackground)
    }

    private func legalTag(_ label: String) -> some View {
        Text(label)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(AppTheme.pillBackground.opacity(0.8))
            )
            .foregroundStyle(.white)
    }

    private func workspaceMetric(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    private func previewDocument(
        listing: PropertyListing,
        offer: OfferRecord,
        document: SaleDocument
    ) {
        let buyer = store.user(id: offer.buyerID) ?? legalFallbackUser(id: offer.buyerID, role: .buyer)
        let seller = store.user(id: offer.sellerID) ?? legalFallbackUser(id: offer.sellerID, role: .seller)

        do {
            preparedDocument = try SaleDocumentRenderer.render(
                document: document,
                listing: listing,
                offer: offer,
                buyer: buyer,
                seller: seller
            )
        } catch {
            notice = "Could not prepare the PDF preview right now."
        }
    }

    private func relayLegalUpdate(
        outcome: LegalWorkspaceActionOutcome,
        listing: PropertyListing,
        offer: OfferRecord,
        invite: SaleWorkspaceInvite
    ) {
        let buyer = store.user(id: offer.buyerID) ?? legalFallbackUser(id: offer.buyerID, role: .buyer)
        let seller = store.user(id: offer.sellerID) ?? legalFallbackUser(id: offer.sellerID, role: .seller)
        let sender = invite.role == .buyerRepresentative ? buyer : seller
        let recipient = sender.id == buyer.id ? seller : buyer

        _ = messaging.sendMessage(
            listing: listing,
            from: sender,
            to: recipient,
            body: outcome.threadMessage,
            isSystem: true,
            saleTaskTarget: .saleTask(
                listingID: listing.id,
                offerID: offer.id,
                checklistItemID: outcome.checklistItemID
            )
        )
    }

    private func handleImportedPDF(_ result: Result<[URL], Error>) {
        guard let kind = pendingUploadKind,
              let listing = store.legalWorkspaceListing,
              let offer = store.legalWorkspaceOffer,
              let invite = store.legalWorkspaceInvite else {
            pendingUploadKind = nil
            return
        }

        defer { pendingUploadKind = nil }

        switch result {
        case let .success(urls):
            guard let url = urls.first else {
                notice = "No PDF was selected."
                return
            }

            let fileName = url.lastPathComponent.isEmpty ? defaultUploadFileName(for: kind) : url.lastPathComponent
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let data = try Data(contentsOf: url)
                guard let outcome = store.uploadLegalWorkspaceDocument(
                    kind: kind,
                    fileName: fileName,
                    data: data,
                    mimeType: "application/pdf"
                ) else {
                    notice = "Could not attach that PDF right now."
                    return
                }

                relayLegalUpdate(outcome: outcome, listing: listing, offer: offer, invite: invite)
                notice = outcome.noticeMessage
            } catch {
                notice = "Could not read that PDF right now."
            }
        case .failure:
            notice = "The PDF picker was cancelled."
        }
    }

    private func defaultUploadFileName(for kind: SaleDocumentKind) -> String {
        switch kind {
        case .reviewedContractPDF:
            return "reviewed-contract.pdf"
        case .settlementAdjustmentPDF:
            return "settlement-adjustment.pdf"
        default:
            return "legal-workspace-document.pdf"
        }
    }

    private func legalFallbackUser(id: UUID, role: UserRole) -> UserProfile {
        UserProfile(
            id: id,
            name: role == .buyer ? "Buyer" : "Seller",
            role: role,
            suburb: "Queensland",
            headline: "Legal workspace participant",
            verificationNote: "Invite-only workspace",
            buyerStage: nil
        )
    }
}

private func legalCurrency(_ value: Int) -> String {
    Currency.aud.string(from: NSNumber(value: value)) ?? "$\(value)"
}

private func legalShortDate(_ date: Date) -> String {
    date.formatted(date: .abbreviated, time: .shortened)
}

private func legalRelativeDate(_ date: Date) -> String {
    date.formatted(.relative(presentation: .named))
}

struct SaleChecklistContent: View {
    let items: [SaleChecklistItem]
    var scrollIDPrefix: String? = nil
    var focusedItemID: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(items) { item in
                SaleChecklistRow(
                    item: item,
                    isFocused: item.id == focusedItemID
                )
                .id(scrollID(for: item.id))
            }
        }
    }

    private func scrollID(for itemID: String) -> String {
        guard let scrollIDPrefix else {
            return itemID
        }

        return "\(scrollIDPrefix):\(itemID)"
    }
}

private struct SaleChecklistRow: View {
    let item: SaleChecklistItem
    var isFocused = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.status.symbolName)
                .font(.headline)
                .foregroundStyle(statusTint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 8) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Spacer(minLength: 8)

                    Text(item.status.title)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(statusTint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(statusBackground)
                        )
                }

                Text(item.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    checklistMetaLine(item.ownerSummary, systemImage: "person.crop.circle.badge.checkmark", tint: Color.secondary)

                    if let targetSummary = item.targetSummary {
                        checklistMetaLine(
                            targetSummary,
                            systemImage: item.isOverdue ? "exclamationmark.circle.fill" : "calendar",
                            tint: attentionTint
                        )
                    }

                    if let nextActionSummary = item.nextActionSummary {
                        checklistMetaLine(nextActionSummary, systemImage: "arrow.forward.circle.fill", tint: statusTint)
                    }

                    if let reminderSummary = item.reminderSummary {
                        checklistMetaLine(reminderSummary, systemImage: "bell.badge.fill", tint: attentionTint)
                    }
                }

                if let supporting = item.supporting {
                    Text(supporting)
                        .font(.caption)
                        .foregroundStyle(statusTint)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(backgroundFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    isFocused ? Color(red: 1.0, green: 0.39, blue: 0.35).opacity(0.9) : .clear,
                    lineWidth: isFocused ? 2 : 0
                )
        )
    }

    private var backgroundFill: Color {
        if isFocused {
            return Color(red: 1.0, green: 0.97, blue: 0.91)
        }

        if item.isOverdue {
            return Color(red: 1.0, green: 0.96, blue: 0.96)
        }

        return Color(red: 0.98, green: 0.99, blue: 1.0)
    }

    private var statusTint: Color {
        switch item.status {
        case .pending:
            return Color(red: 0.38, green: 0.42, blue: 0.47)
        case .inProgress:
            return Color(red: 0.72, green: 0.44, blue: 0.08)
        case .completed:
            return Color(red: 0.05, green: 0.46, blue: 0.48)
        }
    }

    private var statusBackground: Color {
        switch item.status {
        case .pending:
            return Color(red: 0.92, green: 0.94, blue: 0.96)
        case .inProgress:
            return Color(red: 1.0, green: 0.95, blue: 0.85)
        case .completed:
            return Color(red: 0.88, green: 0.97, blue: 0.95)
        }
    }

    private var attentionTint: Color {
        if item.isOverdue {
            return .red
        }

        if item.isDueSoon || item.reminderSummary != nil {
            return Color(red: 0.72, green: 0.44, blue: 0.08)
        }

        return statusTint
    }

    @ViewBuilder
    private func checklistMetaLine(_ text: String, systemImage: String, tint: Color) -> some View {
        Label {
            Text(text)
                .font(.caption)
                .foregroundStyle(tint)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
        }
    }
}
