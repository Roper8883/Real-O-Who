import Combine
import Foundation

@MainActor
final class MarketplaceStore: ObservableObject {
    @Published private(set) var users: [UserProfile] = MarketplaceSeed.users
    @Published private(set) var authAccounts: [LocalAuthAccount] = []
    @Published private(set) var listings: [PropertyListing] = MarketplaceSeed.listings()
    @Published private(set) var savedSearches: [SavedSearch] = MarketplaceSeed.savedSearches
    @Published private(set) var favoriteListingIDs: Set<UUID> = []
    @Published private(set) var plannedInspectionIDs: Set<UUID> = MarketplaceSeed.plannedInspectionIDs
    @Published private(set) var offers: [OfferRecord] = []
    @Published var currentUserID: UUID = MarketplaceSeed.buyerOliviaID
    @Published private(set) var sessionUserID: UUID?
    @Published private(set) var legalWorkspaceSession: LegalWorkspaceSession?
    @Published private(set) var inboundLegalInviteCode: String?
    @Published private(set) var inboundLegalInviteErrorMessage: String?
    @Published private(set) var inboundSaleReminderTarget: SaleReminderNavigationTarget?
    @Published private(set) var authLifecycleNotice: String?

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let fileManager: FileManager
    private let fileURL: URL
    private let isEphemeral: Bool
    private let authService: any MarketplaceAuthServing
    private let listingSync: any MarketplaceListingSyncing
    private let userStateSync: any MarketplaceUserStateSyncing
    private let legalProfessionalSearch: any MarketplaceLegalProfessionalSearching
    private let postSaleConciergeSearch: any MarketplacePostSaleConciergeSearching
    private let saleSync: any MarketplaceSaleSyncing
    private let storageModeSummaryValue: String
    private let backendEndpointSummaryValue: String
    private let remoteSyncEnabled: Bool
    private var userMarketplaceStatesByID: [UUID: UserMarketplaceState] = [:]

    init(
        fileManager: FileManager = .default,
        launchConfiguration: AppLaunchConfiguration? = nil,
        authService: (any MarketplaceAuthServing)? = nil,
        listingSync: (any MarketplaceListingSyncing)? = nil,
        userStateSync: (any MarketplaceUserStateSyncing)? = nil,
        legalProfessionalSearch: (any MarketplaceLegalProfessionalSearching)? = nil,
        postSaleConciergeSearch: (any MarketplacePostSaleConciergeSearching)? = nil,
        saleSync: (any MarketplaceSaleSyncing)? = nil,
        storageModeSummary: String = "Local only",
        backendEndpointSummary: String = "No backend URL",
        remoteSyncEnabled: Bool = false
    ) {
        let launchConfiguration = launchConfiguration ?? .shared

        self.fileManager = fileManager
        self.isEphemeral = launchConfiguration.isScreenshotMode
        self.authService = authService ?? LocalMarketplaceAuthService()
        self.listingSync = listingSync ?? DisabledListingSync()
        self.userStateSync = userStateSync ?? DisabledUserStateSync()
        self.legalProfessionalSearch = legalProfessionalSearch ?? LocalLegalProfessionalSearch()
        self.postSaleConciergeSearch = postSaleConciergeSearch ?? LocalPostSaleConciergeSearch()
        self.saleSync = saleSync ?? DisabledSaleSync()
        self.storageModeSummaryValue = storageModeSummary
        self.backendEndpointSummaryValue = backendEndpointSummary
        self.remoteSyncEnabled = remoteSyncEnabled

        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        let supportDirectory = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fileManager.temporaryDirectory

        let directory = supportDirectory.appendingPathComponent("RealOWhoMarketplace", isDirectory: true)
        fileURL = directory.appendingPathComponent("marketplace.json")

        if !isEphemeral {
            load()
        }

        if !isEphemeral && sessionUserID == nil, !users.isEmpty {
            sessionUserID = currentUserID
            persist()
        }

        if favoriteListingIDs.isEmpty {
            restoreMarketplaceState(for: currentUserID)
        }
    }

    var currentUser: UserProfile {
        users.first(where: { $0.id == currentUserID }) ?? users.first ?? MarketplaceSeed.users[0]
    }

    var isAuthenticated: Bool {
        isEphemeral || sessionUserID != nil
    }

    var legalWorkspaceListing: PropertyListing? {
        guard let legalWorkspaceSession else { return nil }
        return listing(id: legalWorkspaceSession.listingID)
    }

    var legalWorkspaceOffer: OfferRecord? {
        guard let legalWorkspaceSession else { return nil }
        return offer(id: legalWorkspaceSession.offerID)
    }

    var legalWorkspaceInvite: SaleWorkspaceInvite? {
        guard let legalWorkspaceSession,
              let offer = offer(id: legalWorkspaceSession.offerID) else { return nil }
        return offer.invites.first {
            $0.id == legalWorkspaceSession.inviteID ||
            $0.shareCode.caseInsensitiveCompare(legalWorkspaceSession.inviteCode) == .orderedSame
        }
    }

    var currentAccount: LocalAuthAccount? {
        account(for: currentUserID)
    }

    var storageModeSummary: String {
        storageModeSummaryValue
    }

    var backendEndpointSummary: String {
        backendEndpointSummaryValue
    }

    var buyers: [UserProfile] {
        users.filter { $0.role == .buyer }
    }

    var sellers: [UserProfile] {
        users.filter { $0.role == .seller }
    }

    var activeListings: [PropertyListing] {
        listings.filter { $0.status != .draft && $0.status != .sold }
    }

    var featuredListings: [PropertyListing] {
        activeListings.filter(\.isFeatured)
    }

    var currentUserSavedListings: [PropertyListing] {
        listings.filter { favoriteListingIDs.contains($0.id) }
    }

    var currentUserPlannedInspections: [(listing: PropertyListing, slot: InspectionSlot)] {
        listings.flatMap { listing in
            listing.inspectionSlots.compactMap { slot in
                guard plannedInspectionIDs.contains(slot.id) else { return nil }
                return (listing, slot)
            }
        }
        .sorted { $0.slot.startsAt < $1.slot.startsAt }
    }

    var sellerDashboardStats: SellerDashboardStats {
        let ownedListings = listings.filter { $0.sellerID == currentUserID }
        let offerCount = offers.filter { $0.sellerID == currentUserID }.count
        let activeCount = ownedListings.filter { $0.status == .active }.count
        let draftCount = ownedListings.filter { $0.status == .draft }.count
        let demandScore = ownedListings
            .map(\.marketPulse.buyerDemandScore)
            .reduce(0, +)

        let averageDemand = ownedListings.isEmpty ? 0 : demandScore / ownedListings.count

        return SellerDashboardStats(
            activeListings: activeCount,
            draftListings: draftCount,
            totalOffers: offerCount,
            averageDemandScore: averageDemand
        )
    }

    var currentUserConciergeReminderDashboard: ConciergeReminderDashboard {
        let relevantOffers = offers.filter { $0.buyerID == currentUserID || $0.sellerID == currentUserID }
        let bookings = relevantOffers
            .flatMap(\.conciergeBookings)
            .filter { !$0.isCancelled && !$0.isCompleted && !$0.isProviderConfirmed }

        return ConciergeReminderDashboard(
            intensity: currentUser.conciergeReminderIntensity,
            activeBookingCount: bookings.count,
            overdueCount: bookings.filter(\.needsResponseFollowUp).count,
            dueSoonCount: bookings.filter(\.isResponseDueSoon).count,
            snoozedCount: bookings.filter(\.isReminderSnoozed).count,
            openIssueCount: bookings.filter(\.hasOpenIssue).count
        )
    }

    func user(id: UUID) -> UserProfile? {
        users.first { $0.id == id }
    }

    func account(for userID: UUID) -> LocalAuthAccount? {
        authAccounts.first { $0.userID == userID }
    }

    func listing(id: UUID) -> PropertyListing? {
        listings.first { $0.id == id }
    }

    func offer(id: UUID) -> OfferRecord? {
        offers.first { $0.id == id }
    }

    func saleDocuments(for offerID: UUID) -> [SaleDocument] {
        offer(id: offerID)?
            .documents
            .sorted { left, right in
                if left.createdAt == right.createdAt {
                    return left.id.uuidString > right.id.uuidString
                }
                return left.createdAt > right.createdAt
            } ?? []
    }

    func saleInvites(for offerID: UUID) -> [SaleWorkspaceInvite] {
        offer(id: offerID)?
            .invites
            .sorted { left, right in
                if left.isUnavailable != right.isUnavailable {
                    return !left.isUnavailable && right.isUnavailable
                }
                if left.createdAt == right.createdAt {
                    return left.id.uuidString > right.id.uuidString
                }
                return left.createdAt > right.createdAt
            } ?? []
    }

    func relevantOffer(for listingID: UUID, userID: UUID) -> OfferRecord? {
        let listingOffers = offers
            .filter { $0.listingID == listingID }
            .sorted { $0.createdAt > $1.createdAt }

        if let participantMatched = listingOffers.first(where: { $0.buyerID == userID || $0.sellerID == userID }) {
            return participantMatched
        }

        guard let listing = listing(id: listingID) else {
            return listingOffers.first
        }

        if currentUser.role == .seller, listing.sellerID == currentUserID {
            return listingOffers.first
        }

        if currentUser.role == .buyer, listing.sellerID != currentUserID {
            return listingOffers.first
        }

        return nil
    }

    func listings(
        query: String,
        suburb: String,
        minimumBedrooms: Int,
        propertyTypes: Set<PropertyType>,
        maximumPrice: Int?,
        sortOrder: ListingSortOrder
    ) -> [PropertyListing] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedSuburb = suburb.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return activeListings
            .filter { listing in
                guard listing.bedrooms >= minimumBedrooms else { return false }

                if let maximumPrice, listing.askingPrice > maximumPrice {
                    return false
                }

                if !propertyTypes.isEmpty && !propertyTypes.contains(listing.propertyType) {
                    return false
                }

                if !normalizedSuburb.isEmpty &&
                    !listing.address.suburb.lowercased().contains(normalizedSuburb) {
                    return false
                }

                guard !normalizedQuery.isEmpty else { return true }

                let searchable = [
                    listing.title,
                    listing.headline,
                    listing.summary,
                    listing.address.fullLine,
                    listing.features.joined(separator: " ")
                ]
                .joined(separator: " ")
                .lowercased()

                return searchable.contains(normalizedQuery)
            }
            .sorted {
                switch sortOrder {
                case .featured:
                    if $0.isFeatured == $1.isFeatured {
                        return $0.updatedAt > $1.updatedAt
                    }

                    return $0.isFeatured && !$1.isFeatured
                case .newest:
                    return $0.publishedAt > $1.publishedAt
                case .priceLowHigh:
                    return $0.askingPrice < $1.askingPrice
                case .priceHighLow:
                    return $0.askingPrice > $1.askingPrice
                }
            }
    }

    func sellerListings(for sellerID: UUID) -> [PropertyListing] {
        listings
            .filter { $0.sellerID == sellerID }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func isFavorite(listingID: UUID) -> Bool {
        favoriteListingIDs.contains(listingID)
    }

    func isInspectionPlanned(slotID: UUID) -> Bool {
        plannedInspectionIDs.contains(slotID)
    }

    func setCurrentUser(_ userID: UUID) {
        currentUserID = userID
        restoreMarketplaceState(for: userID)
        persist()
    }

    func updateConciergeReminderIntensity(
        userID: UUID,
        intensity: ConciergeReminderIntensity
    ) {
        guard let userIndex = users.firstIndex(where: { $0.id == userID }) else {
            return
        }

        guard users[userIndex].conciergeReminderIntensity != intensity else {
            return
        }

        users[userIndex].conciergeReminderIntensity = intensity
        persist()
    }

    func signIn(email: String, password: String) async throws {
        let session = try await authService.signIn(
            email: email,
            password: password,
            accounts: authAccounts,
            users: users
        )

        if let index = authAccounts.firstIndex(where: { $0.id == session.account.id }) {
            authAccounts[index] = session.account
        } else {
            authAccounts.insert(session.account, at: 0)
        }

        if let userIndex = users.firstIndex(where: { $0.id == session.user.id }) {
            users[userIndex] = session.user
        } else {
            users.insert(session.user, at: 0)
        }

        currentUserID = session.user.id
        sessionUserID = session.user.id
        restoreMarketplaceState(for: session.user.id)
        authLifecycleNotice = nil
        persist()
    }

    @discardableResult
    func createAccount(
        name: String,
        email: String,
        password: String,
        role: UserRole,
        suburb: String
    ) async throws -> UserProfile {
        let session = try await authService.createAccount(
            registration: MarketplaceAuthRegistration(
                name: name,
                email: email,
                password: password,
                role: role,
                suburb: suburb
            ),
            existingAccounts: authAccounts
        )

        users.insert(session.user, at: 0)
        authAccounts.insert(session.account, at: 0)
        currentUserID = session.user.id
        sessionUserID = session.user.id
        restoreMarketplaceState(for: session.user.id)
        authLifecycleNotice = nil
        persist()
        return session.user
    }

    func signOut() {
        sessionUserID = nil
        persist()
    }

    func deleteCurrentAccount() async throws {
        let deletedUser = currentUser
        let deletedAccount = currentAccount

        try await authService.deleteAccount(
            account: deletedAccount,
            user: deletedUser
        )

        purgeLocalData(forDeletedUserID: deletedUser.id)
        authLifecycleNotice = "Account deleted. Local account data has been removed from this device."
        persist()
    }

    func clearAuthLifecycleNotice() {
        authLifecycleNotice = nil
    }

    func closeLegalWorkspace() {
        legalWorkspaceSession = nil
    }

    func toggleFavorite(listingID: UUID) {
        if favoriteListingIDs.contains(listingID) {
            favoriteListingIDs.remove(listingID)
        } else {
            favoriteListingIDs.insert(listingID)
        }

        persist()
        syncMarketplaceStateInBackground()
    }

    func toggleInspection(slotID: UUID) {
        if plannedInspectionIDs.contains(slotID) {
            plannedInspectionIDs.remove(slotID)
        } else {
            plannedInspectionIDs.insert(slotID)
        }

        persist()
    }

    func createSavedSearch(
        title: String,
        suburb: String,
        minimumPrice: Int,
        maximumPrice: Int,
        minimumBedrooms: Int,
        propertyTypes: Set<PropertyType>
    ) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        savedSearches.insert(
            SavedSearch(
                id: UUID(),
                title: trimmedTitle,
                suburb: suburb.trimmingCharacters(in: .whitespacesAndNewlines),
                minimumPrice: minimumPrice,
                maximumPrice: maximumPrice,
                minimumBedrooms: minimumBedrooms,
                propertyTypes: Array(propertyTypes),
                alertsEnabled: true
            ),
            at: 0
        )

        persist()
        syncMarketplaceStateInBackground()
    }

    @discardableResult
    func completeVerificationCheck(
        userID: UUID,
        kind: VerificationCheckKind
    ) -> VerificationCompletionOutcome? {
        guard let completedCheck = markVerificationCheckVerified(
            userID: userID,
            kind: kind,
            detail: verificationCompletionDetail(for: kind, userID: userID)
        ),
        let updatedUser = user(id: userID) else {
            return nil
        }

        let unlockedContractPackets = unlockContractPacketsForEligibleOffers(triggeredBy: userID)
        persist()

        for unlocked in unlockedContractPackets {
            syncOfferInBackground(unlocked.offer)
        }

        return VerificationCompletionOutcome(
            user: updatedUser,
            completedCheck: completedCheck,
            unlockedContractPackets: unlockedContractPackets,
            linkedDealRoomCount: 0,
            noticeMessage: verificationCompletionNotice(
                for: kind,
                user: updatedUser,
                linkedDealRoomCount: 0,
                unlockedCount: unlockedContractPackets.count
            )
        )
    }

    @discardableResult
    func uploadVerificationDocument(
        userID: UUID,
        kind: VerificationCheckKind,
        fileName: String,
        data: Data,
        mimeType: String
    ) -> VerificationCompletionOutcome? {
        guard kind.requiresDocumentUpload else {
            return nil
        }

        let trimmedFileName = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedFileName = trimmedFileName.isEmpty
            ? defaultVerificationEvidenceFileName(for: kind, userID: userID)
            : trimmedFileName
        let uploadedAt = Date()

        guard let completedCheck = markVerificationCheckVerified(
            userID: userID,
            kind: kind,
            detail: verificationEvidenceDetail(
                for: kind,
                userID: userID,
                fileName: normalizedFileName
            ),
            verifiedAt: uploadedAt,
            evidenceFileName: normalizedFileName,
            evidenceMimeType: mimeType,
            evidenceAttachmentBase64: data.base64EncodedString(),
            evidenceUploadedAt: uploadedAt
        ),
        let updatedUser = user(id: userID) else {
            return nil
        }

        let linkedOfferIDs = attachVerificationEvidenceToRelevantOffers(
            user: updatedUser,
            kind: kind
        )
        let unlockedContractPackets = unlockContractPacketsForEligibleOffers(triggeredBy: userID)
        persist()

        var syncedOfferIDs = Set(linkedOfferIDs)
        unlockedContractPackets.forEach { syncedOfferIDs.insert($0.offer.id) }

        for offerID in syncedOfferIDs {
            guard let updatedOffer = offer(id: offerID) else { continue }
            syncOfferInBackground(updatedOffer)
        }

        return VerificationCompletionOutcome(
            user: updatedUser,
            completedCheck: completedCheck,
            unlockedContractPackets: unlockedContractPackets,
            linkedDealRoomCount: linkedOfferIDs.count,
            noticeMessage: verificationCompletionNotice(
                for: kind,
                user: updatedUser,
                linkedDealRoomCount: linkedOfferIDs.count,
                unlockedCount: unlockedContractPackets.count
            )
        )
    }

    func searchLegalProfessionals(for listing: PropertyListing) async throws -> [LegalProfessional] {
        try await legalProfessionalSearch.searchProfessionals(near: listing)
    }

    func searchPostSaleConciergeProviders(
        for listing: PropertyListing,
        serviceKind: PostSaleConciergeServiceKind
    ) async throws -> [PostSaleConciergeProvider] {
        try await postSaleConciergeSearch.searchProviders(near: listing, serviceKind: serviceKind)
    }

    func refreshListings() async {
        guard remoteSyncEnabled else { return }

        do {
            let remoteListings = try await listingSync.fetchListings()
            guard !remoteListings.isEmpty else { return }
            mergeRemoteListings(remoteListings)
        } catch {
            return
        }
    }

    func refreshMarketplaceState() async {
        guard remoteSyncEnabled, isAuthenticated else { return }

        do {
            let remoteState = try await userStateSync.fetchState(for: currentUserID)
            mergeRemoteMarketplaceState(remoteState)
        } catch {
            return
        }
    }

    func refreshOffers() async {
        guard remoteSyncEnabled, isAuthenticated else { return }

        do {
            let remoteOffers = try await saleSync.fetchSales(for: currentUserID)
            replaceOffers(remoteOffers)
        } catch {
            return
        }
    }

    func refreshSale(for listingID: UUID) async {
        guard remoteSyncEnabled else { return }

        do {
            guard let remoteOffer = try await saleSync.fetchSale(for: listingID) else { return }
            mergeRemoteSale(remoteOffer)
        } catch {
            return
        }
    }

    func handleLegalWorkspaceDeepLink(_ url: URL) async {
        guard let inviteCode = LegalWorkspaceDeepLink.inviteCode(from: url) else {
            return
        }

        inboundLegalInviteCode = inviteCode
        inboundLegalInviteErrorMessage = nil

        do {
            let didOpen = try await openLegalWorkspace(inviteCode: inviteCode)
            if !didOpen {
                inboundLegalInviteErrorMessage = "That legal workspace invite could not be found yet."
            }
        } catch {
            inboundLegalInviteErrorMessage = error.localizedDescription
        }
    }

    func handleSaleReminderTarget(_ target: SaleReminderNavigationTarget) async {
        legalWorkspaceSession = nil
        inboundSaleReminderTarget = target
        await refreshListings()
        await refreshSale(for: target.listingID)
    }

    func consumeInboundSaleReminderTarget() {
        inboundSaleReminderTarget = nil
    }

    func clearInboundLegalInviteError() {
        inboundLegalInviteErrorMessage = nil
    }

    func openLegalWorkspace(inviteCode: String) async throws -> Bool {
        let normalizedCode = inviteCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard !normalizedCode.isEmpty else {
            return false
        }

        if remoteSyncEnabled {
            do {
                if let workspace = try await saleSync.fetchLegalWorkspace(inviteCode: normalizedCode) {
                    applyLegalWorkspaceAccess(
                        listing: workspace.listing,
                        offer: workspace.offer,
                        invite: workspace.invite
                    )
                    inboundLegalInviteErrorMessage = nil
                    return true
                }
            } catch let error as MarketplaceHTTPError where error.canFallbackToLocal {
                // Fall back to any locally cached sale workspace below.
            } catch {
                throw error
            }
        }

        guard let localMatch = localLegalWorkspace(inviteCode: normalizedCode) else {
            return false
        }

        guard !localMatch.invite.isRevoked else {
            throw LegalWorkspaceAccessError.revokedInvite
        }

        guard !localMatch.invite.isExpired else {
            throw LegalWorkspaceAccessError.expiredInvite
        }

        let activatedMatch = activateLocalLegalWorkspaceIfNeeded(localMatch)

        applyLegalWorkspaceAccess(
            listing: activatedMatch.listing,
            offer: activatedMatch.offer,
            invite: activatedMatch.invite
        )
        inboundLegalInviteErrorMessage = nil
        return true
    }

    func acknowledgeLegalWorkspaceInvite() -> LegalWorkspaceActionOutcome? {
        guard let session = legalWorkspaceSession,
              let offerIndex = offers.firstIndex(where: { $0.id == session.offerID }),
              let inviteIndex = legalInviteIndex(for: session, offer: offers[offerIndex]) else {
            return nil
        }

        var offer = offers[offerIndex]
        guard offer.invites[inviteIndex].acknowledgedAt == nil else {
            return nil
        }

        let now = Date()
        offer.invites[inviteIndex].acknowledgedAt = now
        let roleTitle = offer.invites[inviteIndex].role.title
        let title = "Legal workspace acknowledged"
        let body = "\(offer.invites[inviteIndex].professionalName) acknowledged the \(roleTitle.lowercased()) and confirmed they have started reviewing the sale documents."
        offer.updates.insert(makeSaleUpdate(title: title, body: body, createdAt: now), at: 0)

        offers[offerIndex] = offer
        legalWorkspaceSession = LegalWorkspaceSession(
            listingID: offer.listingID,
            offerID: offer.id,
            invite: offer.invites[inviteIndex]
        )
        persist()
        syncOfferInBackground(offer)

        return LegalWorkspaceActionOutcome(
            offer: offer,
            representedPartyID: representedPartyID(for: offer.invites[inviteIndex].role, offer: offer),
            checklistItemID: "workspace-active",
            threadMessage: body,
            noticeMessage: "Receipt recorded. Buyer and seller can now see that the legal workspace is active."
        )
    }

    func uploadLegalWorkspaceDocument(
        kind: SaleDocumentKind,
        fileName: String,
        data: Data,
        mimeType: String
    ) -> LegalWorkspaceActionOutcome? {
        guard let session = legalWorkspaceSession,
              let offerIndex = offers.firstIndex(where: { $0.id == session.offerID }),
              let inviteIndex = legalInviteIndex(for: session, offer: offers[offerIndex]) else {
            return nil
        }

        guard kind == .reviewedContractPDF || kind == .settlementAdjustmentPDF else {
            return nil
        }

        var offer = offers[offerIndex]
        guard let packet = offer.contractPacket else {
            return nil
        }

        let invite = offer.invites[inviteIndex]
        let createdAt = Date()
        let document = makeLegalWorkspaceDocument(
            kind: kind,
            offer: offer,
            packet: packet,
            invite: invite,
            createdAt: createdAt,
            fileName: fileName,
            attachmentBase64: data.base64EncodedString(),
            mimeType: mimeType
        )
        upsertWorkspaceDocument(document, to: &offer)

        let updateBody: String
        let noticeMessage: String
        switch kind {
        case .reviewedContractPDF:
            updateBody = "\(invite.professionalName) uploaded a reviewed contract PDF and highlighted the latest legal checks for the private sale."
            noticeMessage = "Reviewed contract PDF added to the shared sale documents."
        case .settlementAdjustmentPDF:
            updateBody = "\(invite.professionalName) uploaded a settlement adjustment PDF covering rates, balances, and final settlement notes."
            noticeMessage = "Settlement adjustment PDF added to the shared sale documents."
        default:
            return nil
        }

        offer.updates.insert(
            makeSaleUpdate(
                title: document.title,
                body: updateBody,
                createdAt: createdAt
            ),
            at: 0
        )

        offers[offerIndex] = offer
        persist()
        syncOfferInBackground(offer)

        return LegalWorkspaceActionOutcome(
            offer: offer,
            representedPartyID: representedPartyID(for: invite.role, offer: offer),
            checklistItemID: kind == .reviewedContractPDF ? "legal-review-pack" : "workspace-active",
            threadMessage: updateBody,
            noticeMessage: noticeMessage
        )
    }

    func manageSaleInvite(
        offerID: UUID,
        role: LegalInviteRole,
        action: SaleInviteManagementAction,
        triggeredBy userID: UUID
    ) -> SaleInviteManagementOutcome? {
        guard let offerIndex = offers.firstIndex(where: { $0.id == offerID }),
              let inviteIndex = offers[offerIndex].invites.firstIndex(where: { $0.role == role }),
              currentUserID == offers[offerIndex].buyerID || currentUserID == offers[offerIndex].sellerID else {
            return nil
        }

        var offer = offers[offerIndex]
        let currentInvite = offer.invites[inviteIndex]
        let now = Date()
        let title: String
        let threadMessage: String
        let noticeMessage: String
        let updatedInvite: SaleWorkspaceInvite

        switch action {
        case .revoke:
            guard currentInvite.revokedAt == nil else { return nil }
            offer.invites[inviteIndex].revokedAt = now
            updatedInvite = offer.invites[inviteIndex]
            title = "Legal workspace invite revoked"
            threadMessage = "\(updatedInvite.role.title) for \(updatedInvite.professionalName) was revoked. That invite code can no longer open the sale workspace."
            noticeMessage = "\(updatedInvite.role.title) was revoked."
        case .regenerate:
            let regeneratedInvite = regenerateWorkspaceInvite(
                currentInvite: currentInvite,
                offer: offer,
                triggeredBy: userID,
                createdAt: now
            )
            offer.invites[inviteIndex] = regeneratedInvite
            updatedInvite = regeneratedInvite
            title = "Legal workspace invite regenerated"
            threadMessage = "\(updatedInvite.role.title) for \(updatedInvite.professionalName) was regenerated. The previous invite code is no longer valid and a fresh code is ready to share."
            noticeMessage = "Fresh \(updatedInvite.role.title.lowercased()) is ready to resend."
        }

        offer.updates.insert(makeSaleUpdate(title: title, body: threadMessage, createdAt: now), at: 0)
        offers[offerIndex] = offer

        let isManagingCurrentLegalSession = legalWorkspaceSession?.offerID == offer.id &&
            (
                legalWorkspaceSession?.inviteID == currentInvite.id ||
                    legalWorkspaceSession?.inviteCode.caseInsensitiveCompare(currentInvite.shareCode) == .orderedSame
            )
        if isManagingCurrentLegalSession {
            legalWorkspaceSession = action == .regenerate
                ? LegalWorkspaceSession(listingID: offer.listingID, offerID: offer.id, invite: updatedInvite)
                : nil
        }

        persist()
        syncOfferInBackground(offer)

        return SaleInviteManagementOutcome(
            offer: offer,
            invite: updatedInvite,
            threadMessage: threadMessage,
            noticeMessage: noticeMessage
        )
    }

    func recordSaleInviteShare(
        offerID: UUID,
        role: LegalInviteRole,
        triggeredBy userID: UUID
    ) -> SaleInviteDeliveryOutcome? {
        guard let offerIndex = offers.firstIndex(where: { $0.id == offerID }),
              let inviteIndex = offers[offerIndex].invites.firstIndex(where: { $0.role == role }),
              currentUserID == offers[offerIndex].buyerID || currentUserID == offers[offerIndex].sellerID else {
            return nil
        }

        var offer = offers[offerIndex]
        guard !offer.invites[inviteIndex].isUnavailable else {
            return nil
        }

        let now = Date()
        let previousShareCount = offer.invites[inviteIndex].shareCount
        offer.invites[inviteIndex].lastSharedAt = now
        offer.invites[inviteIndex].shareCount = previousShareCount + 1

        let updatedInvite = offer.invites[inviteIndex]
        let isFirstShare = previousShareCount == 0
        let title = isFirstShare ? "Legal workspace invite shared" : "Legal workspace invite resent"
        let threadMessage: String
        if isFirstShare {
            threadMessage = "\(updatedInvite.role.title) for \(updatedInvite.professionalName) was shared from the sale workspace. Follow up if the invite has not been opened within 48 hours."
        } else {
            threadMessage = "\(updatedInvite.role.title) for \(updatedInvite.professionalName) was resent from the sale workspace. This invite has now been shared \(updatedInvite.shareCount) times."
        }
        let noticeMessage = isFirstShare
            ? "\(updatedInvite.role.title) delivery is now being tracked."
            : "\(updatedInvite.role.title) was resent. Follow up if it is not opened soon."

        offer.updates.insert(makeSaleUpdate(title: title, body: threadMessage, createdAt: now), at: 0)
        offers[offerIndex] = offer
        persist()
        syncOfferInBackground(offer)

        return SaleInviteDeliveryOutcome(
            offer: offer,
            invite: updatedInvite,
            threadMessage: threadMessage,
            noticeMessage: noticeMessage
        )
    }

    @discardableResult
    func selectLegalProfessional(
        offerID: UUID,
        userID: UUID,
        professional: LegalProfessional
    ) -> LegalSelectionOutcome? {
        guard let offerIndex = offers.firstIndex(where: { $0.id == offerID }) else {
            return nil
        }

        var offer = offers[offerIndex]
        guard offer.contractPacket?.isFullySigned != true else {
            return nil
        }
        let selection = LegalSelection(
            userID: userID,
            selectedAt: .now,
            professional: professional
        )

        var selectionChanged = false

        if offer.buyerID == userID {
            if offer.buyerLegalSelection?.professional.id != professional.id {
                offer.buyerLegalSelection = selection
                selectionChanged = true
            }
        } else if offer.sellerID == userID {
            if offer.sellerLegalSelection?.professional.id != professional.id {
                offer.sellerLegalSelection = selection
                selectionChanged = true
            }
        } else {
            return nil
        }

        var contractPacket: ContractPacket?
        var newUpdates: [SaleUpdateMessage] = []
        let actingUserName = user(id: userID)?.name ?? "Participant"
        let previousContractPacket = offer.contractPacket

        _ = markVerificationCheckVerified(
            userID: userID,
            kind: .legal,
            detail: "\(professional.name) is now selected to handle the \(professional.primarySpecialty.lowercased()) side of the sale."
        )

        if let buyerSelection = offer.buyerLegalSelection,
           let sellerSelection = offer.sellerLegalSelection,
           (selectionChanged || offer.contractPacket == nil) {
            contractPacket = prepareContractPacketIfEligible(
                for: &offer,
                buyerRepresentative: buyerSelection.professional,
                sellerRepresentative: sellerSelection.professional,
                triggeredBy: userID,
                forceRefresh: previousContractPacket != nil
            )
        }

        if selectionChanged {
            let title = offer.buyerID == userID ? "Buyer representative selected" : "Seller representative selected"
            let body = "\(actingUserName) chose \(professional.name) to handle the \(professional.primarySpecialty.lowercased()) side of the sale."
            newUpdates.append(makeSaleUpdate(title: title, body: body))
        }

        if let contractPacket {
            let title = previousContractPacket == nil ? "Contract packet sent" : "Contract packet refreshed"
            newUpdates.append(makeSaleUpdate(title: title, body: contractPacket.summary))
        }

        if !newUpdates.isEmpty {
            offer.updates = newUpdates + offer.updates
        }

        offers[offerIndex] = offer
        persist()
        syncOfferInBackground(offer)

        return LegalSelectionOutcome(
            offer: offer,
            contractPacket: contractPacket
        )
    }

    func toggleSavedSearchAlerts(id: UUID) {
        guard let index = savedSearches.firstIndex(where: { $0.id == id }) else { return }
        savedSearches[index].alertsEnabled.toggle()
        persist()
        syncMarketplaceStateInBackground()
    }

    @discardableResult
    func submitOffer(
        listingID: UUID,
        buyerID: UUID,
        amount: Int,
        conditions: String
    ) -> OfferSubmissionOutcome? {
        guard let listingIndex = listings.firstIndex(where: { $0.id == listingID }),
              let listing = listings[safe: listingIndex],
              let seller = user(id: listing.sellerID),
              amount > 0 else {
            return nil
        }

        let trimmedConditions = conditions.trimmingCharacters(in: .whitespacesAndNewlines)
        let existingOfferIndex = offers.firstIndex { $0.listingID == listingID && $0.buyerID == buyerID }
        let existingOffer = existingOfferIndex.flatMap { offers[safe: $0] }
        guard existingOffer?.contractPacket?.isFullySigned != true else {
            return nil
        }
        let now = Date()
        let buyerName = user(id: buyerID)?.name ?? "Buyer"

        var record = OfferRecord(
            id: existingOffer?.id ?? UUID(),
            listingID: listing.id,
            buyerID: buyerID,
            sellerID: seller.id,
            amount: amount,
            conditions: trimmedConditions,
            createdAt: now,
            status: .underOffer,
            sellerRelationshipStatus: existingOffer?.sellerRelationshipStatus ?? .watching,
            buyerLegalSelection: existingOffer?.buyerLegalSelection,
            sellerLegalSelection: existingOffer?.sellerLegalSelection,
            contractPacket: existingOffer?.contractPacket,
            invites: existingOffer?.invites ?? [],
            documents: existingOffer?.documents ?? [],
            updates: existingOffer?.updates ?? []
        )

        var refreshedPacket: ContractPacket?
        var newUpdates = [
            makeSaleUpdate(
                title: existingOffer == nil ? "Offer submitted" : "Offer updated",
                body: "\(buyerName) \(existingOffer == nil ? "submitted" : "updated") an offer of \(Currency.aud.string(from: NSNumber(value: amount)) ?? "$\(amount)"). Conditions: \(trimmedConditions)"
            )
        ]
        if let buyerRepresentative = record.buyerLegalSelection?.professional,
           let sellerRepresentative = record.sellerLegalSelection?.professional {
            refreshedPacket = prepareContractPacketIfEligible(
                for: &record,
                buyerRepresentative: buyerRepresentative,
                sellerRepresentative: sellerRepresentative,
                triggeredBy: buyerID,
                forceRefresh: existingOffer?.contractPacket != nil
            )
            if let refreshedPacket {
                newUpdates.append(
                    makeSaleUpdate(
                        title: existingOffer?.contractPacket == nil ? "Contract packet sent" : "Contract packet refreshed",
                        body: refreshedPacket.summary
                    )
                )
            }
        } else {
            record.contractPacket = nil
        }

        record.updates = newUpdates + record.updates

        if let existingOfferIndex {
            offers[existingOfferIndex] = record
        } else {
            offers.insert(record, at: 0)
        }
        listings[listingIndex].status = .underOffer
        listings[listingIndex].updatedAt = .now
        persist()
        syncOfferInBackground(record)
        return OfferSubmissionOutcome(
            offer: record,
            contractPacket: refreshedPacket,
            isRevision: existingOffer != nil
        )
    }

    @discardableResult
    func respondToOffer(
        offerID: UUID,
        userID: UUID,
        action: SellerOfferAction,
        amount: Int,
        conditions: String
    ) -> SellerOfferResponseOutcome? {
        guard let offerIndex = offers.firstIndex(where: { $0.id == offerID }),
              amount > 0 else {
            return nil
        }

        let trimmedConditions = conditions.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedConditions.isEmpty else {
            return nil
        }

        var offer = offers[offerIndex]
        guard offer.sellerID == userID else {
            return nil
        }
        guard offer.contractPacket?.isFullySigned != true else {
            return nil
        }
        if action == .accept,
           offers.contains(where: {
               $0.listingID == offer.listingID &&
               $0.id != offer.id &&
               $0.status == .accepted &&
               $0.contractPacket?.isFullySigned != true
           }) {
            return nil
        }
        let previousContractPacket = offer.contractPacket
        var downgradedPreferredOfferIDs: [UUID] = []

        offer.amount = amount
        offer.conditions = trimmedConditions
        offer.createdAt = .now
        offer.status = {
            switch action {
            case .accept:
                return .accepted
            case .requestChanges:
                return .changesRequested
            case .counter:
                return .countered
            }
        }()
        if action == .accept {
            offer.sellerRelationshipStatus = .preferred

            for index in offers.indices {
                guard offers[index].listingID == offer.listingID,
                      offers[index].id != offer.id,
                      offers[index].sellerRelationshipStatus == .preferred else {
                    continue
                }

                offers[index].sellerRelationshipStatus = .shortlisted
                downgradedPreferredOfferIDs.append(offers[index].id)
            }
        }

        var refreshedPacket: ContractPacket?
        var newUpdates: [SaleUpdateMessage] = []
        if let buyerRepresentative = offer.buyerLegalSelection?.professional,
           let sellerRepresentative = offer.sellerLegalSelection?.professional {
            refreshedPacket = prepareContractPacketIfEligible(
                for: &offer,
                buyerRepresentative: buyerRepresentative,
                sellerRepresentative: sellerRepresentative,
                triggeredBy: userID,
                forceRefresh: previousContractPacket != nil
            )
        } else {
            offer.contractPacket = nil
        }

        let sellerName = user(id: userID)?.name ?? "Seller"
        let formattedAmount = Currency.aud.string(from: NSNumber(value: amount)) ?? "$\(amount)"
        offers[offerIndex] = offer

        if let listingIndex = listings.firstIndex(where: { $0.id == offer.listingID }) {
            listings[listingIndex].status = offer.status.listingStatus
            listings[listingIndex].updatedAt = .now
        }
        let threadMessage: String
        let noticeMessage: String

        switch action {
        case .accept:
            threadMessage = "\(sellerName) accepted the offer of \(formattedAmount). Terms confirmed: \(trimmedConditions)"
            noticeMessage = "Offer accepted and synced to the shared sale workspace."
            newUpdates.append(makeSaleUpdate(title: "Offer accepted", body: threadMessage))
        case .requestChanges:
            threadMessage = "\(sellerName) requested changes before acceptance. Updated terms: \(trimmedConditions)"
            noticeMessage = "Requested changes were sent to the buyer."
            newUpdates.append(makeSaleUpdate(title: "Changes requested", body: threadMessage))
        case .counter:
            threadMessage = "\(sellerName) sent a counteroffer of \(formattedAmount). Updated terms: \(trimmedConditions)"
            noticeMessage = "Counteroffer sent to the buyer."
            newUpdates.append(makeSaleUpdate(title: "Counteroffer sent", body: threadMessage))
        }

        if let refreshedPacket {
            newUpdates.append(
                makeSaleUpdate(
                    title: previousContractPacket == nil ? "Contract packet sent" : "Contract packet refreshed",
                    body: refreshedPacket.summary
                )
            )
        }

        offer.updates = newUpdates + offer.updates
        offers[offerIndex] = offer

        persist()
        downgradedPreferredOfferIDs.forEach { downgradedID in
            if let downgradedOffer = offers.first(where: { $0.id == downgradedID }) {
                syncOfferInBackground(downgradedOffer)
            }
        }
        syncOfferInBackground(offer)

        return SellerOfferResponseOutcome(
            offer: offer,
            contractPacket: refreshedPacket,
            threadMessage: threadMessage,
            noticeMessage: noticeMessage
        )
    }

    @discardableResult
    func updateSellerRelationshipStatus(
        offerID: UUID,
        userID: UUID,
        status: SellerBuyerRelationshipStatus
    ) -> SellerOfferDispositionOutcome? {
        guard let offerIndex = offers.firstIndex(where: { $0.id == offerID }) else {
            return nil
        }

        guard offers[offerIndex].sellerID == userID else {
            return nil
        }

        guard offers[offerIndex].contractPacket?.isFullySigned != true else {
            return nil
        }

        let listingID = offers[offerIndex].listingID
        var updatedOffer = offers[offerIndex]
        var downgradedOfferIDs: [UUID] = []

        if status == .preferred {
            for index in offers.indices {
                guard offers[index].listingID == listingID,
                      offers[index].id != offerID,
                      offers[index].sellerID == userID,
                      offers[index].sellerRelationshipStatus == .preferred else {
                    continue
                }

                offers[index].sellerRelationshipStatus = .shortlisted
                downgradedOfferIDs.append(offers[index].id)
                syncOfferInBackground(offers[index])
            }
        }

        updatedOffer.sellerRelationshipStatus = status
        offers[offerIndex] = updatedOffer

        persist()
        syncOfferInBackground(updatedOffer)

        let noticeMessage: String
        switch status {
        case .watching:
            noticeMessage = "Offer moved back to watching so you can keep the buyer warm without prioritising them."
        case .shortlisted:
            noticeMessage = "Offer shortlisted. You can keep comparing it against other buyers on this listing."
        case .preferred:
            if downgradedOfferIDs.isEmpty {
                noticeMessage = "Preferred buyer set for this listing."
            } else {
                noticeMessage = "Preferred buyer updated. The previous preferred offer was kept warm as shortlisted."
            }
        }

        return SellerOfferDispositionOutcome(
            offer: updatedOffer,
            downgradedOfferIDs: downgradedOfferIDs,
            noticeMessage: noticeMessage
        )
    }

    @discardableResult
    func signContractPacket(
        offerID: UUID,
        userID: UUID
    ) -> ContractSigningOutcome? {
        guard let offerIndex = offers.firstIndex(where: { $0.id == offerID }) else {
            return nil
        }

        var offer = offers[offerIndex]
        guard offer.status == .accepted,
              var packet = offer.contractPacket else {
            return nil
        }

        let now = Date()
        let signerName = user(id: userID)?.name ?? "Participant"
        let alreadySigned: Bool

        if userID == offer.buyerID {
            alreadySigned = packet.buyerSignedAt != nil
            packet.buyerSignedAt = packet.buyerSignedAt ?? now
        } else if userID == offer.sellerID {
            alreadySigned = packet.sellerSignedAt != nil
            packet.sellerSignedAt = packet.sellerSignedAt ?? now
        } else {
            return nil
        }

        guard !alreadySigned else {
            return nil
        }

        offer.contractPacket = packet

        let signedTitle = userID == offer.buyerID ? "Buyer signed contract packet" : "Seller signed contract packet"
        var newUpdates = [
            makeSaleUpdate(
                title: signedTitle,
                body: "\(signerName) signed the contract packet and confirmed the private-sale terms."
            )
        ]

        var didCompleteSale = false
        let noticeMessage: String
        let threadMessage: String

        if let listingIndex = listings.firstIndex(where: { $0.id == offer.listingID }) {
            listings[listingIndex].updatedAt = now
            if packet.isFullySigned {
                listings[listingIndex].status = .sold
                didCompleteSale = true
            } else {
                listings[listingIndex].status = offer.listingStatus
            }
        }

        if packet.isFullySigned {
            registerCompletionWorkspaceMaterials(for: &offer, packet: packet, triggeredBy: userID)
            let completionMessage = "Both buyer and seller have signed the contract packet. The listing is now marked sold and the signed contract PDF is ready to share."
            newUpdates.append(makeSaleUpdate(title: "Sale complete", body: completionMessage))
            noticeMessage = "Both sides have signed. The listing is now marked sold and the signed contract PDF is ready."
            threadMessage = "\(signerName) signed the contract packet. Both sides are now signed, the listing is marked sold, and the signed contract PDF is ready."
        } else {
            noticeMessage = "Your contract sign-off has been recorded."
            threadMessage = "\(signerName) signed the contract packet and confirmed the private-sale terms."
        }

        offer.updates = newUpdates + offer.updates
        offers[offerIndex] = offer
        persist()
        syncOfferInBackground(offer)

        return ContractSigningOutcome(
            offer: offer,
            threadMessage: threadMessage,
            noticeMessage: noticeMessage,
            didCompleteSale: didCompleteSale
        )
    }

    @discardableResult
    func completeSettlement(
        offerID: UUID,
        userID: UUID
    ) -> SettlementCompletionOutcome? {
        guard let offerIndex = offers.firstIndex(where: { $0.id == offerID }) else {
            return nil
        }

        var offer = offers[offerIndex]
        guard offer.buyerID == userID || offer.sellerID == userID,
              let packet = offer.contractPacket,
              packet.isFullySigned == true,
              offer.settlementCompletedAt == nil,
              offer.documents.contains(where: { $0.kind == .settlementStatementPDF }) else {
            return nil
        }

        let now = Date()
        offer.settlementCompletedAt = now
        registerSettlementArchiveMaterials(
            for: &offer,
            packet: packet,
            triggeredBy: userID,
            createdAt: now
        )

        let actorName = user(id: userID)?.name ?? "A participant"
        let body = "\(actorName) confirmed settlement completion. Funds, keys, and final handover are now closed out for the private sale."
        offer.updates.insert(
            makeSaleUpdate(
                title: "Settlement completed",
                body: body,
                createdAt: now,
                checklistItemID: "settlement-complete"
            ),
            at: 0
        )
        offers[offerIndex] = offer

        if let listingIndex = listings.firstIndex(where: { $0.id == offer.listingID }) {
            listings[listingIndex].status = .sold
            listings[listingIndex].updatedAt = now
        }

        persist()
        syncOfferInBackground(offer)

        return SettlementCompletionOutcome(
            offer: offer,
            threadMessage: body,
            noticeMessage: "Settlement has been marked complete and the active deal is now fully closed."
        )
    }

    @discardableResult
    func completePostSaleServiceTask(
        offerID: UUID,
        userID: UUID,
        task: PostSaleServiceTaskKind
    ) -> PostSaleServiceOutcome? {
        guard let offerIndex = offers.firstIndex(where: { $0.id == offerID }) else {
            return nil
        }

        var offer = offers[offerIndex]
        guard offer.buyerID == userID || offer.sellerID == userID,
              offer.settlementCompletedAt != nil,
              offer.completedAt(for: task) == nil else {
            return nil
        }

        let now = Date()
        switch task {
        case .utilitiesTransfer:
            offer.utilitiesTransferCompletedAt = now
        case .addressUpdate:
            offer.addressUpdateCompletedAt = now
        }

        let actorName = user(id: userID)?.name ?? "A participant"
        let body = "\(actorName) completed the post-sale follow-through step: \(task.completionSummary)"
        offer.updates.insert(
            makeSaleUpdate(
                title: task.completionTitle,
                body: body,
                createdAt: now
            ),
            at: 0
        )

        offers[offerIndex] = offer
        persist()
        syncOfferInBackground(offer)

        return PostSaleServiceOutcome(
            offer: offer,
            threadMessage: body,
            noticeMessage: "\(task.title) marked complete for this settled deal."
        )
    }

    @discardableResult
    func bookPostSaleConciergeService(
        offerID: UUID,
        userID: UUID,
        serviceKind: PostSaleConciergeServiceKind,
        provider: PostSaleConciergeProvider,
        scheduledFor: Date,
        notes: String,
        estimatedCost: Int?
    ) -> PostSaleConciergeBookingOutcome? {
        guard let offerIndex = offers.firstIndex(where: { $0.id == offerID }) else {
            return nil
        }

        var offer = offers[offerIndex]
        guard offer.buyerID == userID || offer.sellerID == userID,
              offer.settlementCompletedAt != nil,
              provider.serviceKind == serviceKind else {
            return nil
        }

        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let now = Date()
        let actorName = user(id: userID)?.name ?? "A participant"
        let existingBooking = offer.conciergeBooking(for: serviceKind)
        let didReplaceProvider = existingBooking.map { $0.provider.id != provider.id } ?? false
        let preservesProviderHistory = existingBooking?.isCancelled != true &&
            existingBooking?.provider.id == provider.id
        let preservesFinancialState = preservesProviderHistory
        let preservesQuoteApproval = preservesProviderHistory &&
            existingBooking?.estimatedCost == estimatedCost
        let preservesProviderConfirmation = preservesProviderHistory &&
            existingBooking?.scheduledFor == scheduledFor
        let preservesProviderReminderState = preservesProviderHistory &&
            existingBooking?.scheduledFor == scheduledFor
        let didReschedule = preservesProviderHistory &&
            existingBooking?.scheduledFor != scheduledFor
        let providerAuditHistory: [PostSaleConciergeProviderAuditEntry]
        if didReplaceProvider, let existingBooking {
            providerAuditHistory = [
                makePostSaleConciergeProviderAuditEntry(
                    from: existingBooking,
                    replacedAt: now,
                    replacedByUserID: userID,
                    replacedByName: actorName
                )
            ] + (existingBooking.providerAuditHistory ?? [])
        } else {
            providerAuditHistory = existingBooking?.providerAuditHistory ?? []
        }
        let booking = PostSaleConciergeBooking(
            id: existingBooking?.id ?? UUID(),
            serviceKind: serviceKind,
            provider: provider,
            scheduledFor: scheduledFor,
            bookedAt: now,
            bookedByUserID: userID,
            bookedByName: actorName,
            notes: trimmedNotes,
            previousScheduledFor: didReschedule ? existingBooking?.scheduledFor : (preservesProviderHistory ? existingBooking?.previousScheduledFor : nil),
            lastRescheduledAt: didReschedule ? now : (preservesProviderHistory ? existingBooking?.lastRescheduledAt : nil),
            lastRescheduledByUserID: didReschedule ? userID : (preservesProviderHistory ? existingBooking?.lastRescheduledByUserID : nil),
            lastRescheduledByName: didReschedule ? actorName : (preservesProviderHistory ? existingBooking?.lastRescheduledByName : nil),
            rescheduleCount: didReschedule ? (existingBooking?.rescheduleCountValue ?? 0) + 1 : (preservesProviderHistory ? existingBooking?.rescheduleCount : nil),
            estimatedCost: estimatedCost,
            quoteApprovedAt: preservesQuoteApproval ? existingBooking?.quoteApprovedAt : nil,
            quoteApprovedByUserID: preservesQuoteApproval ? existingBooking?.quoteApprovedByUserID : nil,
            quoteApprovedByName: preservesQuoteApproval ? existingBooking?.quoteApprovedByName : nil,
            providerConfirmedAt: preservesProviderConfirmation ? existingBooking?.providerConfirmedAt : nil,
            providerConfirmedByUserID: preservesProviderConfirmation ? existingBooking?.providerConfirmedByUserID : nil,
            providerConfirmedByName: preservesProviderConfirmation ? existingBooking?.providerConfirmedByName : nil,
            providerConfirmationNote: preservesProviderConfirmation ? existingBooking?.providerConfirmationNote : nil,
            reminderSnoozedUntil: preservesProviderReminderState ? existingBooking?.reminderSnoozedUntil : nil,
            lastFollowUpAt: preservesProviderReminderState ? existingBooking?.lastFollowUpAt : nil,
            lastFollowUpByUserID: preservesProviderReminderState ? existingBooking?.lastFollowUpByUserID : nil,
            lastFollowUpByName: preservesProviderReminderState ? existingBooking?.lastFollowUpByName : nil,
            followUpCount: preservesProviderReminderState ? existingBooking?.followUpCount : nil,
            lastFollowUpNote: preservesProviderReminderState ? existingBooking?.lastFollowUpNote : nil,
            invoiceAmount: preservesFinancialState ? existingBooking?.invoiceAmount : nil,
            invoiceFileName: preservesFinancialState ? existingBooking?.invoiceFileName : nil,
            invoiceMimeType: preservesFinancialState ? existingBooking?.invoiceMimeType : nil,
            invoiceAttachmentBase64: preservesFinancialState ? existingBooking?.invoiceAttachmentBase64 : nil,
            invoiceUploadedAt: preservesFinancialState ? existingBooking?.invoiceUploadedAt : nil,
            paidAmount: preservesFinancialState ? existingBooking?.paidAmount : nil,
            paymentConfirmedAt: preservesFinancialState ? existingBooking?.paymentConfirmedAt : nil,
            paymentConfirmedByUserID: preservesFinancialState ? existingBooking?.paymentConfirmedByUserID : nil,
            paymentConfirmedByName: preservesFinancialState ? existingBooking?.paymentConfirmedByName : nil,
            paymentProofFileName: preservesFinancialState ? existingBooking?.paymentProofFileName : nil,
            paymentProofMimeType: preservesFinancialState ? existingBooking?.paymentProofMimeType : nil,
            paymentProofAttachmentBase64: preservesFinancialState ? existingBooking?.paymentProofAttachmentBase64 : nil,
            paymentProofUploadedAt: preservesFinancialState ? existingBooking?.paymentProofUploadedAt : nil,
            cancelledAt: nil,
            cancelledByUserID: nil,
            cancelledByName: nil,
            cancellationReason: nil,
            refundAmount: preservesFinancialState ? existingBooking?.refundAmount : nil,
            refundProcessedAt: preservesFinancialState ? existingBooking?.refundProcessedAt : nil,
            refundProcessedByUserID: preservesFinancialState ? existingBooking?.refundProcessedByUserID : nil,
            refundProcessedByName: preservesFinancialState ? existingBooking?.refundProcessedByName : nil,
            refundNote: preservesFinancialState ? existingBooking?.refundNote : nil,
            issueKind: preservesProviderHistory ? existingBooking?.issueKind : nil,
            issueLoggedAt: preservesProviderHistory ? existingBooking?.issueLoggedAt : nil,
            issueLoggedByUserID: preservesProviderHistory ? existingBooking?.issueLoggedByUserID : nil,
            issueLoggedByName: preservesProviderHistory ? existingBooking?.issueLoggedByName : nil,
            issueNote: preservesProviderHistory ? existingBooking?.issueNote : nil,
            issueResolvedAt: preservesProviderHistory ? existingBooking?.issueResolvedAt : nil,
            issueResolvedByUserID: preservesProviderHistory ? existingBooking?.issueResolvedByUserID : nil,
            issueResolvedByName: preservesProviderHistory ? existingBooking?.issueResolvedByName : nil,
            issueResolutionNote: preservesProviderHistory ? existingBooking?.issueResolutionNote : nil,
            providerAuditHistory: providerAuditHistory,
            status: .scheduled,
            completedAt: nil
        )

        offer.conciergeBookings.removeAll { $0.serviceKind == serviceKind }
        offer.conciergeBookings.insert(booking, at: 0)

        let scheduleString = "\(scheduledFor.formatted(date: .abbreviated, time: .shortened))"
        let title: String
        let body: String
        let quoteSuffix = estimatedCost.map {
            " Quote estimate: \(Currency.aud.string(from: NSNumber(value: $0)) ?? "$\($0)")."
        } ?? ""
        if didReplaceProvider,
           let previousProviderName = existingBooking?.provider.name {
            title = "\(serviceKind.title) provider replaced"
            let archiveSuffix = providerAuditHistory.isEmpty ? "" : " Previous provider history stays in the archive."
            if trimmedNotes.isEmpty {
                body = "\(actorName) changed \(serviceKind.title.lowercased()) from \(previousProviderName) to \(provider.name) for \(scheduleString).\(quoteSuffix)\(archiveSuffix)"
            } else {
                body = "\(actorName) changed \(serviceKind.title.lowercased()) from \(previousProviderName) to \(provider.name) for \(scheduleString).\(quoteSuffix)\(archiveSuffix) Notes: \(trimmedNotes)"
            }
        } else if didReschedule,
           let previousSchedule = existingBooking?.scheduledFor {
            title = "\(serviceKind.title) rescheduled"
            let previousScheduleString = previousSchedule.formatted(date: .abbreviated, time: .shortened)
            if trimmedNotes.isEmpty {
                body = "\(actorName) rescheduled \(serviceKind.title.lowercased()) with \(provider.name) from \(previousScheduleString) to \(scheduleString).\(quoteSuffix)"
            } else {
                body = "\(actorName) rescheduled \(serviceKind.title.lowercased()) with \(provider.name) from \(previousScheduleString) to \(scheduleString).\(quoteSuffix) Notes: \(trimmedNotes)"
            }
        } else if existingBooking == nil {
            title = serviceKind.bookingTitle
            body = "\(actorName) booked \(provider.name) for \(serviceKind.title.lowercased()) on \(scheduleString).\(quoteSuffix)"
        } else {
            title = "\(serviceKind.title) updated"
            if trimmedNotes.isEmpty {
                body = "\(actorName) updated \(serviceKind.title.lowercased()) with \(provider.name) for \(scheduleString).\(quoteSuffix)"
            } else {
                body = "\(actorName) updated \(serviceKind.title.lowercased()) with \(provider.name) for \(scheduleString).\(quoteSuffix) Notes: \(trimmedNotes)"
            }
        }

        offer.updates.insert(
            makeSaleUpdate(
                title: title,
                body: body,
                createdAt: now
            ),
            at: 0
        )

        offers[offerIndex] = offer
        persist()
        syncOfferInBackground(offer)

        return PostSaleConciergeBookingOutcome(
            offer: offer,
            booking: booking,
            threadMessage: body,
            noticeMessage: didReplaceProvider
                ? "\(serviceKind.title) moved to \(provider.name). Previous provider history is preserved in the archive."
                : "\(serviceKind.title) is booked with \(provider.name)."
        )
    }

    @discardableResult
    func confirmPostSaleConciergeProvider(
        offerID: UUID,
        userID: UUID,
        serviceKind: PostSaleConciergeServiceKind,
        note: String
    ) -> PostSaleConciergeBookingOutcome? {
        guard let offerIndex = offers.firstIndex(where: { $0.id == offerID }) else {
            return nil
        }

        var offer = offers[offerIndex]
        guard offer.buyerID == userID || offer.sellerID == userID,
              offer.settlementCompletedAt != nil,
              let bookingIndex = offer.conciergeBookings.firstIndex(where: { $0.serviceKind == serviceKind }) else {
            return nil
        }

        var booking = offer.conciergeBookings[bookingIndex]
        guard booking.isCancelled == false,
              booking.isCompleted == false,
              booking.isProviderConfirmed == false else {
            return nil
        }

        let now = Date()
        let actorName = user(id: userID)?.name ?? "A participant"
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        booking.providerConfirmedAt = now
        booking.providerConfirmedByUserID = userID
        booking.providerConfirmedByName = actorName
        booking.providerConfirmationNote = trimmedNote.isEmpty ? nil : trimmedNote
        booking.reminderSnoozedUntil = nil
        offer.conciergeBookings[bookingIndex] = booking

        let noteSuffix = trimmedNote.isEmpty ? "" : " Note: \(trimmedNote)"
        let body = "\(actorName) marked \(booking.provider.name) as confirmed for \(serviceKind.title.lowercased()).\(noteSuffix)"
        offer.updates.insert(
            makeSaleUpdate(
                title: "\(serviceKind.title) provider confirmed",
                body: body,
                createdAt: now
            ),
            at: 0
        )

        offers[offerIndex] = offer
        persist()
        syncOfferInBackground(offer)

        return PostSaleConciergeBookingOutcome(
            offer: offer,
            booking: booking,
            threadMessage: body,
            noticeMessage: "\(serviceKind.title) provider marked confirmed."
        )
    }

    @discardableResult
    func logPostSaleConciergeFollowUp(
        offerID: UUID,
        userID: UUID,
        serviceKind: PostSaleConciergeServiceKind,
        note: String
    ) -> PostSaleConciergeBookingOutcome? {
        guard let offerIndex = offers.firstIndex(where: { $0.id == offerID }) else {
            return nil
        }

        var offer = offers[offerIndex]
        guard offer.buyerID == userID || offer.sellerID == userID,
              offer.settlementCompletedAt != nil,
              let bookingIndex = offer.conciergeBookings.firstIndex(where: { $0.serviceKind == serviceKind }) else {
            return nil
        }

        var booking = offer.conciergeBookings[bookingIndex]
        guard booking.isCancelled == false,
              booking.isCompleted == false,
              booking.isProviderConfirmed == false else {
            return nil
        }

        let now = Date()
        let actorName = user(id: userID)?.name ?? "A participant"
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        booking.lastFollowUpAt = now
        booking.lastFollowUpByUserID = userID
        booking.lastFollowUpByName = actorName
        booking.followUpCount = booking.followUpCountValue + 1
        booking.lastFollowUpNote = trimmedNote.isEmpty ? nil : trimmedNote
        booking.reminderSnoozedUntil = nil
        offer.conciergeBookings[bookingIndex] = booking

        let noteSuffix = trimmedNote.isEmpty ? "" : " Note: \(trimmedNote)"
        let body = "\(actorName) logged provider follow-up with \(booking.provider.name) for \(serviceKind.title.lowercased()).\(noteSuffix)"
        offer.updates.insert(
            makeSaleUpdate(
                title: "\(serviceKind.title) follow-up logged",
                body: body,
                createdAt: now,
                kind: .reminder,
                checklistItemID: "concierge-\(serviceKind.rawValue)"
            ),
            at: 0
        )

        offers[offerIndex] = offer
        persist()
        syncOfferInBackground(offer)

        return PostSaleConciergeBookingOutcome(
            offer: offer,
            booking: booking,
            threadMessage: body,
            noticeMessage: "\(serviceKind.title) follow-up logged."
        )
    }

    @discardableResult
    func snoozePostSaleConciergeFollowUp(
        offerID: UUID,
        userID: UUID,
        serviceKind: PostSaleConciergeServiceKind,
        until: Date
    ) -> PostSaleConciergeBookingOutcome? {
        guard let offerIndex = offers.firstIndex(where: { $0.id == offerID }) else {
            return nil
        }

        var offer = offers[offerIndex]
        guard offer.buyerID == userID || offer.sellerID == userID,
              offer.settlementCompletedAt != nil,
              let bookingIndex = offer.conciergeBookings.firstIndex(where: { $0.serviceKind == serviceKind }) else {
            return nil
        }

        var booking = offer.conciergeBookings[bookingIndex]
        guard booking.isCancelled == false,
              booking.isCompleted == false,
              booking.isProviderConfirmed == false else {
            return nil
        }

        let now = Date()
        let actorName = user(id: userID)?.name ?? "A participant"
        let snoozedUntil = max(until, now.addingTimeInterval(60 * 15))
        booking.reminderSnoozedUntil = snoozedUntil
        offer.conciergeBookings[bookingIndex] = booking

        let body = "\(actorName) snoozed provider follow-up for \(serviceKind.title.lowercased()) with \(booking.provider.name) until \(snoozedUntil.formatted(date: .abbreviated, time: .shortened))."
        offer.updates.insert(
            makeSaleUpdate(
                title: "\(serviceKind.title) reminder snoozed",
                body: body,
                createdAt: now,
                kind: .reminder,
                checklistItemID: "concierge-\(serviceKind.rawValue)"
            ),
            at: 0
        )

        offers[offerIndex] = offer
        persist()
        syncOfferInBackground(offer)

        return PostSaleConciergeBookingOutcome(
            offer: offer,
            booking: booking,
            threadMessage: body,
            noticeMessage: "\(serviceKind.title) reminder snoozed until \(snoozedUntil.formatted(date: .abbreviated, time: .shortened))."
        )
    }

    @discardableResult
    func logPostSaleConciergeIssue(
        offerID: UUID,
        userID: UUID,
        serviceKind: PostSaleConciergeServiceKind,
        issueKind: PostSaleConciergeIssueKind,
        note: String
    ) -> PostSaleConciergeBookingOutcome? {
        guard let offerIndex = offers.firstIndex(where: { $0.id == offerID }) else {
            return nil
        }

        var offer = offers[offerIndex]
        guard offer.buyerID == userID || offer.sellerID == userID,
              offer.settlementCompletedAt != nil,
              let bookingIndex = offer.conciergeBookings.firstIndex(where: { $0.serviceKind == serviceKind }) else {
            return nil
        }

        var booking = offer.conciergeBookings[bookingIndex]
        guard booking.hasOpenIssue == false else {
            return nil
        }

        let now = Date()
        let actorName = user(id: userID)?.name ?? "A participant"
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        booking.issueKind = issueKind
        booking.issueLoggedAt = now
        booking.issueLoggedByUserID = userID
        booking.issueLoggedByName = actorName
        booking.issueNote = trimmedNote.isEmpty ? nil : trimmedNote
        booking.issueResolvedAt = nil
        booking.issueResolvedByUserID = nil
        booking.issueResolvedByName = nil
        booking.issueResolutionNote = nil
        offer.conciergeBookings[bookingIndex] = booking

        let noteSuffix = trimmedNote.isEmpty ? "" : " Note: \(trimmedNote)"
        let body = "\(actorName) logged a \(issueKind.title.lowercased()) issue for \(serviceKind.title.lowercased()) with \(booking.provider.name).\(noteSuffix)"
        offer.updates.insert(
            makeSaleUpdate(
                title: "\(serviceKind.title) issue logged",
                body: body,
                createdAt: now
            ),
            at: 0
        )

        offers[offerIndex] = offer
        persist()
        syncOfferInBackground(offer)

        return PostSaleConciergeBookingOutcome(
            offer: offer,
            booking: booking,
            threadMessage: body,
            noticeMessage: "\(serviceKind.title) issue logged."
        )
    }

    @discardableResult
    func uploadPostSaleConciergeInvoice(
        offerID: UUID,
        userID: UUID,
        serviceKind: PostSaleConciergeServiceKind,
        fileName: String,
        data: Data,
        mimeType: String,
        invoiceAmount: Int?
    ) -> PostSaleConciergeInvoiceOutcome? {
        guard let offerIndex = offers.firstIndex(where: { $0.id == offerID }) else {
            return nil
        }

        var offer = offers[offerIndex]
        guard offer.buyerID == userID || offer.sellerID == userID,
              offer.settlementCompletedAt != nil,
              let bookingIndex = offer.conciergeBookings.firstIndex(where: { $0.serviceKind == serviceKind }) else {
            return nil
        }

        let now = Date()
        let actorName = user(id: userID)?.name ?? "A participant"
        var booking = offer.conciergeBookings[bookingIndex]
        booking.invoiceAttachmentBase64 = data.base64EncodedString()
        booking.invoiceFileName = fileName
        booking.invoiceMimeType = mimeType
        booking.invoiceUploadedAt = now
        booking.invoiceAmount = invoiceAmount ?? booking.invoiceAmount ?? booking.estimatedCost
        booking.paidAmount = nil
        booking.paymentConfirmedAt = nil
        booking.paymentConfirmedByUserID = nil
        booking.paymentConfirmedByName = nil
        booking.paymentProofFileName = nil
        booking.paymentProofMimeType = nil
        booking.paymentProofAttachmentBase64 = nil
        booking.paymentProofUploadedAt = nil
        offer.conciergeBookings[bookingIndex] = booking

        let invoiceSuffix = booking.invoiceAmount.map {
            " Total: \(Currency.aud.string(from: NSNumber(value: $0)) ?? "$\($0)")."
        } ?? ""
        let body = "\(actorName) uploaded a \(serviceKind.title.lowercased()) invoice from \(booking.provider.name) into the settled archive.\(invoiceSuffix)"
        offer.updates.insert(
            makeSaleUpdate(
                title: "\(serviceKind.title) invoice uploaded",
                body: body,
                createdAt: now
            ),
            at: 0
        )

        offers[offerIndex] = offer
        persist()
        syncOfferInBackground(offer)

        return PostSaleConciergeInvoiceOutcome(
            offer: offer,
            booking: booking,
            threadMessage: body,
            noticeMessage: "\(serviceKind.title) invoice added to the archive."
        )
    }

    @discardableResult
    func approvePostSaleConciergeQuote(
        offerID: UUID,
        userID: UUID,
        serviceKind: PostSaleConciergeServiceKind
    ) -> PostSaleConciergeBookingOutcome? {
        guard let offerIndex = offers.firstIndex(where: { $0.id == offerID }) else {
            return nil
        }

        var offer = offers[offerIndex]
        guard offer.buyerID == userID || offer.sellerID == userID,
              offer.settlementCompletedAt != nil,
              let bookingIndex = offer.conciergeBookings.firstIndex(where: { $0.serviceKind == serviceKind }) else {
            return nil
        }

        var booking = offer.conciergeBookings[bookingIndex]
        guard booking.estimatedCost != nil,
              booking.isQuoteApproved == false else {
            return nil
        }

        let now = Date()
        let actorName = user(id: userID)?.name ?? "A participant"
        booking.quoteApprovedAt = now
        booking.quoteApprovedByUserID = userID
        booking.quoteApprovedByName = actorName
        offer.conciergeBookings[bookingIndex] = booking

        let quoteAmount = booking.estimatedCost.map {
            Currency.aud.string(from: NSNumber(value: $0)) ?? "$\($0)"
        } ?? "the recorded amount"
        let body = "\(actorName) approved the \(serviceKind.title.lowercased()) quote from \(booking.provider.name) at \(quoteAmount)."
        offer.updates.insert(
            makeSaleUpdate(
                title: "\(serviceKind.title) quote approved",
                body: body,
                createdAt: now
            ),
            at: 0
        )

        offers[offerIndex] = offer
        persist()
        syncOfferInBackground(offer)

        return PostSaleConciergeBookingOutcome(
            offer: offer,
            booking: booking,
            threadMessage: body,
            noticeMessage: "\(serviceKind.title) quote approved."
        )
    }

    @discardableResult
    func uploadPostSaleConciergePaymentProof(
        offerID: UUID,
        userID: UUID,
        serviceKind: PostSaleConciergeServiceKind,
        fileName: String,
        data: Data,
        mimeType: String,
        paidAmount: Int?
    ) -> PostSaleConciergePaymentOutcome? {
        guard let offerIndex = offers.firstIndex(where: { $0.id == offerID }) else {
            return nil
        }

        var offer = offers[offerIndex]
        guard offer.buyerID == userID || offer.sellerID == userID,
              offer.settlementCompletedAt != nil,
              let bookingIndex = offer.conciergeBookings.firstIndex(where: { $0.serviceKind == serviceKind }) else {
            return nil
        }

        let now = Date()
        let actorName = user(id: userID)?.name ?? "A participant"
        var booking = offer.conciergeBookings[bookingIndex]
        guard booking.invoiceAmount != nil || booking.hasInvoiceAttachment || booking.estimatedCost != nil else {
            return nil
        }

        if booking.quoteApprovedAt == nil {
            booking.quoteApprovedAt = now
            booking.quoteApprovedByUserID = userID
            booking.quoteApprovedByName = actorName
        }

        booking.paymentProofAttachmentBase64 = data.base64EncodedString()
        booking.paymentProofFileName = fileName
        booking.paymentProofMimeType = mimeType
        booking.paymentProofUploadedAt = now
        booking.paidAmount = paidAmount ?? booking.paidAmount ?? booking.invoiceAmount ?? booking.estimatedCost
        booking.paymentConfirmedAt = now
        booking.paymentConfirmedByUserID = userID
        booking.paymentConfirmedByName = actorName
        offer.conciergeBookings[bookingIndex] = booking

        let paidSuffix = booking.paidAmount.map {
            " Paid total: \(Currency.aud.string(from: NSNumber(value: $0)) ?? "$\($0)")."
        } ?? ""
        let body = "\(actorName) uploaded payment proof for \(serviceKind.title.lowercased()) with \(booking.provider.name).\(paidSuffix)"
        offer.updates.insert(
            makeSaleUpdate(
                title: "\(serviceKind.title) payment confirmed",
                body: body,
                createdAt: now
            ),
            at: 0
        )

        offers[offerIndex] = offer
        persist()
        syncOfferInBackground(offer)

        return PostSaleConciergePaymentOutcome(
            offer: offer,
            booking: booking,
            threadMessage: body,
            noticeMessage: "\(serviceKind.title) payment proof saved."
        )
    }

    @discardableResult
    func cancelPostSaleConciergeBooking(
        offerID: UUID,
        userID: UUID,
        serviceKind: PostSaleConciergeServiceKind,
        reason: String
    ) -> PostSaleConciergeBookingOutcome? {
        guard let offerIndex = offers.firstIndex(where: { $0.id == offerID }) else {
            return nil
        }

        var offer = offers[offerIndex]
        guard offer.buyerID == userID || offer.sellerID == userID,
              offer.settlementCompletedAt != nil,
              let bookingIndex = offer.conciergeBookings.firstIndex(where: { $0.serviceKind == serviceKind }) else {
            return nil
        }

        var booking = offer.conciergeBookings[bookingIndex]
        guard booking.isCancelled == false,
              booking.isCompleted == false else {
            return nil
        }

        let now = Date()
        let actorName = user(id: userID)?.name ?? "A participant"
        let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        booking.status = .cancelled
        booking.cancelledAt = now
        booking.cancelledByUserID = userID
        booking.cancelledByName = actorName
        booking.cancellationReason = trimmedReason.isEmpty ? nil : trimmedReason
        booking.reminderSnoozedUntil = nil
        offer.conciergeBookings[bookingIndex] = booking

        let reasonSuffix = trimmedReason.isEmpty ? "" : " Reason: \(trimmedReason)"
        let body = "\(actorName) cancelled the \(serviceKind.title.lowercased()) booking with \(booking.provider.name).\(reasonSuffix)"
        offer.updates.insert(
            makeSaleUpdate(
                title: "\(serviceKind.title) cancelled",
                body: body,
                createdAt: now
            ),
            at: 0
        )

        offers[offerIndex] = offer
        persist()
        syncOfferInBackground(offer)

        return PostSaleConciergeBookingOutcome(
            offer: offer,
            booking: booking,
            threadMessage: body,
            noticeMessage: "\(serviceKind.title) booking cancelled."
        )
    }

    @discardableResult
    func recordPostSaleConciergeRefund(
        offerID: UUID,
        userID: UUID,
        serviceKind: PostSaleConciergeServiceKind,
        refundAmount: Int?,
        note: String
    ) -> PostSaleConciergeBookingOutcome? {
        guard let offerIndex = offers.firstIndex(where: { $0.id == offerID }) else {
            return nil
        }

        var offer = offers[offerIndex]
        guard offer.buyerID == userID || offer.sellerID == userID,
              offer.settlementCompletedAt != nil,
              let bookingIndex = offer.conciergeBookings.firstIndex(where: { $0.serviceKind == serviceKind }) else {
            return nil
        }

        var booking = offer.conciergeBookings[bookingIndex]
        guard booking.isRefunded == false,
              booking.isPaid || booking.hasPaymentProof || booking.invoiceAmount != nil || booking.hasInvoiceAttachment else {
            return nil
        }

        let now = Date()
        let actorName = user(id: userID)?.name ?? "A participant"
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        booking.refundAmount = refundAmount ?? booking.paidAmount ?? booking.invoiceAmount ?? booking.estimatedCost
        booking.refundProcessedAt = now
        booking.refundProcessedByUserID = userID
        booking.refundProcessedByName = actorName
        booking.refundNote = trimmedNote.isEmpty ? nil : trimmedNote
        booking.reminderSnoozedUntil = nil
        offer.conciergeBookings[bookingIndex] = booking

        let amountLabel = booking.refundAmount.map {
            Currency.aud.string(from: NSNumber(value: $0)) ?? "$\($0)"
        } ?? "the recorded amount"
        let noteSuffix = trimmedNote.isEmpty ? "" : " Note: \(trimmedNote)"
        let body = "\(actorName) recorded a \(serviceKind.title.lowercased()) refund from \(booking.provider.name) for \(amountLabel).\(noteSuffix)"
        offer.updates.insert(
            makeSaleUpdate(
                title: "\(serviceKind.title) refund recorded",
                body: body,
                createdAt: now
            ),
            at: 0
        )

        offers[offerIndex] = offer
        persist()
        syncOfferInBackground(offer)

        return PostSaleConciergeBookingOutcome(
            offer: offer,
            booking: booking,
            threadMessage: body,
            noticeMessage: "\(serviceKind.title) refund recorded."
        )
    }

    @discardableResult
    func resolvePostSaleConciergeIssue(
        offerID: UUID,
        userID: UUID,
        serviceKind: PostSaleConciergeServiceKind,
        resolutionNote: String
    ) -> PostSaleConciergeBookingOutcome? {
        guard let offerIndex = offers.firstIndex(where: { $0.id == offerID }) else {
            return nil
        }

        var offer = offers[offerIndex]
        guard offer.buyerID == userID || offer.sellerID == userID,
              offer.settlementCompletedAt != nil,
              let bookingIndex = offer.conciergeBookings.firstIndex(where: { $0.serviceKind == serviceKind }) else {
            return nil
        }

        var booking = offer.conciergeBookings[bookingIndex]
        guard booking.hasOpenIssue else {
            return nil
        }

        let now = Date()
        let actorName = user(id: userID)?.name ?? "A participant"
        let trimmedNote = resolutionNote.trimmingCharacters(in: .whitespacesAndNewlines)
        booking.issueResolvedAt = now
        booking.issueResolvedByUserID = userID
        booking.issueResolvedByName = actorName
        booking.issueResolutionNote = trimmedNote.isEmpty ? nil : trimmedNote
        offer.conciergeBookings[bookingIndex] = booking

        let noteSuffix = trimmedNote.isEmpty ? "" : " Resolution: \(trimmedNote)"
        let issueLabel = booking.issueKind?.title.lowercased() ?? "service"
        let body = "\(actorName) resolved the \(issueLabel) issue for \(serviceKind.title.lowercased()) with \(booking.provider.name).\(noteSuffix)"
        offer.updates.insert(
            makeSaleUpdate(
                title: "\(serviceKind.title) issue resolved",
                body: body,
                createdAt: now
            ),
            at: 0
        )

        offers[offerIndex] = offer
        persist()
        syncOfferInBackground(offer)

        return PostSaleConciergeBookingOutcome(
            offer: offer,
            booking: booking,
            threadMessage: body,
            noticeMessage: "\(serviceKind.title) issue resolved."
        )
    }

    @discardableResult
    func completePostSaleConciergeBooking(
        offerID: UUID,
        userID: UUID,
        serviceKind: PostSaleConciergeServiceKind
    ) -> PostSaleConciergeBookingOutcome? {
        guard let offerIndex = offers.firstIndex(where: { $0.id == offerID }) else {
            return nil
        }

        var offer = offers[offerIndex]
        guard offer.buyerID == userID || offer.sellerID == userID,
              offer.settlementCompletedAt != nil,
              let bookingIndex = offer.conciergeBookings.firstIndex(where: {
                  $0.serviceKind == serviceKind && !$0.isCompleted && !$0.isCancelled
              }) else {
            return nil
        }

        let now = Date()
        var booking = offer.conciergeBookings[bookingIndex]
        booking.status = .completed
        booking.completedAt = now
        booking.reminderSnoozedUntil = nil
        offer.conciergeBookings[bookingIndex] = booking

        let actorName = user(id: userID)?.name ?? "A participant"
        let body = "\(actorName) marked \(serviceKind.title.lowercased()) complete with \(booking.provider.name) for this settled deal."
        offer.updates.insert(
            makeSaleUpdate(
                title: serviceKind.completionTitle,
                body: body,
                createdAt: now
            ),
            at: 0
        )

        offers[offerIndex] = offer
        persist()
        syncOfferInBackground(offer)

        return PostSaleConciergeBookingOutcome(
            offer: offer,
            booking: booking,
            threadMessage: body,
            noticeMessage: "\(serviceKind.title) marked complete in the archive."
        )
    }

    @discardableResult
    func submitPostSaleFeedback(
        offerID: UUID,
        userID: UUID,
        rating: Int,
        notes: String
    ) -> PostSaleFeedbackOutcome? {
        guard let offerIndex = offers.firstIndex(where: { $0.id == offerID }),
              (1...5).contains(rating) else {
            return nil
        }

        var offer = offers[offerIndex]
        guard offer.buyerID == userID || offer.sellerID == userID,
              offer.settlementCompletedAt != nil else {
            return nil
        }

        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNotes.isEmpty else {
            return nil
        }

        let now = Date()
        let actorName = user(id: userID)?.name ?? "A participant"
        let entry = PostSaleFeedbackEntry(
            submittedAt: now,
            rating: rating,
            notes: trimmedNotes,
            submittedByUserID: userID,
            submittedByName: actorName
        )
        let title: String

        if userID == offer.buyerID {
            title = offer.buyerFeedback == nil ? "Buyer feedback submitted" : "Buyer feedback updated"
            offer.buyerFeedback = entry
        } else {
            title = offer.sellerFeedback == nil ? "Seller feedback submitted" : "Seller feedback updated"
            offer.sellerFeedback = entry
        }

        let body = "\(actorName) left post-sale feedback with a \(rating)-star rating for this settled private sale."
        offer.updates.insert(
            makeSaleUpdate(
                title: title,
                body: body,
                createdAt: now
            ),
            at: 0
        )

        offers[offerIndex] = offer
        persist()
        syncOfferInBackground(offer)

        return PostSaleFeedbackOutcome(
            offer: offer,
            threadMessage: body,
            noticeMessage: "Post-sale feedback saved to the settlement archive."
        )
    }

    func createListing(from draft: ListingDraft, sellerID: UUID) throws {
        if let moderationIssue = MarketplaceSafetyPolicy.moderationIssue(for: draft.title) ??
            MarketplaceSafetyPolicy.moderationIssue(for: draft.headline) ??
            MarketplaceSafetyPolicy.moderationIssue(for: draft.summary) {
            throw moderationIssue
        }

        guard let askingPrice = Int(draft.priceText.filter(\.isNumber)) else { return }

        let features = draft.featuresText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
        let inspectionStart = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: tomorrow) ?? tomorrow
        let inspectionEnd = Calendar.current.date(byAdding: .minute, value: 30, to: inspectionStart) ?? inspectionStart

        let listing = PropertyListing(
            id: UUID(),
            title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
            headline: draft.headline.trimmingCharacters(in: .whitespacesAndNewlines),
            summary: draft.summary.trimmingCharacters(in: .whitespacesAndNewlines),
            propertyType: draft.propertyType,
            status: .active,
            address: PropertyAddress(
                street: draft.street.trimmingCharacters(in: .whitespacesAndNewlines),
                suburb: draft.suburb.trimmingCharacters(in: .whitespacesAndNewlines),
                state: draft.state.trimmingCharacters(in: .whitespacesAndNewlines),
                postcode: draft.postcode.trimmingCharacters(in: .whitespacesAndNewlines)
            ),
            askingPrice: askingPrice,
            bedrooms: draft.bedrooms,
            bathrooms: draft.bathrooms,
            parkingSpaces: draft.parkingSpaces,
            landSizeText: draft.landSizeText.trimmingCharacters(in: .whitespacesAndNewlines),
            features: features,
            sellerID: sellerID,
            inspectionSlots: [
                InspectionSlot(
                    id: UUID(),
                    startsAt: inspectionStart,
                    endsAt: inspectionEnd,
                    note: "First private inspection"
                )
            ],
            marketPulse: MarketPulse(
                valueEstimateLow: max(askingPrice - 45000, 0),
                valueEstimateHigh: askingPrice + 45000,
                suburbMedian: max(askingPrice - 70000, 0),
                buyerDemandScore: 71,
                averageDaysOnMarket: 26,
                schoolInsight: SchoolInsight(
                    catchmentName: "\(draft.suburb) State School",
                    walkMinutes: 12,
                    score: 78
                )
            ),
            comparableSales: [],
            priceJourney: [
                ListingPriceEvent(
                    id: UUID(),
                    amount: askingPrice,
                    recordedAt: .now,
                    note: "Listed privately on Real O Who"
                )
            ],
            palette: .ocean,
            latitude: draft.latitude,
            longitude: draft.longitude,
            isFeatured: false,
            publishedAt: .now,
            updatedAt: .now
        )

        listings.insert(listing, at: 0)
        persist()
        syncListingInBackground(listing)
    }

    @discardableResult
    func repriceListing(
        listingID: UUID,
        sellerID: UUID,
        newPrice: Int,
        note: String
    ) throws -> ListingRepriceOutcome {
        guard let listingIndex = listings.firstIndex(where: { $0.id == listingID }) else {
            throw ListingRepriceError.listingUnavailable
        }

        if let moderationIssue = MarketplaceSafetyPolicy.moderationIssue(for: note) {
            throw moderationIssue
        }

        guard listings[listingIndex].sellerID == sellerID else {
            throw ListingRepriceError.notYourListing
        }

        guard newPrice > 0 else {
            throw ListingRepriceError.invalidPrice
        }

        let currentListing = listings[listingIndex]
        guard currentListing.status == .active || currentListing.status == .draft else {
            throw ListingRepriceError.listingLocked
        }

        guard currentListing.askingPrice != newPrice else {
            throw ListingRepriceError.samePrice
        }

        let now = Date()
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let previousPrice = currentListing.askingPrice
        let changeAmount = newPrice - previousPrice
        let directionNote: String
        if changeAmount < 0 {
            directionNote = "Owner reduced the asking price by \(Currency.aud.string(from: NSNumber(value: abs(changeAmount))) ?? "$\(abs(changeAmount))")."
        } else {
            directionNote = "Owner increased the asking price by \(Currency.aud.string(from: NSNumber(value: changeAmount)) ?? "$\(changeAmount)")."
        }
        let eventNote = trimmedNote.isEmpty ? directionNote : trimmedNote

        var updatedListing = currentListing
        updatedListing.askingPrice = newPrice
        updatedListing.updatedAt = now
        updatedListing.priceJourney.insert(
            ListingPriceEvent(
                id: UUID(),
                amount: newPrice,
                recordedAt: now,
                note: eventNote
            ),
            at: 0
        )
        listings[listingIndex] = updatedListing

        let formattedPreviousPrice = Currency.aud.string(from: NSNumber(value: previousPrice)) ?? "$\(previousPrice)"
        let formattedNewPrice = Currency.aud.string(from: NSNumber(value: newPrice)) ?? "$\(newPrice)"
        let repricingBody = trimmedNote.isEmpty
            ? "Seller updated the asking price from \(formattedPreviousPrice) to \(formattedNewPrice)."
            : "Seller updated the asking price from \(formattedPreviousPrice) to \(formattedNewPrice). Note: \(trimmedNote)"

        var impactedOffers: [OfferRecord] = []
        for offerIndex in offers.indices {
            guard offers[offerIndex].listingID == listingID,
                  offers[offerIndex].contractPacket?.isFullySigned != true else {
                continue
            }

            offers[offerIndex].updates.insert(
                makeSaleUpdate(
                    title: "Asking price updated",
                    body: repricingBody,
                    createdAt: now
                ),
                at: 0
            )
            impactedOffers.append(offers[offerIndex])
        }

        persist()
        syncListingInBackground(updatedListing)
        impactedOffers.forEach(syncOfferInBackground)

        let noticeMessage = "Listing repriced from \(formattedPreviousPrice) to \(formattedNewPrice). The price journey and seller tools are now updated."

        return ListingRepriceOutcome(
            listing: updatedListing,
            previousPrice: previousPrice,
            impactedOffers: impactedOffers,
            threadMessage: repricingBody,
            noticeMessage: noticeMessage
        )
    }

    private func load() {
        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )

            guard fileManager.fileExists(atPath: fileURL.path) else { return }

            let data = try Data(contentsOf: fileURL)
            let snapshot = try decoder.decode(MarketplaceSnapshot.self, from: data)
            users = snapshot.users
            authAccounts = snapshot.authAccounts
            listings = snapshot.listings
            userMarketplaceStatesByID = Dictionary(
                uniqueKeysWithValues: snapshot.userMarketplaceStates.map { ($0.userID, $0) }
            )
            savedSearches = snapshot.savedSearches
            favoriteListingIDs = snapshot.favoriteListingIDs
            plannedInspectionIDs = snapshot.plannedInspectionIDs
            offers = snapshot.offers
            currentUserID = snapshot.currentUserID
            sessionUserID = snapshot.sessionUserID

            if let sessionUserID, users.contains(where: { $0.id == sessionUserID }) {
                currentUserID = sessionUserID
            } else if !users.contains(where: { $0.id == currentUserID }), let firstUser = users.first {
                currentUserID = firstUser.id
            }

            restoreMarketplaceState(for: currentUserID)
        } catch {
            assertionFailure("Failed to load marketplace state: \(error.localizedDescription)")
        }
    }

    private func persist() {
        guard !isEphemeral else { return }

        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )

            if users.contains(where: { $0.id == currentUserID }) {
                userMarketplaceStatesByID[currentUserID] = makeCurrentUserMarketplaceState()
            }

            let snapshot = MarketplaceSnapshot(
                users: users,
                authAccounts: authAccounts,
                listings: listings,
                savedSearches: savedSearches,
                favoriteListingIDs: favoriteListingIDs,
                userMarketplaceStates: userMarketplaceStatesByID.values.sorted { $0.userID.uuidString < $1.userID.uuidString },
                plannedInspectionIDs: plannedInspectionIDs,
                offers: offers,
                currentUserID: currentUserID,
                sessionUserID: sessionUserID
            )

            let data = try encoder.encode(snapshot)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            assertionFailure("Failed to persist marketplace state: \(error.localizedDescription)")
        }
    }

    private func mergeRemoteSale(_ remoteOffer: OfferRecord) {
        if let offerIndex = offers.firstIndex(where: { $0.listingID == remoteOffer.listingID }) {
            offers[offerIndex] = mergeOffer(remoteOffer, existing: offers[offerIndex])
        } else {
            offers.insert(remoteOffer, at: 0)
        }

        if let listingIndex = listings.firstIndex(where: { $0.id == remoteOffer.listingID }) {
            listings[listingIndex].status = remoteOffer.listingStatus
            listings[listingIndex].updatedAt = .now
        }

        persist()
    }

    private func replaceOffers(_ remoteOffers: [OfferRecord]) {
        let existingOffersByListingID = Dictionary(uniqueKeysWithValues: offers.map { ($0.listingID, $0) })
        offers = remoteOffers.map { remoteOffer in
            if let existingOffer = existingOffersByListingID[remoteOffer.listingID] {
                return mergeOffer(remoteOffer, existing: existingOffer)
            }
            return remoteOffer
        }
        .sorted { left, right in
            if left.createdAt == right.createdAt {
                return left.id.uuidString > right.id.uuidString
            }
            return left.createdAt > right.createdAt
        }
        persist()
    }

    private func mergeRemoteListings(_ remoteListings: [PropertyListing]) {
        var mergedByID = Dictionary(uniqueKeysWithValues: listings.map { ($0.id, $0) })
        for listing in remoteListings {
            mergedByID[listing.id] = listing
        }

        listings = mergedByID.values.sorted { left, right in
            if left.updatedAt == right.updatedAt {
                return left.publishedAt > right.publishedAt
            }
            return left.updatedAt > right.updatedAt
        }
        persist()
    }

    private func mergeRemoteMarketplaceState(_ remoteState: UserMarketplaceState) {
        userMarketplaceStatesByID[remoteState.userID] = remoteState

        if remoteState.userID == currentUserID {
            favoriteListingIDs = remoteState.favoriteListingIDs
            savedSearches = remoteState.savedSearches
        }

        persist()
    }

    private func makeCurrentUserMarketplaceState() -> UserMarketplaceState {
        UserMarketplaceState(
            userID: currentUserID,
            favoriteListingIDs: favoriteListingIDs,
            savedSearches: savedSearches
        )
    }

    private func restoreMarketplaceState(for userID: UUID) {
        let state = userMarketplaceStatesByID[userID] ?? MarketplaceSeed.marketplaceState(for: userID)
        userMarketplaceStatesByID[userID] = state
        favoriteListingIDs = state.favoriteListingIDs
        savedSearches = state.savedSearches
        offers = offers.filter { $0.buyerID == userID || $0.sellerID == userID }
    }

    private func purgeLocalData(forDeletedUserID userID: UUID) {
        let removedListingIDs = Set(
            listings
                .filter { $0.sellerID == userID }
                .map(\.id)
        )

        users.removeAll { $0.id == userID }
        authAccounts.removeAll { $0.userID == userID }
        listings.removeAll { $0.sellerID == userID }
        offers.removeAll {
            $0.buyerID == userID ||
            $0.sellerID == userID ||
            removedListingIDs.contains($0.listingID)
        }
        userMarketplaceStatesByID.removeValue(forKey: userID)
        legalWorkspaceSession = nil
        inboundLegalInviteCode = nil
        inboundLegalInviteErrorMessage = nil
        inboundSaleReminderTarget = nil

        if sessionUserID == userID {
            sessionUserID = nil
        }

        for listingIndex in listings.indices {
            guard let matchingOffer = offers.first(where: { $0.listingID == listings[listingIndex].id }) else {
                if listings[listingIndex].status != .draft {
                    listings[listingIndex].status = .active
                }
                listings[listingIndex].updatedAt = .now
                continue
            }

            listings[listingIndex].status = matchingOffer.listingStatus
            listings[listingIndex].updatedAt = .now
        }

        if let remainingSessionUserID = sessionUserID,
           users.contains(where: { $0.id == remainingSessionUserID }) {
            currentUserID = remainingSessionUserID
            restoreMarketplaceState(for: remainingSessionUserID)
        } else if let firstRemainingUser = users.first {
            currentUserID = firstRemainingUser.id
            restoreMarketplaceState(for: firstRemainingUser.id)
        } else {
            favoriteListingIDs = []
            savedSearches = []
            plannedInspectionIDs = []
        }
    }

    private func syncMarketplaceStateInBackground() {
        guard !isEphemeral, remoteSyncEnabled, isAuthenticated else { return }

        let state = makeCurrentUserMarketplaceState()
        userMarketplaceStatesByID[currentUserID] = state

        Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                let syncedState = try await self.userStateSync.upsertState(state)
                self.mergeRemoteMarketplaceState(syncedState)
            } catch {
                return
            }
        }
    }

    private func syncListingInBackground(_ listing: PropertyListing) {
        guard !isEphemeral else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                let syncedListing = try await self.listingSync.upsertListing(listing)
                self.mergeRemoteListings([syncedListing])
            } catch {
                return
            }
        }
    }

    private func syncOfferInBackground(_ offer: OfferRecord) {
        guard !isEphemeral else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                let syncedOffer = try await self.saleSync.upsertSale(offer)
                self.mergeRemoteSale(syncedOffer)
            } catch {
                return
            }
        }
    }

    private func markVerificationCheckVerified(
        userID: UUID,
        kind: VerificationCheckKind,
        detail: String,
        verifiedAt: Date = .now,
        evidenceFileName: String? = nil,
        evidenceMimeType: String? = nil,
        evidenceAttachmentBase64: String? = nil,
        evidenceUploadedAt: Date? = nil
    ) -> UserVerificationCheck? {
        guard let userIndex = users.firstIndex(where: { $0.id == userID }) else {
            return nil
        }

        var profile = users[userIndex]
        guard let existingIndex = profile.verificationChecks.firstIndex(where: { $0.kind == kind }) else {
            return nil
        }

        let existingCheck = profile.verificationChecks[existingIndex]
        let resolvedEvidenceFileName = evidenceFileName ?? existingCheck.evidenceFileName
        let resolvedEvidenceMimeType = evidenceMimeType ?? existingCheck.evidenceMimeType
        let resolvedEvidenceAttachmentBase64 = evidenceAttachmentBase64 ?? existingCheck.evidenceAttachmentBase64
        let resolvedEvidenceUploadedAt = evidenceUploadedAt ?? existingCheck.evidenceUploadedAt
        if existingCheck.status == .verified,
           existingCheck.detail == detail,
           existingCheck.evidenceFileName == resolvedEvidenceFileName,
           existingCheck.evidenceMimeType == resolvedEvidenceMimeType,
           existingCheck.evidenceAttachmentBase64 == resolvedEvidenceAttachmentBase64,
           existingCheck.evidenceUploadedAt == resolvedEvidenceUploadedAt {
            return nil
        }

        let updatedCheck = UserVerificationCheck.verified(
            kind,
            detail: detail,
            verifiedAt: verifiedAt,
            evidenceFileName: resolvedEvidenceFileName,
            evidenceMimeType: resolvedEvidenceMimeType,
            evidenceAttachmentBase64: resolvedEvidenceAttachmentBase64,
            evidenceUploadedAt: resolvedEvidenceUploadedAt
        )
        profile.verificationChecks[existingIndex] = updatedCheck
        profile.verificationNote = primaryVerificationNote(for: profile)
        users[userIndex] = profile
        return updatedCheck
    }

    private func unlockContractPacketsForEligibleOffers(
        triggeredBy userID: UUID
    ) -> [VerificationUnlockedContractPacket] {
        var unlocked: [VerificationUnlockedContractPacket] = []

        for offerIndex in offers.indices {
            var offer = offers[offerIndex]
            guard offer.contractPacket == nil,
                  offer.buyerID == userID || offer.sellerID == userID,
                  let buyerRepresentative = offer.buyerLegalSelection?.professional,
                  let sellerRepresentative = offer.sellerLegalSelection?.professional,
                  let packet = prepareContractPacketIfEligible(
                    for: &offer,
                    buyerRepresentative: buyerRepresentative,
                    sellerRepresentative: sellerRepresentative,
                    triggeredBy: userID,
                    forceRefresh: false
                  ) else {
                continue
            }

            offer.updates.insert(
                makeSaleUpdate(
                    title: "Contract packet sent",
                    body: packet.summary
                ),
                at: 0
            )
            offers[offerIndex] = offer
            unlocked.append(
                VerificationUnlockedContractPacket(
                    offer: offer,
                    packet: packet
                )
            )
        }

        return unlocked
    }

    private func attachVerificationEvidenceToRelevantOffers(
        user: UserProfile,
        kind: VerificationCheckKind
    ) -> [UUID] {
        guard let check = user.verificationCheck(for: kind),
              let documentKind = verificationEvidenceDocumentKind(
                for: kind,
                role: user.role
              ) else {
            return []
        }

        var linkedOfferIDs: [UUID] = []

        for offerIndex in offers.indices {
            var offer = offers[offerIndex]
            guard let packet = offer.contractPacket else {
                continue
            }

            switch kind {
            case .finance:
                guard offer.buyerID == user.id else { continue }
            case .ownership:
                guard offer.sellerID == user.id else { continue }
            case .identity, .mobile, .legal:
                continue
            }

            guard let document = makeVerificationWorkspaceDocument(
                kind: documentKind,
                user: user,
                check: check,
                offer: offer,
                packet: packet
            ) else {
                continue
            }

            let existingDocument = offer.documents.first(where: {
                $0.kind == document.kind && $0.packetID == document.packetID
            })
            guard existingDocument != document else {
                continue
            }

            upsertWorkspaceDocument(document, to: &offer)
            offer.updates.insert(
                makeSaleUpdate(
                    title: existingDocument == nil ? document.title : "\(document.title) updated",
                    body: verificationEvidenceWorkspaceUpdate(
                        for: kind,
                        user: user,
                        fileName: document.fileName,
                        isReplacement: existingDocument != nil
                    ),
                    createdAt: document.createdAt
                ),
                at: 0
            )
            offers[offerIndex] = offer
            linkedOfferIDs.append(offer.id)
        }

        return linkedOfferIDs
    }

    private func prepareContractPacketIfEligible(
        for offer: inout OfferRecord,
        buyerRepresentative: LegalProfessional,
        sellerRepresentative: LegalProfessional,
        triggeredBy userID: UUID,
        forceRefresh: Bool
    ) -> ContractPacket? {
        guard canIssueContractPacket(for: offer) else {
            return nil
        }

        guard forceRefresh || offer.contractPacket == nil else {
            return nil
        }

        let packet = makeContractPacket(
            offer: offer,
            buyerRepresentative: buyerRepresentative,
            sellerRepresentative: sellerRepresentative
        )
        offer.contractPacket = packet
        registerInitialWorkspaceMaterials(for: &offer, packet: packet, triggeredBy: userID)
        return packet
    }

    private func canIssueContractPacket(for offer: OfferRecord) -> Bool {
        guard offer.buyerLegalSelection != nil,
              offer.sellerLegalSelection != nil,
              let buyer = user(id: offer.buyerID),
              let seller = user(id: offer.sellerID) else {
            return false
        }

        return buyer.hasVerifiedCheck(.finance) && seller.hasVerifiedCheck(.ownership)
    }

    private func verificationCompletionDetail(
        for kind: VerificationCheckKind,
        userID: UUID
    ) -> String {
        let role = user(id: userID)?.role ?? .buyer

        switch kind {
        case .identity:
            return role == .seller
                ? "Seller identity has been reviewed for secure private-sale access."
                : "Buyer identity has been reviewed for secure private-sale offers."
        case .mobile:
            return "Mobile number confirmed for inspections, sale updates, and secure messages."
        case .finance:
            return "Finance readiness has been confirmed for direct owner negotiations."
        case .ownership:
            return "Ownership evidence has been reviewed for this private property sale."
        case .legal:
            return "Legal coordination is active for this profile."
        }
    }

    private func verificationEvidenceDetail(
        for kind: VerificationCheckKind,
        userID: UUID,
        fileName: String
    ) -> String {
        let role = user(id: userID)?.role ?? .buyer

        switch kind {
        case .finance:
            return "\(fileName) is attached as finance proof so sellers can see this buyer is ready to move."
        case .ownership:
            return "\(fileName) is attached as ownership evidence for this private property sale."
        case .identity:
            return role == .seller
                ? "Seller identity has been reviewed for secure private-sale access."
                : "Buyer identity has been reviewed for secure private-sale offers."
        case .mobile:
            return "Mobile number confirmed for inspections, sale updates, and secure messages."
        case .legal:
            return "Legal coordination is active for this profile."
        }
    }

    private func verificationCompletionNotice(
        for kind: VerificationCheckKind,
        user: UserProfile,
        linkedDealRoomCount: Int,
        unlockedCount: Int
    ) -> String {
        let base: String

        switch kind {
        case .identity:
            base = "Identity check completed for \(user.name)."
        case .mobile:
            base = "Mobile confirmation completed for \(user.name)."
        case .finance:
            base = linkedDealRoomCount > 0
                ? "Finance proof is on file for \(user.name) and attached to \(linkedDealRoomCount) active \(linkedDealRoomCount == 1 ? "deal room" : "deal rooms")."
                : "Finance proof is now on file for \(user.name)."
        case .ownership:
            base = linkedDealRoomCount > 0
                ? "Ownership evidence is on file for \(user.name) and attached to \(linkedDealRoomCount) active \(linkedDealRoomCount == 1 ? "deal room" : "deal rooms")."
                : "Ownership evidence is now on file for \(user.name)."
        case .legal:
            base = "Legal readiness completed for \(user.name)."
        }

        guard unlockedCount > 0 else {
            return base
        }

        let roomLabel = unlockedCount == 1 ? "deal room" : "deal rooms"
        return "\(base) \(unlockedCount) \(roomLabel) just unlocked contract issue."
    }

    private func verificationEvidenceDocumentKind(
        for kind: VerificationCheckKind,
        role: UserRole
    ) -> SaleDocumentKind? {
        switch (kind, role) {
        case (.finance, .buyer):
            return .buyerFinanceProofPDF
        case (.ownership, .seller):
            return .sellerOwnershipEvidencePDF
        default:
            return nil
        }
    }

    private func defaultVerificationEvidenceFileName(
        for kind: VerificationCheckKind,
        userID: UUID
    ) -> String {
        let suburbSlug = user(id: userID)?
            .suburb
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: ",", with: "")
            ?? "profile"

        switch kind {
        case .finance:
            return "real-o-who-finance-proof-\(suburbSlug).pdf"
        case .ownership:
            return "real-o-who-ownership-evidence-\(suburbSlug).pdf"
        case .identity:
            return "real-o-who-identity-check-\(suburbSlug).pdf"
        case .mobile:
            return "real-o-who-mobile-confirmation-\(suburbSlug).pdf"
        case .legal:
            return "real-o-who-legal-readiness-\(suburbSlug).pdf"
        }
    }

    private func verificationEvidenceWorkspaceUpdate(
        for kind: VerificationCheckKind,
        user: UserProfile,
        fileName: String,
        isReplacement: Bool
    ) -> String {
        switch kind {
        case .finance:
            return isReplacement
                ? "\(user.name) replaced the buyer finance proof with \(fileName). The active deal room now points to the latest pre-approval PDF."
                : "\(user.name) attached buyer finance proof as \(fileName) so the sale can move forward with document-backed finance readiness."
        case .ownership:
            return isReplacement
                ? "\(user.name) replaced the seller ownership evidence with \(fileName). The active deal room now points to the latest ownership PDF."
                : "\(user.name) attached seller ownership evidence as \(fileName) so the sale can move forward with document-backed ownership review."
        case .identity, .mobile, .legal:
            return "\(user.name) updated a verification document."
        }
    }

    private func primaryVerificationNote(for user: UserProfile) -> String {
        if user.hasVerifiedCheck(.ownership) {
            return "Ownership documents reviewed"
        }

        if user.hasVerifiedCheck(.finance) {
            return "Finance pre-approval uploaded"
        }

        if user.hasVerifiedCheck(.identity) && user.hasVerifiedCheck(.mobile) {
            return "Identity and mobile verified"
        }

        if user.hasVerifiedCheck(.legal) {
            return "Legal readiness confirmed"
        }

        return "Verification in progress"
    }

    private func makeContractPacket(
        offer: OfferRecord,
        buyerRepresentative: LegalProfessional,
        sellerRepresentative: LegalProfessional
    ) -> ContractPacket {
        let formattedAmount = Currency.aud.string(from: NSNumber(value: offer.amount)) ?? "$\(offer.amount)"
        let summary = """
        Contract packet prepared for \(formattedAmount).
        Buyer legal representative: \(buyerRepresentative.name), \(buyerRepresentative.primarySpecialty).
        Seller legal representative: \(sellerRepresentative.name), \(sellerRepresentative.primarySpecialty).
        Next step: both parties review and sign through their chosen legal contacts.
        """

        return ContractPacket(
            id: UUID(),
            generatedAt: .now,
            listingID: offer.listingID,
            offerID: offer.id,
            buyerID: offer.buyerID,
            sellerID: offer.sellerID,
            buyerRepresentative: buyerRepresentative,
            sellerRepresentative: sellerRepresentative,
            summary: summary,
            buyerSignedAt: nil,
            sellerSignedAt: nil
        )
    }

    private func mergeOffer(_ remoteOffer: OfferRecord, existing: OfferRecord) -> OfferRecord {
        var mergedOffer = remoteOffer
        if remoteOffer.updates.isEmpty {
            mergedOffer.updates = existing.updates
        }
        if remoteOffer.invites.isEmpty {
            mergedOffer.invites = existing.invites
        }
        if remoteOffer.documents.isEmpty {
            mergedOffer.documents = existing.documents
        }
        if remoteOffer.settlementCompletedAt == nil {
            mergedOffer.settlementCompletedAt = existing.settlementCompletedAt
        }
        if remoteOffer.utilitiesTransferCompletedAt == nil {
            mergedOffer.utilitiesTransferCompletedAt = existing.utilitiesTransferCompletedAt
        }
        if remoteOffer.addressUpdateCompletedAt == nil {
            mergedOffer.addressUpdateCompletedAt = existing.addressUpdateCompletedAt
        }
        if remoteOffer.buyerFeedback == nil {
            mergedOffer.buyerFeedback = existing.buyerFeedback
        }
        if remoteOffer.sellerFeedback == nil {
            mergedOffer.sellerFeedback = existing.sellerFeedback
        }
        if remoteOffer.conciergeBookings.isEmpty {
            mergedOffer.conciergeBookings = existing.conciergeBookings
        }
        return mergedOffer
    }

    private func applyLegalWorkspaceAccess(
        listing: PropertyListing,
        offer: OfferRecord,
        invite: SaleWorkspaceInvite
    ) {
        mergeRemoteListings([listing])
        mergeRemoteSale(offer)
        legalWorkspaceSession = LegalWorkspaceSession(
            listingID: listing.id,
            offerID: offer.id,
            invite: invite
        )
    }

    private func localLegalWorkspace(inviteCode: String) -> (listing: PropertyListing, offer: OfferRecord, invite: SaleWorkspaceInvite)? {
        for offer in offers {
            guard let invite = offer.invites.first(where: {
                $0.shareCode.caseInsensitiveCompare(inviteCode) == .orderedSame
            }),
            let listing = listing(id: offer.listingID) else {
                continue
            }

            return (listing: listing, offer: offer, invite: invite)
        }

        return nil
    }

    private func activateLocalLegalWorkspaceIfNeeded(
        _ workspace: (listing: PropertyListing, offer: OfferRecord, invite: SaleWorkspaceInvite)
    ) -> (listing: PropertyListing, offer: OfferRecord, invite: SaleWorkspaceInvite) {
        guard workspace.invite.activatedAt == nil,
              let offerIndex = offers.firstIndex(where: { $0.id == workspace.offer.id }),
              let inviteIndex = offers[offerIndex].invites.firstIndex(where: {
                  $0.id == workspace.invite.id ||
                  $0.shareCode.caseInsensitiveCompare(workspace.invite.shareCode) == .orderedSame
              }) else {
            return workspace
        }

        let activatedAt = Date()
        offers[offerIndex].invites[inviteIndex].activatedAt = activatedAt
        let roleTitle = offers[offerIndex].invites[inviteIndex].role.title.lowercased()
        let professionalName = offers[offerIndex].invites[inviteIndex].professionalName
        offers[offerIndex].updates.insert(
            makeSaleUpdate(
                title: "Legal workspace opened",
                body: "\(professionalName) opened the \(roleTitle) using invite code \(offers[offerIndex].invites[inviteIndex].shareCode).",
                createdAt: activatedAt
            ),
            at: 0
        )
        let updatedOffer = offers[offerIndex]
        let updatedInvite = updatedOffer.invites[inviteIndex]
        persist()
        syncOfferInBackground(updatedOffer)

        return (listing: workspace.listing, offer: updatedOffer, invite: updatedInvite)
    }

    private func regenerateWorkspaceInvite(
        currentInvite: SaleWorkspaceInvite,
        offer: OfferRecord,
        triggeredBy userID: UUID,
        createdAt: Date
    ) -> SaleWorkspaceInvite {
        let expiryText = DateFormatter.localizedString(
            from: createdAt.addingTimeInterval(SaleWorkspaceInvite.defaultValidityInterval),
            dateStyle: .medium,
            timeStyle: .none
        )
        let listingLine = listing(id: offer.listingID)?.address.fullLine ?? "the property"
        let generatedByName = user(id: userID)?.name ?? "Real O Who"
        let shareCode = makeWorkspaceInviteCode(role: currentInvite.role)
        let openLink = workspaceInviteOpenLink(for: shareCode)

        return SaleWorkspaceInvite(
            id: UUID(),
            role: currentInvite.role,
            createdAt: createdAt,
            professionalName: currentInvite.professionalName,
            professionalSpecialty: currentInvite.professionalSpecialty,
            shareCode: shareCode,
            shareMessage: """
            Real O Who legal workspace invite
            Invite code: \(shareCode)
            Property: \(listingLine)
            Role: \(currentInvite.role.title)
            Professional: \(currentInvite.professionalName) (\(currentInvite.professionalSpecialty))
            Open in the app: \(openLink)
            Valid until: \(expiryText)
            Tap the link above to open the legal workspace directly. If the app does not open automatically, enter invite code \(shareCode) from the Real O Who start screen.
            Use this invite to review the contract packet, council rates notice, identity check pack, and settlement documents for the private sale.
            """,
            expiresAt: createdAt.addingTimeInterval(SaleWorkspaceInvite.defaultValidityInterval),
            activatedAt: nil,
            revokedAt: nil,
            acknowledgedAt: nil,
            lastSharedAt: nil,
            shareCount: 0,
            generatedByUserID: userID,
            generatedByName: generatedByName
        )
    }

    private func registerInitialWorkspaceMaterials(
        for offer: inout OfferRecord,
        packet: ContractPacket,
        triggeredBy userID: UUID
    ) {
        registerWorkspaceInvite(for: &offer, packet: packet, role: .buyerRepresentative, triggeredBy: userID)
        registerWorkspaceInvite(for: &offer, packet: packet, role: .sellerRepresentative, triggeredBy: userID)
        registerWorkspaceDocument(for: &offer, kind: .contractPacketPDF, packet: packet, triggeredBy: userID, createdAt: packet.generatedAt)
        registerWorkspaceDocument(for: &offer, kind: .councilRatesNoticePDF, packet: packet, triggeredBy: userID, createdAt: packet.generatedAt)
        registerWorkspaceDocument(for: &offer, kind: .identityCheckPackPDF, packet: packet, triggeredBy: userID, createdAt: packet.generatedAt)
        registerVerificationWorkspaceDocument(for: &offer, userID: offer.buyerID, kind: .finance, packet: packet)
        registerVerificationWorkspaceDocument(for: &offer, userID: offer.sellerID, kind: .ownership, packet: packet)
    }

    private func registerCompletionWorkspaceMaterials(
        for offer: inout OfferRecord,
        packet: ContractPacket,
        triggeredBy userID: UUID
    ) {
        registerWorkspaceDocument(for: &offer, kind: .signedContractPDF, packet: packet, triggeredBy: userID, createdAt: .now)
        registerWorkspaceDocument(for: &offer, kind: .settlementStatementPDF, packet: packet, triggeredBy: userID, createdAt: .now)
    }

    private func registerSettlementArchiveMaterials(
        for offer: inout OfferRecord,
        packet: ContractPacket,
        triggeredBy userID: UUID,
        createdAt: Date
    ) {
        registerWorkspaceDocument(for: &offer, kind: .settlementSummaryPDF, packet: packet, triggeredBy: userID, createdAt: createdAt)
        registerWorkspaceDocument(for: &offer, kind: .handoverChecklistPDF, packet: packet, triggeredBy: userID, createdAt: createdAt)
    }

    private func registerWorkspaceDocument(
        for offer: inout OfferRecord,
        kind: SaleDocumentKind,
        packet: ContractPacket,
        triggeredBy userID: UUID,
        createdAt: Date
    ) {
        let document = makeSaleDocument(
            kind: kind,
            offer: offer,
            packet: packet,
            triggeredBy: userID,
            createdAt: createdAt
        )
        appendDocumentIfNeeded(document, to: &offer)
    }

    private func registerVerificationWorkspaceDocument(
        for offer: inout OfferRecord,
        userID: UUID,
        kind: VerificationCheckKind,
        packet: ContractPacket
    ) {
        guard let user = user(id: userID),
              let check = user.verificationCheck(for: kind),
              let documentKind = verificationEvidenceDocumentKind(
                for: kind,
                role: user.role
              ),
              let document = makeVerificationWorkspaceDocument(
                kind: documentKind,
                user: user,
                check: check,
                offer: offer,
                packet: packet
              ) else {
            return
        }

        appendDocumentIfNeeded(document, to: &offer)
    }

    private func registerWorkspaceInvite(
        for offer: inout OfferRecord,
        packet: ContractPacket,
        role: LegalInviteRole,
        triggeredBy userID: UUID
    ) {
        let invite = makeWorkspaceInvite(
            role: role,
            offer: offer,
            packet: packet,
            triggeredBy: userID
        )

        if let existingIndex = offer.invites.firstIndex(where: { $0.role == role }) {
            offer.invites[existingIndex] = invite
        } else {
            offer.invites.insert(invite, at: 0)
        }
    }

    private func appendDocumentIfNeeded(_ document: SaleDocument, to offer: inout OfferRecord) {
        guard !offer.documents.contains(where: { $0.kind == document.kind && $0.packetID == document.packetID }) else {
            return
        }
        offer.documents.insert(document, at: 0)
    }

    private func upsertWorkspaceDocument(_ document: SaleDocument, to offer: inout OfferRecord) {
        if let existingIndex = offer.documents.firstIndex(where: {
            $0.kind == document.kind && $0.packetID == document.packetID
        }) {
            offer.documents[existingIndex] = document
        } else {
            offer.documents.insert(document, at: 0)
        }
    }

    private func makeSaleDocument(
        kind: SaleDocumentKind,
        offer: OfferRecord,
        packet: ContractPacket,
        triggeredBy userID: UUID,
        createdAt: Date
    ) -> SaleDocument {
        let formattedAmount = Currency.aud.string(from: NSNumber(value: offer.amount)) ?? "$\(offer.amount)"
        let uploadedByName = user(id: userID)?.name ?? "Real O Who"
        let documentSummary: String

        switch kind {
        case .contractPacketPDF:
            documentSummary = "Generated contract packet for \(formattedAmount) with both legal representatives attached."
        case .councilRatesNoticePDF:
            documentSummary = "Council rates notice for the property with current owner charges and due dates ready for legal review."
        case .identityCheckPackPDF:
            documentSummary = "Identity check pack covering buyer photo ID, seller ownership verification, and signing readiness."
        case .buyerFinanceProofPDF:
            documentSummary = "Buyer finance proof PDF attached for the sale workspace and legal review."
        case .sellerOwnershipEvidencePDF:
            documentSummary = "Seller ownership evidence PDF attached for the sale workspace and legal review."
        case .signedContractPDF:
            documentSummary = "Signed contract copy for \(formattedAmount) with both buyer and seller signatures recorded."
        case .settlementStatementPDF:
            documentSummary = "Settlement statement for \(formattedAmount) with rates adjustments, balance due, and completion notes."
        case .settlementSummaryPDF:
            documentSummary = "Settlement summary for \(formattedAmount) covering closeout timing, participants, signed terms, and final transaction milestones."
        case .handoverChecklistPDF:
            documentSummary = "Handover checklist for \(formattedAmount) covering keys, utilities, meter reads, final inspection, and move-in closeout steps."
        case .reviewedContractPDF:
            documentSummary = "Reviewed contract PDF with tracked legal notes and final review comments ready for buyer and seller sign-off."
        case .settlementAdjustmentPDF:
            documentSummary = "Settlement adjustment PDF with council rates adjustments, transfer balances, and final settlement figures."
        }

        return SaleDocument(
            id: UUID(),
            kind: kind,
            createdAt: createdAt,
            fileName: makeSaleDocumentFileName(kind: kind, offer: offer),
            summary: documentSummary,
            uploadedByUserID: userID,
            uploadedByName: uploadedByName,
            packetID: packet.id,
            mimeType: nil,
            attachmentBase64: nil
        )
    }

    private func makeVerificationWorkspaceDocument(
        kind: SaleDocumentKind,
        user: UserProfile,
        check: UserVerificationCheck,
        offer: OfferRecord,
        packet: ContractPacket
    ) -> SaleDocument? {
        guard let attachmentBase64 = check.evidenceAttachmentBase64 else {
            return nil
        }

        let fileName = (check.evidenceFileName?.isEmpty == false ? check.evidenceFileName : nil)
            ?? makeSaleDocumentFileName(kind: kind, offer: offer)
        let summary: String

        switch kind {
        case .buyerFinanceProofPDF:
            summary = "\(user.name) uploaded buyer finance proof so the seller and legal representatives can review pre-approval evidence inside the sale workspace."
        case .sellerOwnershipEvidencePDF:
            summary = "\(user.name) uploaded seller ownership evidence so the buyer and legal representatives can review title-side proof inside the sale workspace."
        case .contractPacketPDF,
             .councilRatesNoticePDF,
             .identityCheckPackPDF,
             .signedContractPDF,
             .settlementStatementPDF,
             .settlementSummaryPDF,
             .handoverChecklistPDF,
             .reviewedContractPDF,
             .settlementAdjustmentPDF:
            summary = check.detail
        }

        return SaleDocument(
            id: UUID(),
            kind: kind,
            createdAt: check.evidenceUploadedAt ?? check.verifiedAt ?? .now,
            fileName: fileName,
            summary: summary,
            uploadedByUserID: user.id,
            uploadedByName: user.name,
            packetID: packet.id,
            mimeType: check.evidenceMimeType,
            attachmentBase64: attachmentBase64
        )
    }

    private func makeSaleDocumentFileName(kind: SaleDocumentKind, offer: OfferRecord) -> String {
        let listingLabel = listing(id: offer.listingID)?
            .address
            .suburb
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: ",", with: "")
            ?? "sale"
        let suffix: String
        switch kind {
        case .contractPacketPDF:
            suffix = "contract-packet"
        case .councilRatesNoticePDF:
            suffix = "council-rates"
        case .identityCheckPackPDF:
            suffix = "identity-check-pack"
        case .buyerFinanceProofPDF:
            suffix = "buyer-finance-proof"
        case .sellerOwnershipEvidencePDF:
            suffix = "seller-ownership-evidence"
        case .signedContractPDF:
            suffix = "signed-contract"
        case .settlementStatementPDF:
            suffix = "settlement-statement"
        case .settlementSummaryPDF:
            suffix = "settlement-summary"
        case .handoverChecklistPDF:
            suffix = "handover-checklist"
        case .reviewedContractPDF:
            suffix = "reviewed-contract"
        case .settlementAdjustmentPDF:
            suffix = "settlement-adjustment"
        }
        return "real-o-who-\(suffix)-\(listingLabel).pdf"
    }

    private func makeLegalWorkspaceDocument(
        kind: SaleDocumentKind,
        offer: OfferRecord,
        packet: ContractPacket,
        invite: SaleWorkspaceInvite,
        createdAt: Date,
        fileName: String,
        attachmentBase64: String,
        mimeType: String
    ) -> SaleDocument {
        let summary: String
        switch kind {
        case .reviewedContractPDF:
            summary = "\(invite.professionalName) reviewed the latest contract packet and attached their marked-up contract guidance for the private sale."
        case .settlementAdjustmentPDF:
            summary = "\(invite.professionalName) uploaded settlement adjustments covering rates, balances, and the final settlement breakdown."
        case .settlementSummaryPDF,
             .handoverChecklistPDF,
             .contractPacketPDF,
             .councilRatesNoticePDF,
             .identityCheckPackPDF,
             .buyerFinanceProofPDF,
             .sellerOwnershipEvidencePDF,
             .signedContractPDF,
             .settlementStatementPDF:
            summary = invite.shareMessage
        }

        return SaleDocument(
            id: UUID(),
            kind: kind,
            createdAt: createdAt,
            fileName: fileName,
            summary: summary,
            uploadedByUserID: invite.id,
            uploadedByName: invite.professionalName,
            packetID: packet.id,
            mimeType: mimeType,
            attachmentBase64: attachmentBase64
        )
    }

    private func makeWorkspaceInvite(
        role: LegalInviteRole,
        offer: OfferRecord,
        packet: ContractPacket,
        triggeredBy userID: UUID
    ) -> SaleWorkspaceInvite {
        let professional = role == .buyerRepresentative ? packet.buyerRepresentative : packet.sellerRepresentative
        let listingLine = listing(id: offer.listingID)?.address.fullLine ?? "the property"
        let shareCode = makeWorkspaceInviteCode(role: role)
        let generatedByName = user(id: userID)?.name ?? "Real O Who"
        let expiresAt = packet.generatedAt.addingTimeInterval(SaleWorkspaceInvite.defaultValidityInterval)
        let expiryText = DateFormatter.localizedString(from: expiresAt, dateStyle: .medium, timeStyle: .none)
        let openLink = workspaceInviteOpenLink(for: shareCode)
        let shareMessage = """
        Real O Who legal workspace invite
        Invite code: \(shareCode)
        Property: \(listingLine)
        Role: \(role.title)
        Professional: \(professional.name) (\(professional.primarySpecialty))
        Open in the app: \(openLink)
        Valid until: \(expiryText)
        Tap the link above to open the legal workspace directly. If the app does not open automatically, enter invite code \(shareCode) from the Real O Who start screen.
        Use this invite to review the contract packet, council rates notice, identity check pack, and settlement documents for the private sale.
        """

        return SaleWorkspaceInvite(
            id: UUID(),
            role: role,
            createdAt: packet.generatedAt,
            professionalName: professional.name,
            professionalSpecialty: professional.primarySpecialty,
            shareCode: shareCode,
            shareMessage: shareMessage,
            expiresAt: expiresAt,
            activatedAt: nil,
            revokedAt: nil,
            acknowledgedAt: nil,
            lastSharedAt: nil,
            shareCount: 0,
            generatedByUserID: userID,
            generatedByName: generatedByName
        )
    }

    private func makeWorkspaceInviteCode(role: LegalInviteRole) -> String {
        let prefix = role == .buyerRepresentative ? "BUY" : "SEL"
        let token = UUID().uuidString
            .replacingOccurrences(of: "-", with: "")
            .prefix(10)
            .uppercased()
        return "ROW-\(prefix)-\(token)"
    }

    private func workspaceInviteOpenLink(for shareCode: String) -> String {
        LegalWorkspaceDeepLink.url(for: shareCode)?.absoluteString
            ?? "\(LegalWorkspaceDeepLink.scheme)://\(LegalWorkspaceDeepLink.host)?\(LegalWorkspaceDeepLink.codeQueryItemName)=\(shareCode)"
    }

    private func legalInviteIndex(
        for session: LegalWorkspaceSession,
        offer: OfferRecord
    ) -> Int? {
        offer.invites.firstIndex {
            $0.id == session.inviteID ||
            $0.shareCode.caseInsensitiveCompare(session.inviteCode) == .orderedSame
        }
    }

    private func representedPartyID(
        for role: LegalInviteRole,
        offer: OfferRecord
    ) -> UUID {
        role == .buyerRepresentative ? offer.buyerID : offer.sellerID
    }

    @discardableResult
    func recordReminderTimelineActivity(
        offerID: UUID,
        checklistItemID: String,
        actionTitle: String,
        snoozedUntil: Date? = nil,
        triggeredBy userID: UUID?
    ) -> ReminderTimelineActivityOutcome? {
        guard let offerIndex = offers.firstIndex(where: { $0.id == offerID }) else {
            return nil
        }

        var offer = offers[offerIndex]
        let checklistItem = offer.settlementChecklist.first(where: { $0.id == checklistItemID })
        let checklistTitle = checklistItem?.title ?? "Settlement checklist item"
        let actorName = userID.flatMap(user(id:))?.name ?? "A participant"
        let createdAt = Date()
        let title: String
        let body: String
        let threadMessage: String

        if let snoozedUntil {
            title = "Reminder snoozed"
            body = "\(actorName) snoozed the reminder for \(checklistTitle) until \(snoozedUntil.formatted(date: .abbreviated, time: .shortened))."
            threadMessage = "\(actorName) snoozed follow-up for \(checklistTitle) until \(snoozedUntil.formatted(date: .abbreviated, time: .shortened))."
        } else {
            let actionSummary = reminderActionNarrative(for: actionTitle)
            title = "Reminder completed"
            body = "\(actorName) cleared the reminder for \(checklistTitle) by \(actionSummary)."
            threadMessage = "\(actorName) completed follow-up for \(checklistTitle) by \(actionSummary)."
        }

        if let latestUpdate = offer.updates.first,
           latestUpdate.kind == .reminder,
           latestUpdate.title == title,
           latestUpdate.body == body,
           abs(latestUpdate.createdAt.timeIntervalSince(createdAt)) < 10 {
            return ReminderTimelineActivityOutcome(offer: offer, threadMessage: threadMessage)
        }

        offer.updates.insert(
            makeSaleUpdate(
                title: title,
                body: body,
                createdAt: createdAt,
                kind: .reminder,
                checklistItemID: checklistItemID
            ),
            at: 0
        )
        offers[offerIndex] = offer
        persist()
        syncOfferInBackground(offer)
        return ReminderTimelineActivityOutcome(offer: offer, threadMessage: threadMessage)
    }

    private func reminderActionNarrative(for activityTitle: String) -> String {
        switch activityTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "representative follow-up completed":
                return "completing representative follow-up"
        case "contract packet follow-up completed":
            return "completing contract packet follow-up"
        case "invite sent":
            return "sending the legal invite"
        case "invite follow-up completed":
            return "completing legal invite follow-up"
        case "workspace access follow-up completed":
            return "completing legal workspace access follow-up"
        case "workspace receipt follow-up completed":
            return "completing legal workspace receipt follow-up"
        case "reviewed contract follow-up completed":
            return "completing reviewed contract follow-up"
        case "settlement adjustment follow-up completed":
            return "completing settlement adjustment follow-up"
        case "legal review follow-up completed":
            return "completing legal review follow-up"
        case "signature confirmed":
            return "confirming the signature"
        case "signature follow-up completed":
            return "completing signature follow-up"
        case "settlement statement follow-up completed":
            return "completing settlement statement follow-up"
        case "settlement follow-up completed":
            return "completing settlement follow-up"
        default:
            return activityTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
    }

    private func makePostSaleConciergeProviderAuditEntry(
        from booking: PostSaleConciergeBooking,
        replacedAt: Date,
        replacedByUserID: UUID,
        replacedByName: String
    ) -> PostSaleConciergeProviderAuditEntry {
        PostSaleConciergeProviderAuditEntry(
            id: UUID(),
            provider: booking.provider,
            scheduledFor: booking.scheduledFor,
            notes: booking.notes,
            replacedAt: replacedAt,
            replacedByUserID: replacedByUserID,
            replacedByName: replacedByName,
            estimatedCost: booking.estimatedCost,
            quoteApprovedAt: booking.quoteApprovedAt,
            providerConfirmedAt: booking.providerConfirmedAt,
            providerConfirmationNote: booking.providerConfirmationNote,
            reminderSnoozedUntil: booking.reminderSnoozedUntil,
            lastFollowUpAt: booking.lastFollowUpAt,
            lastFollowUpByName: booking.lastFollowUpByName,
            followUpCount: booking.followUpCount,
            lastFollowUpNote: booking.lastFollowUpNote,
            invoiceAmount: booking.invoiceAmount,
            paidAmount: booking.paidAmount,
            refundAmount: booking.refundAmount,
            issueKind: booking.issueKind,
            issueNote: booking.issueNote,
            issueResolvedAt: booking.issueResolvedAt,
            issueResolutionNote: booking.issueResolutionNote,
            hadInvoiceAttachment: booking.hasInvoiceAttachment,
            hadPaymentProof: booking.hasPaymentProof,
            status: booking.status,
            completedAt: booking.completedAt,
            cancelledAt: booking.cancelledAt,
            cancellationReason: booking.cancellationReason
        )
    }

    private func makeSaleUpdate(
        title: String,
        body: String,
        createdAt: Date = .now,
        kind: SaleUpdateKind = .milestone,
        checklistItemID: String? = nil
    ) -> SaleUpdateMessage {
        SaleUpdateMessage(
            id: UUID(),
            createdAt: createdAt,
            title: title,
            body: body,
            kind: kind,
            checklistItemID: checklistItemID
        )
    }
}

struct SellerDashboardStats {
    var activeListings: Int
    var draftListings: Int
    var totalOffers: Int
    var averageDemandScore: Int
}

struct ConciergeReminderDashboard {
    var intensity: ConciergeReminderIntensity
    var activeBookingCount: Int
    var overdueCount: Int
    var dueSoonCount: Int
    var snoozedCount: Int
    var openIssueCount: Int

    var surfacedDueSoonCount: Int {
        intensity.showsDueSoonAttention ? dueSoonCount : 0
    }

    var surfacedAttentionCount: Int {
        overdueCount + surfacedDueSoonCount
    }

    var hasEscalatedAttention: Bool {
        surfacedAttentionCount > 0
    }

    var headline: String {
        if overdueCount > 0 {
            return overdueCount == 1
                ? "1 overdue provider follow-up needs attention."
                : "\(overdueCount) overdue provider follow-ups need attention."
        }

        if surfacedDueSoonCount > 0 {
            return surfacedDueSoonCount == 1
                ? "1 provider reply window is due soon."
                : "\(surfacedDueSoonCount) provider reply windows are due soon."
        }

        return "No concierge provider follow-ups need attention right now."
    }

    var supportingLine: String {
        if overdueCount > 0 && surfacedDueSoonCount > 0 {
            return "\(surfacedDueSoonCount) more booking\(surfacedDueSoonCount == 1 ? "" : "s") are due soon. Reminder mode: \(intensity.title)."
        }

        if overdueCount > 0 {
            return "Reminder mode: \(intensity.title). Snoozed reminders: \(snoozedCount)."
        }

        if surfacedDueSoonCount > 0 {
            return "Reminder mode: \(intensity.title). We are surfacing upcoming provider reply windows early."
        }

        return intensity.detail
    }
}

struct VerificationUnlockedContractPacket {
    var offer: OfferRecord
    var packet: ContractPacket
}

struct VerificationCompletionOutcome {
    var user: UserProfile
    var completedCheck: UserVerificationCheck
    var unlockedContractPackets: [VerificationUnlockedContractPacket]
    var linkedDealRoomCount: Int
    var noticeMessage: String
}

struct LegalSelectionOutcome {
    var offer: OfferRecord
    var contractPacket: ContractPacket?
}

struct OfferSubmissionOutcome {
    var offer: OfferRecord
    var contractPacket: ContractPacket?
    var isRevision: Bool
}

struct ListingRepriceOutcome {
    var listing: PropertyListing
    var previousPrice: Int
    var impactedOffers: [OfferRecord]
    var threadMessage: String
    var noticeMessage: String
}

struct SellerOfferDispositionOutcome {
    var offer: OfferRecord
    var downgradedOfferIDs: [UUID]
    var noticeMessage: String
}

struct ReminderTimelineActivityOutcome {
    var offer: OfferRecord
    var threadMessage: String
}

struct SellerOfferResponseOutcome {
    var offer: OfferRecord
    var contractPacket: ContractPacket?
    var threadMessage: String
    var noticeMessage: String
}

struct ContractSigningOutcome {
    var offer: OfferRecord
    var threadMessage: String
    var noticeMessage: String
    var didCompleteSale: Bool
}

struct SettlementCompletionOutcome {
    var offer: OfferRecord
    var threadMessage: String
    var noticeMessage: String
}

struct PostSaleServiceOutcome {
    var offer: OfferRecord
    var threadMessage: String
    var noticeMessage: String
}

struct PostSaleConciergeBookingOutcome {
    var offer: OfferRecord
    var booking: PostSaleConciergeBooking
    var threadMessage: String
    var noticeMessage: String
}

struct PostSaleConciergeInvoiceOutcome {
    var offer: OfferRecord
    var booking: PostSaleConciergeBooking
    var threadMessage: String
    var noticeMessage: String
}

struct PostSaleConciergePaymentOutcome {
    var offer: OfferRecord
    var booking: PostSaleConciergeBooking
    var threadMessage: String
    var noticeMessage: String
}

struct PostSaleFeedbackOutcome {
    var offer: OfferRecord
    var threadMessage: String
    var noticeMessage: String
}

struct LegalWorkspaceActionOutcome {
    var offer: OfferRecord
    var representedPartyID: UUID
    var checklistItemID: String
    var threadMessage: String
    var noticeMessage: String
}

enum ListingRepriceError: LocalizedError {
    case listingUnavailable
    case notYourListing
    case invalidPrice
    case samePrice
    case listingLocked

    var errorDescription: String? {
        switch self {
        case .listingUnavailable:
            return "That listing could not be found right now."
        case .notYourListing:
            return "Only the owner of this listing can reprice it."
        case .invalidPrice:
            return "Enter a valid asking price before saving."
        case .samePrice:
            return "The new asking price is the same as the current one."
        case .listingLocked:
            return "This listing can no longer be repriced because it is already under offer or sold."
        }
    }
}

private struct MarketplaceSnapshot: Codable {
    var users: [UserProfile]
    var authAccounts: [LocalAuthAccount]
    var listings: [PropertyListing]
    var savedSearches: [SavedSearch]
    var favoriteListingIDs: Set<UUID>
    var userMarketplaceStates: [UserMarketplaceState]
    var plannedInspectionIDs: Set<UUID>
    var offers: [OfferRecord]
    var currentUserID: UUID
    var sessionUserID: UUID?

    init(
        users: [UserProfile],
        authAccounts: [LocalAuthAccount],
        listings: [PropertyListing],
        savedSearches: [SavedSearch],
        favoriteListingIDs: Set<UUID>,
        userMarketplaceStates: [UserMarketplaceState],
        plannedInspectionIDs: Set<UUID>,
        offers: [OfferRecord],
        currentUserID: UUID,
        sessionUserID: UUID?
    ) {
        self.users = users
        self.authAccounts = authAccounts
        self.listings = listings
        self.savedSearches = savedSearches
        self.favoriteListingIDs = favoriteListingIDs
        self.userMarketplaceStates = userMarketplaceStates
        self.plannedInspectionIDs = plannedInspectionIDs
        self.offers = offers
        self.currentUserID = currentUserID
        self.sessionUserID = sessionUserID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        users = try container.decode([UserProfile].self, forKey: .users)
        authAccounts = try container.decodeIfPresent([LocalAuthAccount].self, forKey: .authAccounts) ?? []
        listings = try container.decode([PropertyListing].self, forKey: .listings)
        savedSearches = try container.decode([SavedSearch].self, forKey: .savedSearches)
        favoriteListingIDs = try container.decode(Set<UUID>.self, forKey: .favoriteListingIDs)
        userMarketplaceStates = try container.decodeIfPresent([UserMarketplaceState].self, forKey: .userMarketplaceStates) ?? []
        plannedInspectionIDs = try container.decode(Set<UUID>.self, forKey: .plannedInspectionIDs)
        offers = try container.decode([OfferRecord].self, forKey: .offers)
        currentUserID = try container.decode(UUID.self, forKey: .currentUserID)
        sessionUserID = try container.decodeIfPresent(UUID.self, forKey: .sessionUserID)

        if userMarketplaceStates.isEmpty {
            userMarketplaceStates = [
                UserMarketplaceState(
                    userID: currentUserID,
                    favoriteListingIDs: favoriteListingIDs,
                    savedSearches: savedSearches
                )
            ]
        }
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
