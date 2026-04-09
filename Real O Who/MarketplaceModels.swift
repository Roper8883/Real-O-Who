import Foundation

nonisolated enum UserRole: String, CaseIterable, Codable, Identifiable, Sendable {
    case buyer
    case seller

    var id: String { rawValue }

    var title: String {
        switch self {
        case .buyer:
            return "Buyer"
        case .seller:
            return "Seller"
        }
    }
}

nonisolated enum PropertyType: String, CaseIterable, Codable, Identifiable, Sendable {
    case house
    case apartment
    case townhouse
    case acreage
    case land

    var id: String { rawValue }

    var title: String {
        switch self {
        case .house:
            return "House"
        case .apartment:
            return "Apartment"
        case .townhouse:
            return "Townhouse"
        case .acreage:
            return "Acreage"
        case .land:
            return "Land"
        }
    }
}

nonisolated enum ListingStatus: String, CaseIterable, Codable, Identifiable, Sendable {
    case active
    case underOffer
    case sold
    case draft

    var id: String { rawValue }

    var title: String {
        switch self {
        case .active:
            return "Active"
        case .underOffer:
            return "Under offer"
        case .sold:
            return "Sold"
        case .draft:
            return "Draft"
        }
    }
}

nonisolated enum OfferStatus: String, CaseIterable, Codable, Identifiable, Sendable {
    case underOffer
    case changesRequested
    case countered
    case accepted

    var id: String { rawValue }

    var title: String {
        switch self {
        case .underOffer:
            return "Under offer"
        case .changesRequested:
            return "Changes requested"
        case .countered:
            return "Counteroffer sent"
        case .accepted:
            return "Accepted"
        }
    }

    var listingStatus: ListingStatus {
        .underOffer
    }
}

nonisolated enum SellerOfferAction: String, CaseIterable, Identifiable, Sendable {
    case accept
    case requestChanges
    case counter

    var id: String { rawValue }

    var title: String {
        switch self {
        case .accept:
            return "Accept Offer"
        case .requestChanges:
            return "Request Changes"
        case .counter:
            return "Send Counteroffer"
        }
    }
}

nonisolated enum ListingSortOrder: String, CaseIterable, Identifiable, Sendable {
    case featured
    case newest
    case priceLowHigh
    case priceHighLow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .featured:
            return "Featured"
        case .newest:
            return "Newest"
        case .priceLowHigh:
            return "Price low-high"
        case .priceHighLow:
            return "Price high-low"
        }
    }
}

nonisolated enum BuyerStage: String, Codable, Sendable {
    case browsing
    case preApproved
    case readyToOffer

    var title: String {
        switch self {
        case .browsing:
            return "Browsing"
        case .preApproved:
            return "Pre-approved"
        case .readyToOffer:
            return "Ready to offer"
        }
    }
}

nonisolated enum ListingPalette: String, Codable, Sendable {
    case ocean
    case sand
    case gumleaf
    case dusk
}

nonisolated struct UserProfile: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var role: UserRole
    var suburb: String
    var headline: String
    var verificationNote: String
    var buyerStage: BuyerStage?

    var initials: String {
        name
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map(String.init)
            .joined()
    }
}

nonisolated struct PropertyAddress: Codable, Hashable, Sendable {
    var street: String
    var suburb: String
    var state: String
    var postcode: String

    var shortLine: String {
        "\(street), \(suburb)"
    }

    var fullLine: String {
        "\(street), \(suburb) \(state) \(postcode)"
    }
}

nonisolated struct InspectionSlot: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var startsAt: Date
    var endsAt: Date
    var note: String
}

nonisolated struct ComparableSale: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var address: String
    var soldPrice: Int
    var soldAt: Date
    var bedrooms: Int
}

nonisolated struct SchoolInsight: Codable, Hashable, Sendable {
    var catchmentName: String
    var walkMinutes: Int
    var score: Int
}

nonisolated struct MarketPulse: Codable, Hashable, Sendable {
    var valueEstimateLow: Int
    var valueEstimateHigh: Int
    var suburbMedian: Int
    var buyerDemandScore: Int
    var averageDaysOnMarket: Int
    var schoolInsight: SchoolInsight
}

nonisolated struct PropertyListing: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var headline: String
    var summary: String
    var propertyType: PropertyType
    var status: ListingStatus
    var address: PropertyAddress
    var askingPrice: Int
    var bedrooms: Int
    var bathrooms: Int
    var parkingSpaces: Int
    var landSizeText: String
    var features: [String]
    var sellerID: UUID
    var inspectionSlots: [InspectionSlot]
    var marketPulse: MarketPulse
    var comparableSales: [ComparableSale]
    var palette: ListingPalette
    var latitude: Double
    var longitude: Double
    var isFeatured: Bool
    var publishedAt: Date
    var updatedAt: Date

    var primaryFactLine: String {
        "\(bedrooms) bed • \(bathrooms) bath • \(parkingSpaces) car"
    }
}

nonisolated struct SavedSearch: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var suburb: String
    var minimumPrice: Int
    var maximumPrice: Int
    var minimumBedrooms: Int
    var propertyTypes: [PropertyType]
    var alertsEnabled: Bool
}

nonisolated struct UserMarketplaceState: Codable, Hashable, Sendable {
    var userID: UUID
    var favoriteListingIDs: Set<UUID>
    var savedSearches: [SavedSearch]
}

nonisolated struct SaleTaskSnapshotViewerState: Codable, Hashable, Sendable {
    var viewerID: String
    var seenUrgentSnapshotKeysByMessageID: [String: String]
    var seenUrgentSnapshotKeysByTaskID: [String: String]
    var seenUrgentSnapshotSeenAtByMessageID: [String: Int64]
    var seenUrgentSnapshotSeenAtByTaskID: [String: Int64]

    init(
        viewerID: String,
        seenUrgentSnapshotKeysByMessageID: [String: String] = [:],
        seenUrgentSnapshotKeysByTaskID: [String: String] = [:],
        seenUrgentSnapshotSeenAtByMessageID: [String: Int64] = [:],
        seenUrgentSnapshotSeenAtByTaskID: [String: Int64] = [:]
    ) {
        self.viewerID = viewerID
        self.seenUrgentSnapshotKeysByMessageID = seenUrgentSnapshotKeysByMessageID
        self.seenUrgentSnapshotKeysByTaskID = seenUrgentSnapshotKeysByTaskID
        self.seenUrgentSnapshotSeenAtByMessageID = seenUrgentSnapshotSeenAtByMessageID
        self.seenUrgentSnapshotSeenAtByTaskID = seenUrgentSnapshotSeenAtByTaskID
    }

    enum CodingKeys: String, CodingKey {
        case viewerID
        case seenUrgentSnapshotKeysByMessageID
        case seenUrgentSnapshotKeysByTaskID
        case seenUrgentSnapshotSeenAtByMessageID
        case seenUrgentSnapshotSeenAtByTaskID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        viewerID = try container.decode(String.self, forKey: .viewerID)
        seenUrgentSnapshotKeysByMessageID =
            try container.decodeIfPresent([String: String].self, forKey: .seenUrgentSnapshotKeysByMessageID) ?? [:]
        seenUrgentSnapshotKeysByTaskID =
            try container.decodeIfPresent([String: String].self, forKey: .seenUrgentSnapshotKeysByTaskID) ?? [:]
        seenUrgentSnapshotSeenAtByMessageID =
            try container.decodeIfPresent([String: Int64].self, forKey: .seenUrgentSnapshotSeenAtByMessageID) ?? [:]
        seenUrgentSnapshotSeenAtByTaskID =
            try container.decodeIfPresent([String: Int64].self, forKey: .seenUrgentSnapshotSeenAtByTaskID) ?? [:]
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(viewerID, forKey: .viewerID)
        try container.encode(seenUrgentSnapshotKeysByMessageID, forKey: .seenUrgentSnapshotKeysByMessageID)
        try container.encode(seenUrgentSnapshotKeysByTaskID, forKey: .seenUrgentSnapshotKeysByTaskID)
        try container.encode(seenUrgentSnapshotSeenAtByMessageID, forKey: .seenUrgentSnapshotSeenAtByMessageID)
        try container.encode(seenUrgentSnapshotSeenAtByTaskID, forKey: .seenUrgentSnapshotSeenAtByTaskID)
    }
}

nonisolated struct SaleTaskSnapshotAudienceMember: Identifiable, Hashable, Sendable {
    let viewerID: String
    let label: String

    var id: String { viewerID }
}

nonisolated struct SaleTaskAudienceSeenEntry: Identifiable, Hashable, Sendable {
    let label: String
    let seenAt: Date

    var id: String {
        "\(label)|\(seenAt.timeIntervalSince1970)"
    }
}

nonisolated struct SaleTaskAudienceStatus: Hashable, Sendable {
    var seenBy: [String]
    var waitingOn: [String]
    var pending: [String]
    var seenEntries: [SaleTaskAudienceSeenEntry]
}

nonisolated enum LegalProfessionalSource: String, Codable, Hashable, Sendable {
    case googlePlaces
    case localFallback

    var title: String {
        switch self {
        case .googlePlaces:
            return "Google local listing"
        case .localFallback:
            return "Offline local directory"
        }
    }
}

nonisolated struct LegalProfessional: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var name: String
    var specialties: [String]
    var address: String
    var suburb: String
    var phoneNumber: String?
    var websiteURL: URL?
    var mapsURL: URL?
    var latitude: Double
    var longitude: Double
    var rating: Double?
    var reviewCount: Int?
    var source: LegalProfessionalSource
    var searchSummary: String

    var primarySpecialty: String {
        specialties.first ?? "Property law support"
    }

    var sourceLine: String {
        "\(source.title) • \(suburb)"
    }
}

nonisolated struct LegalSelection: Codable, Hashable, Sendable {
    var userID: UUID
    var selectedAt: Date
    var professional: LegalProfessional
}

nonisolated struct ContractPacket: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var generatedAt: Date
    var listingID: UUID
    var offerID: UUID
    var buyerID: UUID
    var sellerID: UUID
    var buyerRepresentative: LegalProfessional
    var sellerRepresentative: LegalProfessional
    var summary: String
    var buyerSignedAt: Date?
    var sellerSignedAt: Date?

    var isFullySigned: Bool {
        buyerSignedAt != nil && sellerSignedAt != nil
    }

    func signedAt(for userID: UUID) -> Date? {
        if userID == buyerID {
            return buyerSignedAt
        }

        if userID == sellerID {
            return sellerSignedAt
        }

        return nil
    }
}

nonisolated enum LegalInviteRole: String, Codable, Hashable, Sendable {
    case buyerRepresentative
    case sellerRepresentative

    var title: String {
        switch self {
        case .buyerRepresentative:
            return "Buyer legal rep access"
        case .sellerRepresentative:
            return "Seller legal rep access"
        }
    }

    var symbolName: String {
        switch self {
        case .buyerRepresentative:
            return "person.badge.key.fill"
        case .sellerRepresentative:
            return "person.2.badge.gearshape.fill"
        }
    }

    var audienceLabel: String {
        switch self {
        case .buyerRepresentative:
            return "Buyer legal rep"
        case .sellerRepresentative:
            return "Seller legal rep"
        }
    }
}

nonisolated struct SaleWorkspaceInvite: Identifiable, Codable, Hashable, Sendable {
    static let defaultValidityInterval: TimeInterval = 60 * 60 * 24 * 30
    static let followUpInterval: TimeInterval = 60 * 60 * 48

    let id: UUID
    var role: LegalInviteRole
    var createdAt: Date
    var professionalName: String
    var professionalSpecialty: String
    var shareCode: String
    var shareMessage: String
    var expiresAt: Date
    var activatedAt: Date?
    var revokedAt: Date?
    var acknowledgedAt: Date?
    var lastSharedAt: Date?
    var shareCount: Int
    var generatedByUserID: UUID
    var generatedByName: String

    var isAcknowledged: Bool {
        acknowledgedAt != nil
    }

    var isActivated: Bool {
        activatedAt != nil
    }

    var isExpired: Bool {
        expiresAt < .now
    }

    var isRevoked: Bool {
        revokedAt != nil
    }

    var isUnavailable: Bool {
        isExpired || isRevoked
    }

    var hasBeenShared: Bool {
        shareCount > 0 || lastSharedAt != nil
    }

    var needsFollowUp: Bool {
        guard !isUnavailable,
              activatedAt == nil,
              let lastSharedAt else {
            return false
        }

        return lastSharedAt.addingTimeInterval(Self.followUpInterval) < .now
    }

    init(
        id: UUID,
        role: LegalInviteRole,
        createdAt: Date,
        professionalName: String,
        professionalSpecialty: String,
        shareCode: String,
        shareMessage: String,
        expiresAt: Date,
        activatedAt: Date?,
        revokedAt: Date?,
        acknowledgedAt: Date?,
        lastSharedAt: Date?,
        shareCount: Int,
        generatedByUserID: UUID,
        generatedByName: String
    ) {
        self.id = id
        self.role = role
        self.createdAt = createdAt
        self.professionalName = professionalName
        self.professionalSpecialty = professionalSpecialty
        self.shareCode = shareCode
        self.shareMessage = shareMessage
        self.expiresAt = expiresAt
        self.activatedAt = activatedAt
        self.revokedAt = revokedAt
        self.acknowledgedAt = acknowledgedAt
        self.lastSharedAt = lastSharedAt
        self.shareCount = shareCount
        self.generatedByUserID = generatedByUserID
        self.generatedByName = generatedByName
    }

    enum CodingKeys: String, CodingKey {
        case id
        case role
        case createdAt
        case professionalName
        case professionalSpecialty
        case shareCode
        case shareMessage
        case expiresAt
        case activatedAt
        case revokedAt
        case acknowledgedAt
        case lastSharedAt
        case shareCount
        case generatedByUserID
        case generatedByName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        role = try container.decode(LegalInviteRole.self, forKey: .role)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        professionalName = try container.decode(String.self, forKey: .professionalName)
        professionalSpecialty = try container.decode(String.self, forKey: .professionalSpecialty)
        shareCode = try container.decode(String.self, forKey: .shareCode)
        shareMessage = try container.decode(String.self, forKey: .shareMessage)
        expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
            ?? createdAt.addingTimeInterval(Self.defaultValidityInterval)
        activatedAt = try container.decodeIfPresent(Date.self, forKey: .activatedAt)
        revokedAt = try container.decodeIfPresent(Date.self, forKey: .revokedAt)
        acknowledgedAt = try container.decodeIfPresent(Date.self, forKey: .acknowledgedAt)
        lastSharedAt = try container.decodeIfPresent(Date.self, forKey: .lastSharedAt)
        shareCount = max(try container.decodeIfPresent(Int.self, forKey: .shareCount) ?? 0, 0)
        generatedByUserID = try container.decode(UUID.self, forKey: .generatedByUserID)
        generatedByName = try container.decode(String.self, forKey: .generatedByName)
    }
}

nonisolated enum SaleDocumentKind: String, Codable, Hashable, Sendable {
    case contractPacketPDF
    case councilRatesNoticePDF
    case identityCheckPackPDF
    case signedContractPDF
    case settlementStatementPDF
    case reviewedContractPDF
    case settlementAdjustmentPDF

    var title: String {
        switch self {
        case .contractPacketPDF:
            return "Contract packet PDF"
        case .councilRatesNoticePDF:
            return "Council rates notice PDF"
        case .identityCheckPackPDF:
            return "Identity check pack PDF"
        case .signedContractPDF:
            return "Signed contract PDF"
        case .settlementStatementPDF:
            return "Settlement statement PDF"
        case .reviewedContractPDF:
            return "Reviewed contract PDF"
        case .settlementAdjustmentPDF:
            return "Settlement adjustment PDF"
        }
    }

    var symbolName: String {
        switch self {
        case .contractPacketPDF:
            return "doc.text.fill"
        case .councilRatesNoticePDF:
            return "building.columns.fill"
        case .identityCheckPackPDF:
            return "person.text.rectangle.fill"
        case .signedContractPDF:
            return "checkmark.seal.fill"
        case .settlementStatementPDF:
            return "banknote.fill"
        case .reviewedContractPDF:
            return "doc.badge.gearshape.fill"
        case .settlementAdjustmentPDF:
            return "signature"
        }
    }
}

nonisolated struct SaleDocument: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var kind: SaleDocumentKind
    var createdAt: Date
    var fileName: String
    var summary: String
    var uploadedByUserID: UUID
    var uploadedByName: String
    var packetID: UUID?
    var mimeType: String?
    var attachmentBase64: String?

    var title: String {
        kind.title
    }

    var hasAttachment: Bool {
        attachmentBase64?.isEmpty == false
    }
}

nonisolated enum SaleUpdateKind: String, Codable, Hashable, Sendable {
    case milestone
    case reminder

    var badgeTitle: String {
        switch self {
        case .milestone:
            return "Milestone"
        case .reminder:
            return "Reminder"
        }
    }

    var symbolName: String {
        switch self {
        case .milestone:
            return "flag.2.crossed"
        case .reminder:
            return "bell.badge"
        }
    }
}

nonisolated struct SaleUpdateMessage: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var createdAt: Date
    var title: String
    var body: String
    var kind: SaleUpdateKind
    var checklistItemID: String?

    init(
        id: UUID,
        createdAt: Date,
        title: String,
        body: String,
        kind: SaleUpdateKind = .milestone,
        checklistItemID: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.body = body
        self.kind = kind
        self.checklistItemID = checklistItemID
    }

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt
        case title
        case body
        case kind
        case checklistItemID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decode(String.self, forKey: .body)
        kind = try container.decodeIfPresent(SaleUpdateKind.self, forKey: .kind) ?? .milestone
        checklistItemID = try container.decodeIfPresent(String.self, forKey: .checklistItemID)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(title, forKey: .title)
        try container.encode(body, forKey: .body)
        try container.encode(kind, forKey: .kind)
        try container.encodeIfPresent(checklistItemID, forKey: .checklistItemID)
    }
}

nonisolated enum SaleChecklistStatus: String, Hashable, Sendable {
    case pending
    case inProgress
    case completed

    var title: String {
        switch self {
        case .pending:
            return "Pending"
        case .inProgress:
            return "In progress"
        case .completed:
            return "Done"
        }
    }

    var symbolName: String {
        switch self {
        case .pending:
            return "circle.dashed"
        case .inProgress:
            return "clock.badge.checkmark.fill"
        case .completed:
            return "checkmark.circle.fill"
        }
    }
}

nonisolated struct SaleChecklistItem: Identifiable, Hashable, Sendable {
    let id: String
    var title: String
    var detail: String
    var ownerLabel: String
    var targetDate: Date?
    var nextAction: String?
    var reminder: String?
    var supporting: String?
    var status: SaleChecklistStatus

    var ownerSummary: String {
        "Owner: \(ownerLabel)"
    }

    var targetSummary: String? {
        guard status != .completed,
              let targetDate else { return nil }

        if isOverdue {
            return "Overdue since \(Self.deadlineDateString(targetDate))"
        }

        if isDueSoon {
            return "Due soon: \(Self.deadlineDateString(targetDate))"
        }

        return "Target by \(Self.deadlineDateString(targetDate))"
    }

    var nextActionSummary: String? {
        nextAction.map { "Next: \($0)" }
    }

    var reminderSummary: String? {
        reminder.map { "Reminder: \($0)" }
    }

    var isOverdue: Bool {
        guard status != .completed,
              let targetDate else { return false }
        return targetDate < .now
    }

    var isDueSoon: Bool {
        guard status != .completed,
              let targetDate,
              !isOverdue else { return false }
        return targetDate < .now.addingTimeInterval(60 * 60 * 24)
    }

    private static func deadlineDateString(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }
}

nonisolated struct OfferRecord: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var listingID: UUID
    var buyerID: UUID
    var sellerID: UUID
    var amount: Int
    var conditions: String
    var createdAt: Date
    var status: OfferStatus
    var buyerLegalSelection: LegalSelection?
    var sellerLegalSelection: LegalSelection?
    var contractPacket: ContractPacket?
    var invites: [SaleWorkspaceInvite]
    var documents: [SaleDocument]
    var updates: [SaleUpdateMessage]

    init(
        id: UUID,
        listingID: UUID,
        buyerID: UUID,
        sellerID: UUID,
        amount: Int,
        conditions: String,
        createdAt: Date,
        status: OfferStatus,
        buyerLegalSelection: LegalSelection? = nil,
        sellerLegalSelection: LegalSelection? = nil,
        contractPacket: ContractPacket? = nil,
        invites: [SaleWorkspaceInvite] = [],
        documents: [SaleDocument] = [],
        updates: [SaleUpdateMessage] = []
    ) {
        self.id = id
        self.listingID = listingID
        self.buyerID = buyerID
        self.sellerID = sellerID
        self.amount = amount
        self.conditions = conditions
        self.createdAt = createdAt
        self.status = status
        self.buyerLegalSelection = buyerLegalSelection
        self.sellerLegalSelection = sellerLegalSelection
        self.contractPacket = contractPacket
        self.invites = invites
        self.documents = documents
        self.updates = updates
    }

    enum CodingKeys: String, CodingKey {
        case id
        case listingID
        case buyerID
        case sellerID
        case amount
        case conditions
        case createdAt
        case status
        case buyerLegalSelection
        case sellerLegalSelection
        case contractPacket
        case invites
        case documents
        case updates
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        listingID = try container.decode(UUID.self, forKey: .listingID)
        buyerID = try container.decode(UUID.self, forKey: .buyerID)
        sellerID = try container.decode(UUID.self, forKey: .sellerID)
        amount = try container.decode(Int.self, forKey: .amount)
        conditions = try container.decode(String.self, forKey: .conditions)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        status = try container.decode(OfferStatus.self, forKey: .status)
        buyerLegalSelection = try container.decodeIfPresent(LegalSelection.self, forKey: .buyerLegalSelection)
        sellerLegalSelection = try container.decodeIfPresent(LegalSelection.self, forKey: .sellerLegalSelection)
        contractPacket = try container.decodeIfPresent(ContractPacket.self, forKey: .contractPacket)
        invites = try container.decodeIfPresent([SaleWorkspaceInvite].self, forKey: .invites) ?? []
        documents = try container.decodeIfPresent([SaleDocument].self, forKey: .documents) ?? []
        updates = try container.decodeIfPresent([SaleUpdateMessage].self, forKey: .updates) ?? []
    }

    var isLegallyCoordinated: Bool {
        buyerLegalSelection != nil && sellerLegalSelection != nil
    }

    var listingStatus: ListingStatus {
        contractPacket?.isFullySigned == true ? .sold : status.listingStatus
    }

    var settlementChecklist: [SaleChecklistItem] {
        let buyerInvite = invite(for: .buyerRepresentative)
        let sellerInvite = invite(for: .sellerRepresentative)
        let requiredInvites = [buyerInvite, sellerInvite].compactMap { $0 }
        let expectedInviteCount = isLegallyCoordinated ? 2 : requiredInvites.count
        let sharedInviteCount = requiredInvites.filter { $0.hasBeenShared }.count
        let activatedInviteCount = requiredInvites.filter { $0.isActivated }.count
        let acknowledgedInviteCount = requiredInvites.filter { $0.isAcknowledged }.count
        let followUpInviteCount = requiredInvites.filter { $0.needsFollowUp }.count
        let unavailableInviteCount = requiredInvites.filter { $0.isUnavailable }.count
        let latestSelectionDate = [buyerLegalSelection?.selectedAt, sellerLegalSelection?.selectedAt]
            .compactMap { $0 }
            .max()
        let latestInviteSentDate = requiredInvites
            .compactMap(\.lastSharedAt)
            .max()
        let latestInviteAcknowledgedDate = requiredInvites
            .compactMap(\.acknowledgedAt)
            .max()
        let latestSignatureDate = [contractPacket?.buyerSignedAt, contractPacket?.sellerSignedAt]
            .compactMap { $0 }
            .max()

        let documentKinds = Set(documents.map(\.kind))
        let hasReviewedContract = documentKinds.contains(.reviewedContractPDF)
        let hasSettlementAdjustment = documentKinds.contains(.settlementAdjustmentPDF)
        let hasSettlementStatement = documentKinds.contains(.settlementStatementPDF)
        let hasSignedContract = documentKinds.contains(.signedContractPDF)
        let legalReviewCount = [hasReviewedContract, hasSettlementAdjustment].filter { $0 }.count

        let signatureCount = [contractPacket?.buyerSignedAt, contractPacket?.sellerSignedAt]
            .compactMap { $0 }
            .count

        let inviteSupporting = SaleChecklistItem.inviteSupporting(
            unavailableInviteCount: unavailableInviteCount,
            followUpInviteCount: followUpInviteCount
        )

        return [
            SaleChecklistItem(
                id: "buyer-representative",
                title: "Buyer legal rep chosen",
                detail: buyerLegalSelection.map {
                    "\($0.professional.name) selected \(Self.checklistDateString($0.selectedAt))."
                } ?? "Buyer still needs to choose a conveyancer, solicitor, or property lawyer.",
                ownerLabel: "Buyer",
                targetDate: createdAt.addingTimeInterval(60 * 60 * 24 * 2),
                nextAction: buyerLegalSelection == nil ? "Choose a buyer-side conveyancer or solicitor." : nil,
                reminder: buyerLegalSelection == nil && createdAt.addingTimeInterval(60 * 60 * 24 * 2) < .now
                    ? "The contract packet cannot start until the buyer chooses a representative."
                    : nil,
                supporting: buyerLegalSelection?.professional.primarySpecialty,
                status: buyerLegalSelection == nil ? .pending : .completed
            ),
            SaleChecklistItem(
                id: "seller-representative",
                title: "Seller legal rep chosen",
                detail: sellerLegalSelection.map {
                    "\($0.professional.name) selected \(Self.checklistDateString($0.selectedAt))."
                } ?? "Seller still needs to choose a conveyancer, solicitor, or property lawyer.",
                ownerLabel: "Seller",
                targetDate: createdAt.addingTimeInterval(60 * 60 * 24 * 2),
                nextAction: sellerLegalSelection == nil ? "Choose a seller-side conveyancer or solicitor." : nil,
                reminder: sellerLegalSelection == nil && createdAt.addingTimeInterval(60 * 60 * 24 * 2) < .now
                    ? "The contract packet cannot start until the seller chooses a representative."
                    : nil,
                supporting: sellerLegalSelection?.professional.primarySpecialty,
                status: sellerLegalSelection == nil ? .pending : .completed
            ),
            SaleChecklistItem(
                id: "contract-packet",
                title: "Contract packet issued",
                detail: contractPacket.map {
                    "Contract packet issued \(Self.checklistDateString($0.generatedAt))."
                } ?? (
                    isLegallyCoordinated
                    ? "Legal reps are set. The contract packet is the next document to issue."
                    : "Both sides need legal reps before the contract packet can be issued."
                ),
                ownerLabel: "Legal reps",
                targetDate: (latestSelectionDate ?? createdAt).addingTimeInterval(60 * 60 * 24),
                nextAction: contractPacket == nil && isLegallyCoordinated
                    ? "Issue the contract packet so both sides can move into signing."
                    : nil,
                reminder: contractPacket == nil && isLegallyCoordinated && (latestSelectionDate ?? createdAt).addingTimeInterval(60 * 60 * 24) < .now
                    ? "The legal handoff is ready. Send the contract packet to avoid stalling the sale."
                    : nil,
                supporting: contractPacket?.summary,
                status: contractPacket == nil
                    ? (isLegallyCoordinated ? .inProgress : .pending)
                    : .completed
            ),
            SaleChecklistItem(
                id: "workspace-invites",
                title: "Legal workspace invites sent",
                detail: expectedInviteCount == 0
                    ? "Invites unlock once both sides have chosen a legal rep."
                    : sharedInviteCount == expectedInviteCount
                    ? "\(sharedInviteCount) of \(expectedInviteCount) legal workspace invites have been sent."
                    : "\(sharedInviteCount) of \(expectedInviteCount) legal workspace invites have been sent.",
                ownerLabel: "Buyer and seller",
                targetDate: (contractPacket?.generatedAt ?? latestSelectionDate ?? createdAt).addingTimeInterval(60 * 60 * 4),
                nextAction: expectedInviteCount > 0 && sharedInviteCount < expectedInviteCount
                    ? "Share the latest invite link and code with each legal rep."
                    : (unavailableInviteCount > 0
                        ? "Regenerate the expired or revoked invite before resending it."
                        : (followUpInviteCount > 0 ? "Resend the invite or follow up directly." : nil)),
                reminder: inviteSupporting,
                supporting: inviteSupporting,
                status: expectedInviteCount == 0
                    ? .pending
                    : sharedInviteCount == expectedInviteCount
                    ? .completed
                    : (sharedInviteCount > 0 || !requiredInvites.isEmpty ? .inProgress : .pending)
            ),
            SaleChecklistItem(
                id: "workspace-active",
                title: "Legal workspace active",
                detail: expectedInviteCount == 0
                    ? "Once invites are sent, the legal reps can open and acknowledge the workspace."
                    : acknowledgedInviteCount == expectedInviteCount
                    ? "All legal reps have opened and acknowledged the workspace."
                    : "\(activatedInviteCount) of \(expectedInviteCount) opened • \(acknowledgedInviteCount) of \(expectedInviteCount) acknowledged.",
                ownerLabel: "Legal reps",
                targetDate: (latestInviteSentDate ?? contractPacket?.generatedAt ?? latestSelectionDate ?? createdAt)
                    .addingTimeInterval(60 * 60 * 24 * 2),
                nextAction: expectedInviteCount > 0 && acknowledgedInviteCount < expectedInviteCount
                    ? "Open the workspace invite and tap Acknowledge Receipt."
                    : nil,
                reminder: expectedInviteCount > 0 && acknowledgedInviteCount < expectedInviteCount && followUpInviteCount > 0
                    ? "At least one legal rep still has not opened the workspace after the invite was sent."
                    : (expectedInviteCount > 0 && activatedInviteCount > 0 && acknowledgedInviteCount < expectedInviteCount
                        ? "A legal rep opened the workspace but has not acknowledged receipt yet."
                        : nil),
                supporting: inviteSupporting,
                status: expectedInviteCount == 0
                    ? .pending
                    : acknowledgedInviteCount == expectedInviteCount
                    ? .completed
                    : (activatedInviteCount > 0 || acknowledgedInviteCount > 0 || sharedInviteCount > 0 ? .inProgress : .pending)
            ),
            SaleChecklistItem(
                id: "legal-review-pack",
                title: "Legal review pack uploaded",
                detail: legalReviewCount == 2
                    ? "Reviewed contract and settlement adjustment PDFs are attached."
                    : legalReviewCount == 1
                    ? "1 of 2 legal review PDFs is attached."
                    : "Legal reps can attach the reviewed contract and settlement adjustments here.",
                ownerLabel: "Legal reps",
                targetDate: (latestInviteAcknowledgedDate ?? contractPacket?.generatedAt ?? createdAt)
                    .addingTimeInterval(60 * 60 * 24 * 3),
                nextAction: Self.reviewPackNextAction(
                    hasReviewedContract: hasReviewedContract,
                    hasSettlementAdjustment: hasSettlementAdjustment
                ),
                reminder: legalReviewCount < 2 && (latestInviteAcknowledgedDate ?? contractPacket?.generatedAt ?? createdAt)
                    .addingTimeInterval(60 * 60 * 24 * 3) < .now
                    ? "The legal review pack is still incomplete, so contract changes may be waiting on upload."
                    : nil,
                supporting: legalReviewCount == 2
                    ? nil
                    : Self.missingReviewPackSummary(
                        hasReviewedContract: hasReviewedContract,
                        hasSettlementAdjustment: hasSettlementAdjustment
                    ),
                status: legalReviewCount == 2
                    ? .completed
                    : (legalReviewCount > 0 || acknowledgedInviteCount > 0 ? .inProgress : .pending)
            ),
            SaleChecklistItem(
                id: "contract-signatures",
                title: "Contract signed by both parties",
                detail: contractPacket?.isFullySigned == true
                    ? "Buyer and seller signatures are both recorded."
                    : contractPacket != nil
                    ? "\(signatureCount) of 2 signatures recorded."
                    : "Contract signatures start after the contract packet is issued.",
                ownerLabel: Self.signatureOwnerLabel(packet: contractPacket),
                targetDate: (contractPacket?.generatedAt ?? createdAt).addingTimeInterval(60 * 60 * 24 * 5),
                nextAction: Self.signatureNextAction(packet: contractPacket),
                reminder: contractPacket?.isFullySigned == false && (contractPacket?.generatedAt ?? createdAt).addingTimeInterval(60 * 60 * 24 * 5) < .now
                    ? "The contract is still waiting on signatures. Follow up with the remaining party."
                    : nil,
                supporting: contractPacket?.isFullySigned == true
                    ? nil
                    : Self.pendingSignatureSummary(packet: contractPacket),
                status: contractPacket?.isFullySigned == true
                    ? .completed
                    : contractPacket != nil
                    ? .inProgress
                    : .pending
            ),
            SaleChecklistItem(
                id: "settlement-statement",
                title: "Settlement statement ready",
                detail: hasSettlementStatement
                    ? "Settlement statement is attached in shared sale documents."
                    : contractPacket?.isFullySigned == true || hasSignedContract
                    ? "The sale is signed. Settlement paperwork is being finalised."
                    : "Settlement statement appears after both sides sign the contract.",
                ownerLabel: "Legal reps",
                targetDate: (latestSignatureDate ?? contractPacket?.generatedAt ?? createdAt).addingTimeInterval(60 * 60 * 24 * 2),
                nextAction: hasSettlementStatement
                    ? nil
                    : (contractPacket?.isFullySigned == true || hasSignedContract
                        ? "Prepare and upload the settlement statement PDF."
                        : "Complete both contract signatures before preparing settlement paperwork."),
                reminder: !hasSettlementStatement && (contractPacket?.isFullySigned == true || hasSignedContract) &&
                    (latestSignatureDate ?? contractPacket?.generatedAt ?? createdAt).addingTimeInterval(60 * 60 * 24 * 2) < .now
                    ? "Settlement paperwork is due. Upload the settlement statement to finish the file."
                    : nil,
                supporting: hasSettlementStatement
                    ? nil
                    : (listingStatus == .sold ? "The listing is already marked sold." : nil),
                status: hasSettlementStatement
                    ? .completed
                    : (contractPacket?.isFullySigned == true || hasSignedContract ? .inProgress : .pending)
            )
        ]
    }

    private func invite(for role: LegalInviteRole) -> SaleWorkspaceInvite? {
        invites
            .filter { $0.role == role }
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }

    var taskSnapshotAudienceMembers: [SaleTaskSnapshotAudienceMember] {
        var audience = [
            SaleTaskSnapshotAudienceMember(
                viewerID: "user:\(buyerID.uuidString)",
                label: "Buyer"
            ),
            SaleTaskSnapshotAudienceMember(
                viewerID: "user:\(sellerID.uuidString)",
                label: "Seller"
            )
        ]

        for role in [LegalInviteRole.buyerRepresentative, .sellerRepresentative] {
            let activeInvite = invites
                .filter { $0.role == role && $0.revokedAt == nil }
                .sorted { $0.createdAt > $1.createdAt }
                .first
                ?? invite(for: role)

            if let activeInvite {
                audience.append(
                    SaleTaskSnapshotAudienceMember(
                        viewerID: "invite:\(activeInvite.id.uuidString)",
                        label: role.audienceLabel
                    )
                )
            }
        }

        return audience
    }

    func taskSnapshotID(for checklistItemID: String) -> String {
        "\(id.uuidString)|\(checklistItemID)"
    }

    private static func checklistDateString(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    private static func missingReviewPackSummary(
        hasReviewedContract: Bool,
        hasSettlementAdjustment: Bool
    ) -> String? {
        var missingItems: [String] = []

        if !hasReviewedContract {
            missingItems.append("reviewed contract")
        }

        if !hasSettlementAdjustment {
            missingItems.append("settlement adjustment")
        }

        guard !missingItems.isEmpty else { return nil }
        return "Still needed: \(missingItems.joined(separator: " and "))."
    }

    private static func pendingSignatureSummary(packet: ContractPacket?) -> String? {
        guard let packet else { return nil }

        var pendingSides: [String] = []
        if packet.buyerSignedAt == nil {
            pendingSides.append("buyer")
        }
        if packet.sellerSignedAt == nil {
            pendingSides.append("seller")
        }

        guard !pendingSides.isEmpty else { return nil }
        return "Waiting on \(pendingSides.joined(separator: " and ")) sign-off."
    }

    private static func reviewPackNextAction(
        hasReviewedContract: Bool,
        hasSettlementAdjustment: Bool
    ) -> String? {
        switch (hasReviewedContract, hasSettlementAdjustment) {
        case (false, false):
            return "Upload the reviewed contract and settlement adjustment PDFs."
        case (false, true):
            return "Upload the reviewed contract PDF."
        case (true, false):
            return "Upload the settlement adjustment PDF."
        case (true, true):
            return nil
        }
    }

    private static func signatureOwnerLabel(packet: ContractPacket?) -> String {
        guard let packet else { return "Buyer and seller" }

        switch (packet.buyerSignedAt == nil, packet.sellerSignedAt == nil) {
        case (true, true):
            return "Buyer and seller"
        case (true, false):
            return "Buyer"
        case (false, true):
            return "Seller"
        case (false, false):
            return "Buyer and seller"
        }
    }

    private static func signatureNextAction(packet: ContractPacket?) -> String? {
        guard let packet else { return nil }

        switch (packet.buyerSignedAt == nil, packet.sellerSignedAt == nil) {
        case (true, true):
            return "Collect buyer and seller signatures on the contract packet."
        case (true, false):
            return "Buyer should sign the contract packet."
        case (false, true):
            return "Seller should sign the contract packet."
        case (false, false):
            return nil
        }
    }
}

nonisolated enum SaleTaskLiveSnapshotTone: String, Hashable, Sendable {
    case info
    case warning
    case critical
    case success
}

nonisolated struct SaleTaskLiveSnapshot: Hashable, Sendable {
    var summary: String
    var tone: SaleTaskLiveSnapshotTone
}

private nonisolated let saleTaskDayInterval: TimeInterval = 60 * 60 * 24

extension OfferRecord {
    func liveTaskSnapshot(for checklistItemID: String, now: Date = .now) -> SaleTaskLiveSnapshot? {
        guard let checklistItem = settlementChecklist.first(where: { $0.id == checklistItemID }) else {
            return nil
        }

        let buyerInvite = invite(for: .buyerRepresentative)
        let sellerInvite = invite(for: .sellerRepresentative)
        let requiredInvites = [buyerInvite, sellerInvite].compactMap { $0 }
        let expectedInviteCount = isLegallyCoordinated ? 2 : requiredInvites.count
        let sharedInviteCount = requiredInvites.filter { $0.hasBeenShared }.count
        let activatedInviteCount = requiredInvites.filter { $0.isActivated }.count
        let acknowledgedInviteCount = requiredInvites.filter { $0.isAcknowledged }.count
        let followUpInvites = requiredInvites.filter { $0.needsFollowUp }
        let unavailableInviteCount = requiredInvites.filter { $0.isUnavailable }.count

        let documentKinds = Set(documents.map(\.kind))
        let hasReviewedContract = documentKinds.contains(.reviewedContractPDF)
        let hasSettlementAdjustment = documentKinds.contains(.settlementAdjustmentPDF)
        let hasSettlementStatement = documentKinds.contains(.settlementStatementPDF)
        let hasSignedContract = documentKinds.contains(.signedContractPDF)
        let legalReviewCount = [hasReviewedContract, hasSettlementAdjustment].filter { $0 }.count

        let missingSignatureCount = [contractPacket?.buyerSignedAt, contractPacket?.sellerSignedAt]
            .filter { $0 == nil }
            .count

        switch checklistItemID {
        case "buyer-representative", "seller-representative":
            if checklistItem.status == .completed {
                return SaleTaskLiveSnapshot(summary: "Representative selected", tone: .success)
            }

            return SaleTaskLiveSnapshot(
                summary: withDeadlineState("Representative still missing", checklistItem: checklistItem, now: now),
                tone: checklistItem.isOverdue ? .critical : .warning
            )
        case "contract-packet":
            if contractPacket != nil {
                return SaleTaskLiveSnapshot(summary: "Contract packet ready to review", tone: .success)
            }

            if isLegallyCoordinated {
                return SaleTaskLiveSnapshot(
                    summary: withDeadlineState("Contract packet still needs issuing", checklistItem: checklistItem, now: now),
                    tone: checklistItem.isOverdue ? .critical : .warning
                )
            }

            let repsLeft = [buyerLegalSelection, sellerLegalSelection].filter { $0 == nil }.count
            return SaleTaskLiveSnapshot(
                summary: "\(repsLeft) legal rep\(repsLeft == 1 ? "" : "s") left before issue",
                tone: .info
            )
        case "workspace-invites":
            if expectedInviteCount == 0 {
                return SaleTaskLiveSnapshot(summary: "Invites unlock after both reps are chosen", tone: .info)
            }

            if unavailableInviteCount > 0 {
                return SaleTaskLiveSnapshot(
                    summary: "\(unavailableInviteCount) invite\(unavailableInviteCount == 1 ? "" : "s") need regeneration",
                    tone: .critical
                )
            }

            if !followUpInvites.isEmpty {
                let overdueDays = followUpInvites
                    .compactMap(\.lastSharedAt)
                    .map { daysBetween($0.addingTimeInterval(SaleWorkspaceInvite.followUpInterval), now: now) }
                    .max() ?? 1
                let prefix = followUpInvites.count == 1 ? "1 invite needs follow-up" : "\(followUpInvites.count) invites need follow-up"
                return SaleTaskLiveSnapshot(
                    summary: "\(prefix) • \(overdueDays) day\(overdueDays == 1 ? "" : "s") overdue",
                    tone: .warning
                )
            }

            if sharedInviteCount < expectedInviteCount {
                let remaining = expectedInviteCount - sharedInviteCount
                return SaleTaskLiveSnapshot(
                    summary: "\(remaining) invite\(remaining == 1 ? "" : "s") left to send",
                    tone: .warning
                )
            }

            if activatedInviteCount < expectedInviteCount {
                let remaining = expectedInviteCount - activatedInviteCount
                return SaleTaskLiveSnapshot(
                    summary: "\(remaining) invite\(remaining == 1 ? "" : "s") left to open",
                    tone: .info
                )
            }

            if acknowledgedInviteCount < expectedInviteCount {
                let remaining = expectedInviteCount - acknowledgedInviteCount
                return SaleTaskLiveSnapshot(
                    summary: "\(remaining) acknowledgement\(remaining == 1 ? "" : "s") left",
                    tone: .info
                )
            }

            return SaleTaskLiveSnapshot(summary: "Both legal reps acknowledged", tone: .success)
        case "workspace-active":
            if expectedInviteCount == 0 {
                return SaleTaskLiveSnapshot(summary: "Waiting for invite delivery", tone: .info)
            }

            if acknowledgedInviteCount == expectedInviteCount {
                return SaleTaskLiveSnapshot(summary: "All legal reps active in workspace", tone: .success)
            }

            if checklistItem.isOverdue {
                return SaleTaskLiveSnapshot(
                    summary: withDeadlineState("\(expectedInviteCount - acknowledgedInviteCount) acknowledgement\(expectedInviteCount - acknowledgedInviteCount == 1 ? "" : "s") left", checklistItem: checklistItem, now: now),
                    tone: .warning
                )
            }

            if activatedInviteCount == 0 {
                return SaleTaskLiveSnapshot(
                    summary: "\(expectedInviteCount) legal rep\(expectedInviteCount == 1 ? "" : "s") still need to open",
                    tone: .info
                )
            }

            let remaining = expectedInviteCount - acknowledgedInviteCount
            return SaleTaskLiveSnapshot(
                summary: "\(remaining) acknowledgement\(remaining == 1 ? "" : "s") left",
                tone: .info
            )
        case "legal-review-pack":
            if legalReviewCount == 2 {
                return SaleTaskLiveSnapshot(summary: "Legal review pack complete", tone: .success)
            }

            if acknowledgedInviteCount == 0 {
                return SaleTaskLiveSnapshot(summary: "Waiting for legal review to begin", tone: .info)
            }

            let missingDocuments = 2 - legalReviewCount
            return SaleTaskLiveSnapshot(
                summary: withDeadlineState("\(missingDocuments) review document\(missingDocuments == 1 ? "" : "s") left", checklistItem: checklistItem, now: now),
                tone: checklistItem.isOverdue ? .warning : .info
            )
        case "contract-signatures":
            guard contractPacket != nil else {
                return SaleTaskLiveSnapshot(summary: "Waiting for contract packet", tone: .info)
            }

            if missingSignatureCount == 0 {
                return SaleTaskLiveSnapshot(summary: "Fully signed and ready to settle", tone: .success)
            }

            return SaleTaskLiveSnapshot(
                summary: withDeadlineState("\(missingSignatureCount) signature\(missingSignatureCount == 1 ? "" : "s") left", checklistItem: checklistItem, now: now),
                tone: checklistItem.isOverdue ? .warning : .info
            )
        case "settlement-statement":
            if hasSettlementStatement {
                return SaleTaskLiveSnapshot(summary: "Settlement statement ready", tone: .success)
            }

            if contractPacket?.isFullySigned == true || hasSignedContract {
                return SaleTaskLiveSnapshot(
                    summary: withDeadlineState("Settlement statement still pending", checklistItem: checklistItem, now: now),
                    tone: checklistItem.isOverdue ? .warning : .info
                )
            }

            return SaleTaskLiveSnapshot(summary: "Settlement waits for final signing", tone: .info)
        default:
            return nil
        }
    }

    private func withDeadlineState(_ base: String, checklistItem: SaleChecklistItem, now: Date) -> String {
        if checklistItem.isOverdue, let targetDate = checklistItem.targetDate {
            let overdueDays = daysBetween(targetDate, now: now)
            return "\(base) • \(overdueDays) day\(overdueDays == 1 ? "" : "s") overdue"
        }

        if checklistItem.isDueSoon {
            return "\(base) • due soon"
        }

        return base
    }

    private func daysBetween(_ date: Date, now: Date) -> Int {
        max(1, Int(ceil(now.timeIntervalSince(date) / saleTaskDayInterval)))
    }
}

private extension SaleChecklistItem {
    nonisolated static func inviteSupporting(
        unavailableInviteCount: Int,
        followUpInviteCount: Int
    ) -> String? {
        if unavailableInviteCount > 0 {
            let noun = unavailableInviteCount == 1 ? "invite needs" : "invites need"
            return "\(unavailableInviteCount) \(noun) a fresh code."
        }

        if followUpInviteCount > 0 {
            let noun = followUpInviteCount == 1 ? "invite still needs" : "invites still need"
            return "\(followUpInviteCount) \(noun) follow-up."
        }

        return nil
    }
}

nonisolated struct LegalWorkspaceSession: Identifiable, Hashable, Sendable {
    let id: UUID
    var listingID: UUID
    var offerID: UUID
    var inviteID: UUID
    var inviteCode: String
    var role: LegalInviteRole
    var professionalName: String

    init(
        listingID: UUID,
        offerID: UUID,
        invite: SaleWorkspaceInvite
    ) {
        id = invite.id
        self.listingID = listingID
        self.offerID = offerID
        inviteID = invite.id
        inviteCode = invite.shareCode
        role = invite.role
        professionalName = invite.professionalName
    }
}

nonisolated enum LegalWorkspaceAccessError: LocalizedError, Sendable {
    case expiredInvite
    case revokedInvite

    var errorDescription: String? {
        switch self {
        case .expiredInvite:
            return "This legal workspace invite has expired. Ask the buyer or seller to send a fresh invite."
        case .revokedInvite:
            return "This legal workspace invite has been revoked. Ask the buyer or seller to send a fresh invite."
        }
    }
}

nonisolated enum SaleInviteManagementAction: Sendable {
    case regenerate
    case revoke
}

nonisolated struct SaleInviteManagementOutcome {
    var offer: OfferRecord
    var invite: SaleWorkspaceInvite
    var threadMessage: String
    var noticeMessage: String
}

nonisolated struct SaleInviteDeliveryOutcome {
    var offer: OfferRecord
    var invite: SaleWorkspaceInvite
    var threadMessage: String
    var noticeMessage: String
}

nonisolated struct ListingDraft: Sendable {
    var title = ""
    var headline = ""
    var summary = ""
    var street = ""
    var suburb = "Brisbane"
    var state = "QLD"
    var postcode = ""
    var priceText = ""
    var bedrooms = 3
    var bathrooms = 2
    var parkingSpaces = 1
    var landSizeText = "420 sqm"
    var featuresText = "Private inspections, Family home, Outdoor area"
    var propertyType: PropertyType = .house
    var latitude = -27.4705
    var longitude = 153.0260

    var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !street.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Int(priceText.filter(\.isNumber)) != nil
    }
}

nonisolated enum MarketplaceSeed {
    static let buyerOliviaID = UUID(uuidString: "C8F18F9D-772E-4D62-8A88-0B9E23265001") ?? UUID()
    static let buyerNoahID = UUID(uuidString: "C8F18F9D-772E-4D62-8A88-0B9E23265002") ?? UUID()
    static let sellerAvaID = UUID(uuidString: "C8F18F9D-772E-4D62-8A88-0B9E23265003") ?? UUID()
    static let sellerMasonID = UUID(uuidString: "C8F18F9D-772E-4D62-8A88-0B9E23265004") ?? UUID()

    static let users: [UserProfile] = [
        UserProfile(
            id: buyerOliviaID,
            name: "Olivia Bennett",
            role: .buyer,
            suburb: "Paddington, QLD",
            headline: "Searching for a family home with flexible inspection times.",
            verificationNote: "Identity and mobile verified",
            buyerStage: .readyToOffer
        ),
        UserProfile(
            id: buyerNoahID,
            name: "Noah Chen",
            role: .buyer,
            suburb: "New Farm, QLD",
            headline: "Focused on inner-city townhomes close to schools and cafes.",
            verificationNote: "Finance pre-approval uploaded",
            buyerStage: .preApproved
        ),
        UserProfile(
            id: sellerAvaID,
            name: "Ava Thompson",
            role: .seller,
            suburb: "Graceville, QLD",
            headline: "Private owner listing with direct buyer conversations.",
            verificationNote: "Ownership documents reviewed",
            buyerStage: nil
        ),
        UserProfile(
            id: sellerMasonID,
            name: "Mason Wright",
            role: .seller,
            suburb: "Wilston, QLD",
            headline: "Selling privately and managing inspections directly.",
            verificationNote: "Owner dashboard enabled",
            buyerStage: nil
        )
    ]

    static func listings(now: Date = .now) -> [PropertyListing] {
        let calendar = Calendar.current

        func date(daysAgo: Int, hour: Int, minute: Int) -> Date {
            let start = calendar.startOfDay(for: now)
            let base = calendar.date(byAdding: .day, value: -daysAgo, to: start) ?? now
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
        }

        return [
            PropertyListing(
                id: UUID(uuidString: "DAA3A4D1-0FE6-4FD7-8A81-68D7E1971001") ?? UUID(),
                title: "Renovated Queenslander with pool and studio",
                headline: "Privately listed family home with strong school catchment appeal.",
                summary: "A bright, elevated home with open-plan living, a detached studio, landscaped yard, and flexible private inspection windows for serious buyers.",
                propertyType: .house,
                status: .active,
                address: PropertyAddress(
                    street: "14 Roseberry Street",
                    suburb: "Graceville",
                    state: "QLD",
                    postcode: "4075"
                ),
                askingPrice: 1585000,
                bedrooms: 4,
                bathrooms: 2,
                parkingSpaces: 2,
                landSizeText: "607 sqm",
                features: [
                    "Private pool",
                    "Detached studio",
                    "School catchment appeal",
                    "Walk to rail",
                    "Solar power"
                ],
                sellerID: sellerAvaID,
                inspectionSlots: [
                    InspectionSlot(
                        id: UUID(uuidString: "DAA3A4D1-0FE6-4FD7-8A81-68D7E1972001") ?? UUID(),
                        startsAt: date(daysAgo: -1, hour: 9, minute: 30),
                        endsAt: date(daysAgo: -1, hour: 10, minute: 15),
                        note: "Saturday private inspection"
                    ),
                    InspectionSlot(
                        id: UUID(uuidString: "DAA3A4D1-0FE6-4FD7-8A81-68D7E1972002") ?? UUID(),
                        startsAt: date(daysAgo: -2, hour: 17, minute: 30),
                        endsAt: date(daysAgo: -2, hour: 18, minute: 0),
                        note: "After-work twilight viewing"
                    )
                ],
                marketPulse: MarketPulse(
                    valueEstimateLow: 1530000,
                    valueEstimateHigh: 1610000,
                    suburbMedian: 1490000,
                    buyerDemandScore: 89,
                    averageDaysOnMarket: 24,
                    schoolInsight: SchoolInsight(
                        catchmentName: "Graceville State School",
                        walkMinutes: 11,
                        score: 91
                    )
                ),
                comparableSales: [
                    ComparableSale(
                        id: UUID(uuidString: "DAA3A4D1-0FE6-4FD7-8A81-68D7E1973001") ?? UUID(),
                        address: "22 Verney Road, Graceville",
                        soldPrice: 1510000,
                        soldAt: date(daysAgo: 19, hour: 0, minute: 0),
                        bedrooms: 4
                    ),
                    ComparableSale(
                        id: UUID(uuidString: "DAA3A4D1-0FE6-4FD7-8A81-68D7E1973002") ?? UUID(),
                        address: "7 Long Street East, Graceville",
                        soldPrice: 1625000,
                        soldAt: date(daysAgo: 34, hour: 0, minute: 0),
                        bedrooms: 4
                    )
                ],
                palette: .ocean,
                latitude: -27.5232,
                longitude: 152.9817,
                isFeatured: true,
                publishedAt: date(daysAgo: 2, hour: 8, minute: 30),
                updatedAt: date(daysAgo: 0, hour: 7, minute: 10)
            ),
            PropertyListing(
                id: UUID(uuidString: "DAA3A4D1-0FE6-4FD7-8A81-68D7E1971002") ?? UUID(),
                title: "Architect townhouse near Newmarket village",
                headline: "Turn-key private sale with curated finishes and quick offer path.",
                summary: "A low-maintenance inner-north townhouse with high ceilings, protected outdoor entertaining, and owner-managed inspections designed for efficient private sale.",
                propertyType: .townhouse,
                status: .active,
                address: PropertyAddress(
                    street: "5/32 Ashgrove Avenue",
                    suburb: "Wilston",
                    state: "QLD",
                    postcode: "4051"
                ),
                askingPrice: 1125000,
                bedrooms: 3,
                bathrooms: 2,
                parkingSpaces: 2,
                landSizeText: "192 sqm",
                features: [
                    "Stone kitchen",
                    "Courtyard",
                    "Private garage",
                    "Walk to cafes",
                    "Low body corporate"
                ],
                sellerID: sellerMasonID,
                inspectionSlots: [
                    InspectionSlot(
                        id: UUID(uuidString: "DAA3A4D1-0FE6-4FD7-8A81-68D7E1972003") ?? UUID(),
                        startsAt: date(daysAgo: -1, hour: 11, minute: 0),
                        endsAt: date(daysAgo: -1, hour: 11, minute: 30),
                        note: "Open private inspection"
                    )
                ],
                marketPulse: MarketPulse(
                    valueEstimateLow: 1090000,
                    valueEstimateHigh: 1155000,
                    suburbMedian: 1070000,
                    buyerDemandScore: 84,
                    averageDaysOnMarket: 19,
                    schoolInsight: SchoolInsight(
                        catchmentName: "Wilston State School",
                        walkMinutes: 8,
                        score: 88
                    )
                ),
                comparableSales: [
                    ComparableSale(
                        id: UUID(uuidString: "DAA3A4D1-0FE6-4FD7-8A81-68D7E1973003") ?? UUID(),
                        address: "3/14 Erin Street, Wilston",
                        soldPrice: 1080000,
                        soldAt: date(daysAgo: 27, hour: 0, minute: 0),
                        bedrooms: 3
                    ),
                    ComparableSale(
                        id: UUID(uuidString: "DAA3A4D1-0FE6-4FD7-8A81-68D7E1973004") ?? UUID(),
                        address: "8/41 Swan Terrace, Wilston",
                        soldPrice: 1160000,
                        soldAt: date(daysAgo: 43, hour: 0, minute: 0),
                        bedrooms: 3
                    )
                ],
                palette: .sand,
                latitude: -27.4329,
                longitude: 153.0151,
                isFeatured: true,
                publishedAt: date(daysAgo: 5, hour: 9, minute: 15),
                updatedAt: date(daysAgo: 0, hour: 6, minute: 45)
            ),
            PropertyListing(
                id: UUID(uuidString: "DAA3A4D1-0FE6-4FD7-8A81-68D7E1971003") ?? UUID(),
                title: "Leafy acreage retreat with secondary dwelling",
                headline: "Private acreage listing with strong multi-generational flexibility.",
                summary: "Set on usable land with a secondary dwelling and wide frontage, this private acreage sale is positioned for buyers seeking lifestyle space without losing access to the city.",
                propertyType: .acreage,
                status: .active,
                address: PropertyAddress(
                    street: "88 Cedar Creek Road",
                    suburb: "Samford Valley",
                    state: "QLD",
                    postcode: "4520"
                ),
                askingPrice: 1895000,
                bedrooms: 5,
                bathrooms: 3,
                parkingSpaces: 4,
                landSizeText: "1.4 ha",
                features: [
                    "Secondary dwelling",
                    "Rainwater tanks",
                    "Horse-ready paddock",
                    "Mountain outlook",
                    "Large shed"
                ],
                sellerID: sellerAvaID,
                inspectionSlots: [
                    InspectionSlot(
                        id: UUID(uuidString: "DAA3A4D1-0FE6-4FD7-8A81-68D7E1972004") ?? UUID(),
                        startsAt: date(daysAgo: -3, hour: 10, minute: 0),
                        endsAt: date(daysAgo: -3, hour: 11, minute: 0),
                        note: "Booked acreage tour"
                    )
                ],
                marketPulse: MarketPulse(
                    valueEstimateLow: 1810000,
                    valueEstimateHigh: 1920000,
                    suburbMedian: 1760000,
                    buyerDemandScore: 74,
                    averageDaysOnMarket: 33,
                    schoolInsight: SchoolInsight(
                        catchmentName: "Samford State School",
                        walkMinutes: 14,
                        score: 80
                    )
                ),
                comparableSales: [
                    ComparableSale(
                        id: UUID(uuidString: "DAA3A4D1-0FE6-4FD7-8A81-68D7E1973005") ?? UUID(),
                        address: "21 Wights Mountain Road, Samford Valley",
                        soldPrice: 1840000,
                        soldAt: date(daysAgo: 31, hour: 0, minute: 0),
                        bedrooms: 5
                    )
                ],
                palette: .gumleaf,
                latitude: -27.3696,
                longitude: 152.8905,
                isFeatured: false,
                publishedAt: date(daysAgo: 8, hour: 7, minute: 50),
                updatedAt: date(daysAgo: 1, hour: 14, minute: 10)
            ),
            PropertyListing(
                id: UUID(uuidString: "DAA3A4D1-0FE6-4FD7-8A81-68D7E1971004") ?? UUID(),
                title: "Corner-block apartment with city skyline views",
                headline: "Investor-friendly layout with strong recent sales evidence.",
                summary: "An upper-level apartment with panoramic views, oversized balcony, and a private-seller workflow built for fast shortlist-to-offer conversion.",
                propertyType: .apartment,
                status: .active,
                address: PropertyAddress(
                    street: "17/85 Moray Street",
                    suburb: "New Farm",
                    state: "QLD",
                    postcode: "4005"
                ),
                askingPrice: 865000,
                bedrooms: 2,
                bathrooms: 2,
                parkingSpaces: 1,
                landSizeText: "108 sqm",
                features: [
                    "City views",
                    "Secure parking",
                    "Lift access",
                    "Balcony",
                    "Walk to riverwalk"
                ],
                sellerID: sellerMasonID,
                inspectionSlots: [
                    InspectionSlot(
                        id: UUID(uuidString: "DAA3A4D1-0FE6-4FD7-8A81-68D7E1972005") ?? UUID(),
                        startsAt: date(daysAgo: -2, hour: 13, minute: 0),
                        endsAt: date(daysAgo: -2, hour: 13, minute: 25),
                        note: "Mid-week private appointment"
                    )
                ],
                marketPulse: MarketPulse(
                    valueEstimateLow: 840000,
                    valueEstimateHigh: 878000,
                    suburbMedian: 912000,
                    buyerDemandScore: 77,
                    averageDaysOnMarket: 21,
                    schoolInsight: SchoolInsight(
                        catchmentName: "New Farm State School",
                        walkMinutes: 10,
                        score: 85
                    )
                ),
                comparableSales: [
                    ComparableSale(
                        id: UUID(uuidString: "DAA3A4D1-0FE6-4FD7-8A81-68D7E1973006") ?? UUID(),
                        address: "12/71 Moray Street, New Farm",
                        soldPrice: 855000,
                        soldAt: date(daysAgo: 16, hour: 0, minute: 0),
                        bedrooms: 2
                    )
                ],
                palette: .dusk,
                latitude: -27.4685,
                longitude: 153.0459,
                isFeatured: true,
                publishedAt: date(daysAgo: 4, hour: 10, minute: 5),
                updatedAt: date(daysAgo: 0, hour: 9, minute: 20)
            )
        ]
    }

    static let savedSearches: [SavedSearch] = [
        SavedSearch(
            id: UUID(uuidString: "7A19AB1A-B78A-440D-8308-1F95FC891001") ?? UUID(),
            title: "Inner north family homes",
            suburb: "Wilston",
            minimumPrice: 950000,
            maximumPrice: 1400000,
            minimumBedrooms: 3,
            propertyTypes: [.house, .townhouse],
            alertsEnabled: true
        ),
        SavedSearch(
            id: UUID(uuidString: "7A19AB1A-B78A-440D-8308-1F95FC891002") ?? UUID(),
            title: "Graceville catchment watchlist",
            suburb: "Graceville",
            minimumPrice: 1200000,
            maximumPrice: 1700000,
            minimumBedrooms: 4,
            propertyTypes: [.house],
            alertsEnabled: true
        )
    ]

    static let plannedInspectionIDs: Set<UUID> = [
        UUID(uuidString: "DAA3A4D1-0FE6-4FD7-8A81-68D7E1972001") ?? UUID(),
        UUID(uuidString: "DAA3A4D1-0FE6-4FD7-8A81-68D7E1972003") ?? UUID()
    ]

    static func marketplaceState(for userID: UUID) -> UserMarketplaceState {
        switch userID {
        case buyerOliviaID:
            return UserMarketplaceState(
                userID: userID,
                favoriteListingIDs: [
                    UUID(uuidString: "DAA3A4D1-0FE6-4FD7-8A81-68D7E1971001") ?? UUID(),
                    UUID(uuidString: "DAA3A4D1-0FE6-4FD7-8A81-68D7E1971004") ?? UUID()
                ],
                savedSearches: savedSearches
            )
        case buyerNoahID:
            return UserMarketplaceState(
                userID: userID,
                favoriteListingIDs: [
                    UUID(uuidString: "DAA3A4D1-0FE6-4FD7-8A81-68D7E1971004") ?? UUID(),
                    UUID(uuidString: "DAA3A4D1-0FE6-4FD7-8A81-68D7E1971002") ?? UUID()
                ],
                savedSearches: [
                    SavedSearch(
                        id: UUID(uuidString: "7A19AB1A-B78A-440D-8308-1F95FC891011") ?? UUID(),
                        title: "Inner north buyer shortlist",
                        suburb: "Wilston",
                        minimumPrice: 900000,
                        maximumPrice: 1400000,
                        minimumBedrooms: 3,
                        propertyTypes: [.house, .townhouse],
                        alertsEnabled: true
                    ),
                    SavedSearch(
                        id: UUID(uuidString: "7A19AB1A-B78A-440D-8308-1F95FC891012") ?? UUID(),
                        title: "Riverfront apartment watch",
                        suburb: "New Farm",
                        minimumPrice: 700000,
                        maximumPrice: 980000,
                        minimumBedrooms: 2,
                        propertyTypes: [.apartment],
                        alertsEnabled: true
                    )
                ]
            )
        default:
            return UserMarketplaceState(
                userID: userID,
                favoriteListingIDs: [],
                savedSearches: []
            )
        }
    }
}
