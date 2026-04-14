import Foundation

nonisolated enum MarketplaceRemoteMode: Sendable {
    case localOnly
    case remotePreferred
}

nonisolated struct MarketplaceBackendConfiguration: Sendable {
    var mode: MarketplaceRemoteMode
    var baseURL: URL?
    var requestTimeout: TimeInterval = 4

    static func launchDefault(launchConfiguration: AppLaunchConfiguration) -> MarketplaceBackendConfiguration {
        if launchConfiguration.isScreenshotMode {
            return MarketplaceBackendConfiguration(mode: .localOnly, baseURL: nil)
        }

        if let rawURL = ProcessInfo.processInfo.environment["REAL_O_WHO_API_BASE_URL"],
           let url = URL(string: rawURL) {
            return MarketplaceBackendConfiguration(mode: .remotePreferred, baseURL: url)
        }

#if targetEnvironment(simulator)
        return MarketplaceBackendConfiguration(
            mode: .remotePreferred,
            baseURL: URL(string: "http://127.0.0.1:8080")
        )
#else
        return MarketplaceBackendConfiguration(mode: .localOnly, baseURL: nil)
#endif
    }
}

nonisolated enum MarketplaceHTTPError: LocalizedError, Sendable {
    case missingBaseURL
    case invalidResponse
    case server(statusCode: Int, message: String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .missingBaseURL:
            return "The marketplace backend URL is not configured."
        case .invalidResponse:
            return "The marketplace backend returned an invalid response."
        case let .server(_, message):
            return message
        case let .transport(message):
            return message
        }
    }

    var canFallbackToLocal: Bool {
        switch self {
        case .server:
            return false
        case .missingBaseURL, .invalidResponse, .transport:
            return true
        }
    }
}

nonisolated struct MarketplaceWireUserProfile: Codable, Sendable {
    var id: UUID
    var name: String
    var role: UserRole
    var suburb: String
    var headline: String
    var verificationNote: String
    var buyerStage: BuyerStage?
    var verificationChecks: [UserVerificationCheck]
    var conciergeReminderIntensity: ConciergeReminderIntensity

    init(_ user: UserProfile) {
        id = user.id
        name = user.name
        role = user.role
        suburb = user.suburb
        headline = user.headline
        verificationNote = user.verificationNote
        buyerStage = user.buyerStage
        verificationChecks = user.verificationChecks
        conciergeReminderIntensity = user.conciergeReminderIntensity
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case role
        case suburb
        case headline
        case verificationNote
        case buyerStage
        case verificationChecks
        case conciergeReminderIntensity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        role = try container.decode(UserRole.self, forKey: .role)
        suburb = try container.decode(String.self, forKey: .suburb)
        headline = try container.decode(String.self, forKey: .headline)
        verificationNote = try container.decode(String.self, forKey: .verificationNote)
        buyerStage = try container.decodeIfPresent(BuyerStage.self, forKey: .buyerStage)
        verificationChecks = try container.decodeIfPresent([UserVerificationCheck].self, forKey: .verificationChecks) ?? []
        conciergeReminderIntensity = try container.decodeIfPresent(
            ConciergeReminderIntensity.self,
            forKey: .conciergeReminderIntensity
        ) ?? .balanced
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(role, forKey: .role)
        try container.encode(suburb, forKey: .suburb)
        try container.encode(headline, forKey: .headline)
        try container.encode(verificationNote, forKey: .verificationNote)
        try container.encodeIfPresent(buyerStage, forKey: .buyerStage)
        try container.encode(verificationChecks, forKey: .verificationChecks)
        try container.encode(conciergeReminderIntensity, forKey: .conciergeReminderIntensity)
    }

    nonisolated func toAppModel() -> UserProfile {
        UserProfile(
            id: id,
            name: name,
            role: role,
            suburb: suburb,
            headline: headline,
            verificationNote: verificationNote,
            buyerStage: buyerStage,
            verificationChecks: verificationChecks,
            conciergeReminderIntensity: conciergeReminderIntensity
        )
    }
}

nonisolated struct MarketplaceWireAuthAccount: Codable, Sendable {
    var id: UUID
    var userId: UUID
    var email: String
    var passwordSaltBase64: String
    var passwordHashBase64: String
    var createdAt: Date
    var lastSignedInAt: Date?

    nonisolated func toAppModel() -> LocalAuthAccount {
        LocalAuthAccount(
            id: id,
            userID: userId,
            email: email,
            passwordSaltBase64: passwordSaltBase64,
            passwordHashBase64: passwordHashBase64,
            createdAt: createdAt,
            lastSignedInAt: lastSignedInAt
        )
    }
}

nonisolated struct MarketplaceWireAuthSessionEnvelope: Codable, Sendable {
    var user: MarketplaceWireUserProfile
    var account: MarketplaceWireAuthAccount

    nonisolated func toAppModel() -> MarketplaceAuthSession {
        MarketplaceAuthSession(
            user: user.toAppModel(),
            account: account.toAppModel()
        )
    }
}

nonisolated struct MarketplaceWireMessage: Codable, Sendable {
    var id: UUID
    var senderId: UUID
    var sentAt: Date
    var body: String
    var isSystem: Bool
    var saleTaskTarget: SaleReminderNavigationTarget?

    nonisolated init(_ message: EncryptedMessage) {
        id = message.id
        senderId = message.senderID
        sentAt = message.sentAt
        body = message.body
        isSystem = message.isSystem
        saleTaskTarget = message.saleTaskTarget
    }

    nonisolated func toAppModel() -> EncryptedMessage {
        EncryptedMessage(
            id: id,
            senderID: senderId,
            sentAt: sentAt,
            body: body,
            isSystem: isSystem,
            saleTaskTarget: saleTaskTarget
        )
    }
}

nonisolated struct MarketplaceWireConversation: Codable, Sendable {
    var id: UUID
    var listingId: UUID
    var participantIds: [UUID]
    var encryptionLabel: String
    var updatedAt: Date
    var messages: [MarketplaceWireMessage]

    nonisolated init(_ conversation: EncryptedConversation) {
        id = conversation.id
        listingId = conversation.listingID
        participantIds = conversation.participantIDs
        encryptionLabel = conversation.encryptionLabel
        updatedAt = conversation.updatedAt
        messages = conversation.messages.map { MarketplaceWireMessage($0) }
    }

    nonisolated func toAppModel() -> EncryptedConversation {
        EncryptedConversation(
            id: id,
            listingID: listingId,
            participantIDs: participantIds,
            encryptionLabel: encryptionLabel,
            updatedAt: updatedAt,
            messages: messages.map { $0.toAppModel() }
        )
    }
}

nonisolated struct MarketplaceWireLegalProfessional: Codable, Sendable {
    var id: String
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

    nonisolated func toAppModel() -> LegalProfessional {
        LegalProfessional(
            id: id,
            name: name,
            specialties: specialties,
            address: address,
            suburb: suburb,
            phoneNumber: phoneNumber,
            websiteURL: websiteURL,
            mapsURL: mapsURL,
            latitude: latitude,
            longitude: longitude,
            rating: rating,
            reviewCount: reviewCount,
            source: source,
            searchSummary: searchSummary
        )
    }
}

nonisolated struct MarketplaceWireLegalSelection: Codable, Sendable {
    var userID: UUID
    var selectedAt: Date
    var professional: MarketplaceWireLegalProfessional

    nonisolated init(_ selection: LegalSelection) {
        userID = selection.userID
        selectedAt = selection.selectedAt
        professional = MarketplaceWireLegalProfessional(
            id: selection.professional.id,
            name: selection.professional.name,
            specialties: selection.professional.specialties,
            address: selection.professional.address,
            suburb: selection.professional.suburb,
            phoneNumber: selection.professional.phoneNumber,
            websiteURL: selection.professional.websiteURL,
            mapsURL: selection.professional.mapsURL,
            latitude: selection.professional.latitude,
            longitude: selection.professional.longitude,
            rating: selection.professional.rating,
            reviewCount: selection.professional.reviewCount,
            source: selection.professional.source,
            searchSummary: selection.professional.searchSummary
        )
    }

    nonisolated func toAppModel() -> LegalSelection {
        LegalSelection(
            userID: userID,
            selectedAt: selectedAt,
            professional: professional.toAppModel()
        )
    }
}

nonisolated struct MarketplaceWirePostSaleConciergeProvider: Codable, Sendable {
    var id: String
    var serviceKind: PostSaleConciergeServiceKind
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
    var indicativePriceLow: Int?
    var indicativePriceHigh: Int?
    var estimatedResponseHours: Int?
    var source: PostSaleConciergeProviderSource
    var searchSummary: String

    nonisolated init(_ provider: PostSaleConciergeProvider) {
        id = provider.id
        serviceKind = provider.serviceKind
        name = provider.name
        specialties = provider.specialties
        address = provider.address
        suburb = provider.suburb
        phoneNumber = provider.phoneNumber
        websiteURL = provider.websiteURL
        mapsURL = provider.mapsURL
        latitude = provider.latitude
        longitude = provider.longitude
        rating = provider.rating
        reviewCount = provider.reviewCount
        indicativePriceLow = provider.indicativePriceLow
        indicativePriceHigh = provider.indicativePriceHigh
        estimatedResponseHours = provider.estimatedResponseHours
        source = provider.source
        searchSummary = provider.searchSummary
    }

    nonisolated func toAppModel() -> PostSaleConciergeProvider {
        PostSaleConciergeProvider(
            id: id,
            serviceKind: serviceKind,
            name: name,
            specialties: specialties,
            address: address,
            suburb: suburb,
            phoneNumber: phoneNumber,
            websiteURL: websiteURL,
            mapsURL: mapsURL,
            latitude: latitude,
            longitude: longitude,
            rating: rating,
            reviewCount: reviewCount,
            indicativePriceLow: indicativePriceLow,
            indicativePriceHigh: indicativePriceHigh,
            estimatedResponseHours: estimatedResponseHours,
            source: source,
            searchSummary: searchSummary
        )
    }
}

nonisolated struct MarketplaceWirePostSaleFeedbackEntry: Codable, Sendable {
    var submittedAt: Date
    var rating: Int
    var notes: String
    var submittedByUserID: UUID
    var submittedByName: String

    nonisolated init(_ entry: PostSaleFeedbackEntry) {
        submittedAt = entry.submittedAt
        rating = entry.rating
        notes = entry.notes
        submittedByUserID = entry.submittedByUserID
        submittedByName = entry.submittedByName
    }

    nonisolated func toAppModel() -> PostSaleFeedbackEntry {
        PostSaleFeedbackEntry(
            submittedAt: submittedAt,
            rating: rating,
            notes: notes,
            submittedByUserID: submittedByUserID,
            submittedByName: submittedByName
        )
    }
}

nonisolated struct MarketplaceWirePostSaleConciergeBooking: Codable, Sendable {
    var id: UUID
    var serviceKind: PostSaleConciergeServiceKind
    var provider: MarketplaceWirePostSaleConciergeProvider
    var scheduledFor: Date
    var bookedAt: Date
    var bookedByUserID: UUID
    var bookedByName: String
    var notes: String
    var previousScheduledFor: Date?
    var lastRescheduledAt: Date?
    var lastRescheduledByUserID: UUID?
    var lastRescheduledByName: String?
    var rescheduleCount: Int?
    var estimatedCost: Int?
    var quoteApprovedAt: Date?
    var quoteApprovedByUserID: UUID?
    var quoteApprovedByName: String?
    var providerConfirmedAt: Date?
    var providerConfirmedByUserID: UUID?
    var providerConfirmedByName: String?
    var providerConfirmationNote: String?
    var reminderSnoozedUntil: Date?
    var lastFollowUpAt: Date?
    var lastFollowUpByUserID: UUID?
    var lastFollowUpByName: String?
    var followUpCount: Int?
    var lastFollowUpNote: String?
    var invoiceAmount: Int?
    var invoiceFileName: String?
    var invoiceMimeType: String?
    var invoiceAttachmentBase64: String?
    var invoiceUploadedAt: Date?
    var paidAmount: Int?
    var paymentConfirmedAt: Date?
    var paymentConfirmedByUserID: UUID?
    var paymentConfirmedByName: String?
    var paymentProofFileName: String?
    var paymentProofMimeType: String?
    var paymentProofAttachmentBase64: String?
    var paymentProofUploadedAt: Date?
    var cancelledAt: Date?
    var cancelledByUserID: UUID?
    var cancelledByName: String?
    var cancellationReason: String?
    var refundAmount: Int?
    var refundProcessedAt: Date?
    var refundProcessedByUserID: UUID?
    var refundProcessedByName: String?
    var refundNote: String?
    var issueKind: PostSaleConciergeIssueKind?
    var issueLoggedAt: Date?
    var issueLoggedByUserID: UUID?
    var issueLoggedByName: String?
    var issueNote: String?
    var issueResolvedAt: Date?
    var issueResolvedByUserID: UUID?
    var issueResolvedByName: String?
    var issueResolutionNote: String?
    var providerAuditHistory: [MarketplaceWirePostSaleConciergeProviderAuditEntry]?
    var status: PostSaleConciergeBookingStatus
    var completedAt: Date?

    nonisolated init(_ booking: PostSaleConciergeBooking) {
        id = booking.id
        serviceKind = booking.serviceKind
        provider = MarketplaceWirePostSaleConciergeProvider(booking.provider)
        scheduledFor = booking.scheduledFor
        bookedAt = booking.bookedAt
        bookedByUserID = booking.bookedByUserID
        bookedByName = booking.bookedByName
        notes = booking.notes
        previousScheduledFor = booking.previousScheduledFor
        lastRescheduledAt = booking.lastRescheduledAt
        lastRescheduledByUserID = booking.lastRescheduledByUserID
        lastRescheduledByName = booking.lastRescheduledByName
        rescheduleCount = booking.rescheduleCount
        estimatedCost = booking.estimatedCost
        quoteApprovedAt = booking.quoteApprovedAt
        quoteApprovedByUserID = booking.quoteApprovedByUserID
        quoteApprovedByName = booking.quoteApprovedByName
        providerConfirmedAt = booking.providerConfirmedAt
        providerConfirmedByUserID = booking.providerConfirmedByUserID
        providerConfirmedByName = booking.providerConfirmedByName
        providerConfirmationNote = booking.providerConfirmationNote
        reminderSnoozedUntil = booking.reminderSnoozedUntil
        lastFollowUpAt = booking.lastFollowUpAt
        lastFollowUpByUserID = booking.lastFollowUpByUserID
        lastFollowUpByName = booking.lastFollowUpByName
        followUpCount = booking.followUpCount
        lastFollowUpNote = booking.lastFollowUpNote
        invoiceAmount = booking.invoiceAmount
        invoiceFileName = booking.invoiceFileName
        invoiceMimeType = booking.invoiceMimeType
        invoiceAttachmentBase64 = booking.invoiceAttachmentBase64
        invoiceUploadedAt = booking.invoiceUploadedAt
        paidAmount = booking.paidAmount
        paymentConfirmedAt = booking.paymentConfirmedAt
        paymentConfirmedByUserID = booking.paymentConfirmedByUserID
        paymentConfirmedByName = booking.paymentConfirmedByName
        paymentProofFileName = booking.paymentProofFileName
        paymentProofMimeType = booking.paymentProofMimeType
        paymentProofAttachmentBase64 = booking.paymentProofAttachmentBase64
        paymentProofUploadedAt = booking.paymentProofUploadedAt
        cancelledAt = booking.cancelledAt
        cancelledByUserID = booking.cancelledByUserID
        cancelledByName = booking.cancelledByName
        cancellationReason = booking.cancellationReason
        refundAmount = booking.refundAmount
        refundProcessedAt = booking.refundProcessedAt
        refundProcessedByUserID = booking.refundProcessedByUserID
        refundProcessedByName = booking.refundProcessedByName
        refundNote = booking.refundNote
        issueKind = booking.issueKind
        issueLoggedAt = booking.issueLoggedAt
        issueLoggedByUserID = booking.issueLoggedByUserID
        issueLoggedByName = booking.issueLoggedByName
        issueNote = booking.issueNote
        issueResolvedAt = booking.issueResolvedAt
        issueResolvedByUserID = booking.issueResolvedByUserID
        issueResolvedByName = booking.issueResolvedByName
        issueResolutionNote = booking.issueResolutionNote
        providerAuditHistory = booking.providerAuditHistory?.map(MarketplaceWirePostSaleConciergeProviderAuditEntry.init)
        status = booking.status
        completedAt = booking.completedAt
    }

    nonisolated func toAppModel() -> PostSaleConciergeBooking {
        PostSaleConciergeBooking(
            id: id,
            serviceKind: serviceKind,
            provider: provider.toAppModel(),
            scheduledFor: scheduledFor,
            bookedAt: bookedAt,
            bookedByUserID: bookedByUserID,
            bookedByName: bookedByName,
            notes: notes,
            previousScheduledFor: previousScheduledFor,
            lastRescheduledAt: lastRescheduledAt,
            lastRescheduledByUserID: lastRescheduledByUserID,
            lastRescheduledByName: lastRescheduledByName,
            rescheduleCount: rescheduleCount,
            estimatedCost: estimatedCost,
            quoteApprovedAt: quoteApprovedAt,
            quoteApprovedByUserID: quoteApprovedByUserID,
            quoteApprovedByName: quoteApprovedByName,
            providerConfirmedAt: providerConfirmedAt,
            providerConfirmedByUserID: providerConfirmedByUserID,
            providerConfirmedByName: providerConfirmedByName,
            providerConfirmationNote: providerConfirmationNote,
            reminderSnoozedUntil: reminderSnoozedUntil,
            lastFollowUpAt: lastFollowUpAt,
            lastFollowUpByUserID: lastFollowUpByUserID,
            lastFollowUpByName: lastFollowUpByName,
            followUpCount: followUpCount,
            lastFollowUpNote: lastFollowUpNote,
            invoiceAmount: invoiceAmount,
            invoiceFileName: invoiceFileName,
            invoiceMimeType: invoiceMimeType,
            invoiceAttachmentBase64: invoiceAttachmentBase64,
            invoiceUploadedAt: invoiceUploadedAt,
            paidAmount: paidAmount,
            paymentConfirmedAt: paymentConfirmedAt,
            paymentConfirmedByUserID: paymentConfirmedByUserID,
            paymentConfirmedByName: paymentConfirmedByName,
            paymentProofFileName: paymentProofFileName,
            paymentProofMimeType: paymentProofMimeType,
            paymentProofAttachmentBase64: paymentProofAttachmentBase64,
            paymentProofUploadedAt: paymentProofUploadedAt,
            cancelledAt: cancelledAt,
            cancelledByUserID: cancelledByUserID,
            cancelledByName: cancelledByName,
            cancellationReason: cancellationReason,
            refundAmount: refundAmount,
            refundProcessedAt: refundProcessedAt,
            refundProcessedByUserID: refundProcessedByUserID,
            refundProcessedByName: refundProcessedByName,
            refundNote: refundNote,
            issueKind: issueKind,
            issueLoggedAt: issueLoggedAt,
            issueLoggedByUserID: issueLoggedByUserID,
            issueLoggedByName: issueLoggedByName,
            issueNote: issueNote,
            issueResolvedAt: issueResolvedAt,
            issueResolvedByUserID: issueResolvedByUserID,
            issueResolvedByName: issueResolvedByName,
            issueResolutionNote: issueResolutionNote,
            providerAuditHistory: providerAuditHistory?.map { $0.toAppModel() },
            status: status,
            completedAt: completedAt
        )
    }
}

nonisolated struct MarketplaceWirePostSaleConciergeProviderAuditEntry: Codable, Sendable {
    var id: UUID
    var provider: MarketplaceWirePostSaleConciergeProvider
    var scheduledFor: Date
    var notes: String
    var replacedAt: Date
    var replacedByUserID: UUID
    var replacedByName: String
    var estimatedCost: Int?
    var quoteApprovedAt: Date?
    var providerConfirmedAt: Date?
    var providerConfirmationNote: String?
    var reminderSnoozedUntil: Date?
    var lastFollowUpAt: Date?
    var lastFollowUpByName: String?
    var followUpCount: Int?
    var lastFollowUpNote: String?
    var invoiceAmount: Int?
    var paidAmount: Int?
    var refundAmount: Int?
    var issueKind: PostSaleConciergeIssueKind?
    var issueNote: String?
    var issueResolvedAt: Date?
    var issueResolutionNote: String?
    var hadInvoiceAttachment: Bool
    var hadPaymentProof: Bool
    var status: PostSaleConciergeBookingStatus
    var completedAt: Date?
    var cancelledAt: Date?
    var cancellationReason: String?

    nonisolated init(_ auditEntry: PostSaleConciergeProviderAuditEntry) {
        id = auditEntry.id
        provider = MarketplaceWirePostSaleConciergeProvider(auditEntry.provider)
        scheduledFor = auditEntry.scheduledFor
        notes = auditEntry.notes
        replacedAt = auditEntry.replacedAt
        replacedByUserID = auditEntry.replacedByUserID
        replacedByName = auditEntry.replacedByName
        estimatedCost = auditEntry.estimatedCost
        quoteApprovedAt = auditEntry.quoteApprovedAt
        providerConfirmedAt = auditEntry.providerConfirmedAt
        providerConfirmationNote = auditEntry.providerConfirmationNote
        reminderSnoozedUntil = auditEntry.reminderSnoozedUntil
        lastFollowUpAt = auditEntry.lastFollowUpAt
        lastFollowUpByName = auditEntry.lastFollowUpByName
        followUpCount = auditEntry.followUpCount
        lastFollowUpNote = auditEntry.lastFollowUpNote
        invoiceAmount = auditEntry.invoiceAmount
        paidAmount = auditEntry.paidAmount
        refundAmount = auditEntry.refundAmount
        issueKind = auditEntry.issueKind
        issueNote = auditEntry.issueNote
        issueResolvedAt = auditEntry.issueResolvedAt
        issueResolutionNote = auditEntry.issueResolutionNote
        hadInvoiceAttachment = auditEntry.hadInvoiceAttachment
        hadPaymentProof = auditEntry.hadPaymentProof
        status = auditEntry.status
        completedAt = auditEntry.completedAt
        cancelledAt = auditEntry.cancelledAt
        cancellationReason = auditEntry.cancellationReason
    }

    nonisolated func toAppModel() -> PostSaleConciergeProviderAuditEntry {
        PostSaleConciergeProviderAuditEntry(
            id: id,
            provider: provider.toAppModel(),
            scheduledFor: scheduledFor,
            notes: notes,
            replacedAt: replacedAt,
            replacedByUserID: replacedByUserID,
            replacedByName: replacedByName,
            estimatedCost: estimatedCost,
            quoteApprovedAt: quoteApprovedAt,
            providerConfirmedAt: providerConfirmedAt,
            providerConfirmationNote: providerConfirmationNote,
            reminderSnoozedUntil: reminderSnoozedUntil,
            lastFollowUpAt: lastFollowUpAt,
            lastFollowUpByName: lastFollowUpByName,
            followUpCount: followUpCount,
            lastFollowUpNote: lastFollowUpNote,
            invoiceAmount: invoiceAmount,
            paidAmount: paidAmount,
            refundAmount: refundAmount,
            issueKind: issueKind,
            issueNote: issueNote,
            issueResolvedAt: issueResolvedAt,
            issueResolutionNote: issueResolutionNote,
            hadInvoiceAttachment: hadInvoiceAttachment,
            hadPaymentProof: hadPaymentProof,
            status: status,
            completedAt: completedAt,
            cancelledAt: cancelledAt,
            cancellationReason: cancellationReason
        )
    }
}

nonisolated struct MarketplaceWireContractPacket: Codable, Sendable {
    var id: UUID
    var generatedAt: Date
    var listingID: UUID
    var offerID: UUID
    var buyerID: UUID
    var sellerID: UUID
    var buyerRepresentative: MarketplaceWireLegalProfessional
    var sellerRepresentative: MarketplaceWireLegalProfessional
    var summary: String
    var buyerSignedAt: Date?
    var sellerSignedAt: Date?

    nonisolated init(_ packet: ContractPacket) {
        id = packet.id
        generatedAt = packet.generatedAt
        listingID = packet.listingID
        offerID = packet.offerID
        buyerID = packet.buyerID
        sellerID = packet.sellerID
        buyerRepresentative = MarketplaceWireLegalProfessional(
            id: packet.buyerRepresentative.id,
            name: packet.buyerRepresentative.name,
            specialties: packet.buyerRepresentative.specialties,
            address: packet.buyerRepresentative.address,
            suburb: packet.buyerRepresentative.suburb,
            phoneNumber: packet.buyerRepresentative.phoneNumber,
            websiteURL: packet.buyerRepresentative.websiteURL,
            mapsURL: packet.buyerRepresentative.mapsURL,
            latitude: packet.buyerRepresentative.latitude,
            longitude: packet.buyerRepresentative.longitude,
            rating: packet.buyerRepresentative.rating,
            reviewCount: packet.buyerRepresentative.reviewCount,
            source: packet.buyerRepresentative.source,
            searchSummary: packet.buyerRepresentative.searchSummary
        )
        sellerRepresentative = MarketplaceWireLegalProfessional(
            id: packet.sellerRepresentative.id,
            name: packet.sellerRepresentative.name,
            specialties: packet.sellerRepresentative.specialties,
            address: packet.sellerRepresentative.address,
            suburb: packet.sellerRepresentative.suburb,
            phoneNumber: packet.sellerRepresentative.phoneNumber,
            websiteURL: packet.sellerRepresentative.websiteURL,
            mapsURL: packet.sellerRepresentative.mapsURL,
            latitude: packet.sellerRepresentative.latitude,
            longitude: packet.sellerRepresentative.longitude,
            rating: packet.sellerRepresentative.rating,
            reviewCount: packet.sellerRepresentative.reviewCount,
            source: packet.sellerRepresentative.source,
            searchSummary: packet.sellerRepresentative.searchSummary
        )
        summary = packet.summary
        buyerSignedAt = packet.buyerSignedAt
        sellerSignedAt = packet.sellerSignedAt
    }

    nonisolated func toAppModel() -> ContractPacket {
        ContractPacket(
            id: id,
            generatedAt: generatedAt,
            listingID: listingID,
            offerID: offerID,
            buyerID: buyerID,
            sellerID: sellerID,
            buyerRepresentative: buyerRepresentative.toAppModel(),
            sellerRepresentative: sellerRepresentative.toAppModel(),
            summary: summary,
            buyerSignedAt: buyerSignedAt,
            sellerSignedAt: sellerSignedAt
        )
    }
}

nonisolated struct MarketplaceWireSaleDocument: Codable, Sendable {
    var id: UUID
    var kind: SaleDocumentKind
    var createdAt: Date
    var fileName: String
    var summary: String
    var uploadedByUserID: UUID
    var uploadedByName: String
    var packetID: UUID?
    var mimeType: String?
    var attachmentBase64: String?

    nonisolated init(_ document: SaleDocument) {
        id = document.id
        kind = document.kind
        createdAt = document.createdAt
        fileName = document.fileName
        summary = document.summary
        uploadedByUserID = document.uploadedByUserID
        uploadedByName = document.uploadedByName
        packetID = document.packetID
        mimeType = document.mimeType
        attachmentBase64 = document.attachmentBase64
    }

    nonisolated func toAppModel() -> SaleDocument {
        SaleDocument(
            id: id,
            kind: kind,
            createdAt: createdAt,
            fileName: fileName,
            summary: summary,
            uploadedByUserID: uploadedByUserID,
            uploadedByName: uploadedByName,
            packetID: packetID,
            mimeType: mimeType,
            attachmentBase64: attachmentBase64
        )
    }
}

nonisolated struct MarketplaceWireSaleWorkspaceInvite: Codable, Sendable {
    var id: UUID
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

    nonisolated init(_ invite: SaleWorkspaceInvite) {
        id = invite.id
        role = invite.role
        createdAt = invite.createdAt
        professionalName = invite.professionalName
        professionalSpecialty = invite.professionalSpecialty
        shareCode = invite.shareCode
        shareMessage = invite.shareMessage
        expiresAt = invite.expiresAt
        activatedAt = invite.activatedAt
        revokedAt = invite.revokedAt
        acknowledgedAt = invite.acknowledgedAt
        lastSharedAt = invite.lastSharedAt
        shareCount = invite.shareCount
        generatedByUserID = invite.generatedByUserID
        generatedByName = invite.generatedByName
    }

    nonisolated func toAppModel() -> SaleWorkspaceInvite {
        SaleWorkspaceInvite(
            id: id,
            role: role,
            createdAt: createdAt,
            professionalName: professionalName,
            professionalSpecialty: professionalSpecialty,
            shareCode: shareCode,
            shareMessage: shareMessage,
            expiresAt: expiresAt,
            activatedAt: activatedAt,
            revokedAt: revokedAt,
            acknowledgedAt: acknowledgedAt,
            lastSharedAt: lastSharedAt,
            shareCount: shareCount,
            generatedByUserID: generatedByUserID,
            generatedByName: generatedByName
        )
    }
}

nonisolated struct MarketplaceWireSaleRecord: Codable, Sendable {
    var id: UUID
    var listingID: UUID
    var buyerID: UUID
    var sellerID: UUID
    var amount: Int
    var conditions: String
    var createdAt: Date
    var status: OfferStatus
    var sellerRelationshipStatus: SellerBuyerRelationshipStatus
    var buyerLegalSelection: MarketplaceWireLegalSelection?
    var sellerLegalSelection: MarketplaceWireLegalSelection?
    var contractPacket: MarketplaceWireContractPacket?
    var settlementCompletedAt: Date?
    var utilitiesTransferCompletedAt: Date?
    var addressUpdateCompletedAt: Date?
    var buyerFeedback: MarketplaceWirePostSaleFeedbackEntry?
    var sellerFeedback: MarketplaceWirePostSaleFeedbackEntry?
    var conciergeBookings: [MarketplaceWirePostSaleConciergeBooking]?
    var invites: [MarketplaceWireSaleWorkspaceInvite]
    var documents: [MarketplaceWireSaleDocument]
    var updates: [SaleUpdateMessage]

    nonisolated init(_ offer: OfferRecord) {
        id = offer.id
        listingID = offer.listingID
        buyerID = offer.buyerID
        sellerID = offer.sellerID
        amount = offer.amount
        conditions = offer.conditions
        createdAt = offer.createdAt
        status = offer.status
        sellerRelationshipStatus = offer.sellerRelationshipStatus
        buyerLegalSelection = offer.buyerLegalSelection.map(MarketplaceWireLegalSelection.init)
        sellerLegalSelection = offer.sellerLegalSelection.map(MarketplaceWireLegalSelection.init)
        contractPacket = offer.contractPacket.map(MarketplaceWireContractPacket.init)
        settlementCompletedAt = offer.settlementCompletedAt
        utilitiesTransferCompletedAt = offer.utilitiesTransferCompletedAt
        addressUpdateCompletedAt = offer.addressUpdateCompletedAt
        buyerFeedback = offer.buyerFeedback.map(MarketplaceWirePostSaleFeedbackEntry.init)
        sellerFeedback = offer.sellerFeedback.map(MarketplaceWirePostSaleFeedbackEntry.init)
        conciergeBookings = offer.conciergeBookings.map(MarketplaceWirePostSaleConciergeBooking.init)
        invites = offer.invites.map(MarketplaceWireSaleWorkspaceInvite.init)
        documents = offer.documents.map(MarketplaceWireSaleDocument.init)
        updates = offer.updates
    }

    nonisolated func toAppModel() -> OfferRecord {
        OfferRecord(
            id: id,
            listingID: listingID,
            buyerID: buyerID,
            sellerID: sellerID,
            amount: amount,
            conditions: conditions,
            createdAt: createdAt,
            status: status,
            sellerRelationshipStatus: sellerRelationshipStatus,
            buyerLegalSelection: buyerLegalSelection?.toAppModel(),
            sellerLegalSelection: sellerLegalSelection?.toAppModel(),
            contractPacket: contractPacket?.toAppModel(),
            settlementCompletedAt: settlementCompletedAt,
            utilitiesTransferCompletedAt: utilitiesTransferCompletedAt,
            addressUpdateCompletedAt: addressUpdateCompletedAt,
            buyerFeedback: buyerFeedback?.toAppModel(),
            sellerFeedback: sellerFeedback?.toAppModel(),
            conciergeBookings: conciergeBookings?.map { $0.toAppModel() } ?? [],
            invites: invites.map { $0.toAppModel() },
            documents: documents.map { $0.toAppModel() },
            updates: updates
        )
    }
}

private nonisolated struct MarketplaceWireConversationEnvelope: Codable, Sendable {
    var conversation: MarketplaceWireConversation
}

private nonisolated struct MarketplaceWireConversationListEnvelope: Codable, Sendable {
    var conversations: [MarketplaceWireConversation]
}

private nonisolated struct MarketplaceWireLegalProfessionalEnvelope: Codable, Sendable {
    var professionals: [MarketplaceWireLegalProfessional]
}

private nonisolated struct MarketplaceWirePostSaleConciergeEnvelope: Codable, Sendable {
    var providers: [MarketplaceWirePostSaleConciergeProvider]
}

private nonisolated struct MarketplaceWireListingEnvelope: Codable, Sendable {
    var listing: PropertyListing?
}

private nonisolated struct MarketplaceWireListingListEnvelope: Codable, Sendable {
    var listings: [PropertyListing]
}

private nonisolated struct MarketplaceWireUserMarketplaceStateEnvelope: Codable, Sendable {
    var state: UserMarketplaceState
}

private nonisolated struct MarketplaceWireSaleTaskSnapshotViewerStateEnvelope: Codable, Sendable {
    var state: SaleTaskSnapshotViewerState
}

private nonisolated struct MarketplaceWireSaleEnvelope: Codable, Sendable {
    var sale: MarketplaceWireSaleRecord?
}

private nonisolated struct MarketplaceWireSaleListEnvelope: Codable, Sendable {
    var sales: [MarketplaceWireSaleRecord]
}

private nonisolated struct MarketplaceWireLegalWorkspaceEnvelope: Codable, Sendable {
    var listing: PropertyListing?
    var sale: MarketplaceWireSaleRecord?
    var invite: MarketplaceWireSaleWorkspaceInvite?
}

private nonisolated struct MarketplaceWireErrorEnvelope: Decodable, Sendable {
    var error: String?
}

private nonisolated struct MarketplaceWireSignInRequest: Codable, Sendable {
    var email: String
    var password: String
}

private nonisolated struct MarketplaceWireSignUpRequest: Codable, Sendable {
    var name: String
    var email: String
    var password: String
    var role: UserRole
    var suburb: String
}

private nonisolated struct MarketplaceWireAcknowledgementEnvelope: Codable, Sendable {
    var ok: Bool
}

nonisolated struct MarketplaceHTTPClient: Sendable {
    let configuration: MarketplaceBackendConfiguration
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(configuration: MarketplaceBackendConfiguration) {
        self.configuration = configuration
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func get<Response: Decodable>(
        path: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> Response {
        try await send(path: path, method: "GET", queryItems: queryItems, body: Optional<Int>.none)
    }

    func post<Body: Encodable, Response: Decodable>(
        path: String,
        body: Body
    ) async throws -> Response {
        try await send(path: path, method: "POST", queryItems: [], body: body)
    }

    func put<Body: Encodable, Response: Decodable>(
        path: String,
        body: Body
    ) async throws -> Response {
        try await send(path: path, method: "PUT", queryItems: [], body: body)
    }

    func delete<Response: Decodable>(
        path: String
    ) async throws -> Response {
        try await send(path: path, method: "DELETE", queryItems: [], body: Optional<Int>.none)
    }

    private func send<Body: Encodable, Response: Decodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem],
        body: Body?
    ) async throws -> Response {
        guard let baseURL = configuration.baseURL else {
            throw MarketplaceHTTPError.missingBaseURL
        }

        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw MarketplaceHTTPError.invalidResponse
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw MarketplaceHTTPError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = configuration.requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body {
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw MarketplaceHTTPError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let message = (try? decoder.decode(MarketplaceWireErrorEnvelope.self, from: data).error) ?? "Backend request failed."
                throw MarketplaceHTTPError.server(statusCode: httpResponse.statusCode, message: message)
            }

            return try decoder.decode(Response.self, from: data)
        } catch let error as MarketplaceHTTPError {
            throw error
        } catch let error as URLError {
            throw MarketplaceHTTPError.transport(error.localizedDescription)
        } catch {
            throw MarketplaceHTTPError.transport(error.localizedDescription)
        }
    }
}

nonisolated struct RemoteMarketplaceAuthService: MarketplaceAuthServing, Sendable {
    let client: MarketplaceHTTPClient

    nonisolated func signIn(
        email: String,
        password: String,
        accounts _: [LocalAuthAccount],
        users _: [UserProfile]
    ) async throws -> MarketplaceAuthSession {
        let response: MarketplaceWireAuthSessionEnvelope = try await client.post(
            path: "v1/auth/sign-in",
            body: MarketplaceWireSignInRequest(email: email, password: password)
        )
        return response.toAppModel()
    }

    nonisolated func createAccount(
        registration: MarketplaceAuthRegistration,
        existingAccounts _: [LocalAuthAccount]
    ) async throws -> MarketplaceAuthSession {
        let response: MarketplaceWireAuthSessionEnvelope = try await client.post(
            path: "v1/auth/sign-up",
            body: MarketplaceWireSignUpRequest(
                name: registration.name,
                email: registration.email,
                password: registration.password,
                role: registration.role,
                suburb: registration.suburb
            )
        )
        return response.toAppModel()
    }

    nonisolated func deleteAccount(
        account _: LocalAuthAccount?,
        user: UserProfile
    ) async throws {
        let _: MarketplaceWireAcknowledgementEnvelope = try await client.delete(
            path: "v1/auth/account/\(user.id.uuidString)"
        )
    }
}

nonisolated struct FallbackMarketplaceAuthService: MarketplaceAuthServing, Sendable {
    let remote: RemoteMarketplaceAuthService
    let local: LocalMarketplaceAuthService
    let configuration: MarketplaceBackendConfiguration

    nonisolated func signIn(
        email: String,
        password: String,
        accounts: [LocalAuthAccount],
        users: [UserProfile]
    ) async throws -> MarketplaceAuthSession {
        guard configuration.mode == .remotePreferred else {
            return try await local.signIn(email: email, password: password, accounts: accounts, users: users)
        }

        do {
            return try await remote.signIn(email: email, password: password, accounts: accounts, users: users)
        } catch let error as MarketplaceHTTPError where error.canFallbackToLocal {
            return try await local.signIn(email: email, password: password, accounts: accounts, users: users)
        }
    }

    nonisolated func createAccount(
        registration: MarketplaceAuthRegistration,
        existingAccounts: [LocalAuthAccount]
    ) async throws -> MarketplaceAuthSession {
        guard configuration.mode == .remotePreferred else {
            return try await local.createAccount(registration: registration, existingAccounts: existingAccounts)
        }

        do {
            return try await remote.createAccount(registration: registration, existingAccounts: existingAccounts)
        } catch let error as MarketplaceHTTPError where error.canFallbackToLocal {
            return try await local.createAccount(registration: registration, existingAccounts: existingAccounts)
        }
    }

    nonisolated func deleteAccount(
        account: LocalAuthAccount?,
        user: UserProfile
    ) async throws {
        guard configuration.mode == .remotePreferred else {
            try await local.deleteAccount(account: account, user: user)
            return
        }

        do {
            try await remote.deleteAccount(account: account, user: user)
        } catch let error as MarketplaceHTTPError where error.canFallbackToLocal {
            try await local.deleteAccount(account: account, user: user)
        }
    }
}

protocol MarketplaceConversationSyncing: Sendable {
    nonisolated func fetchThreads(for userID: UUID) async throws -> [EncryptedConversation]
    nonisolated func upsertConversation(_ conversation: EncryptedConversation) async throws -> EncryptedConversation
}

nonisolated struct DisabledConversationSync: MarketplaceConversationSyncing, Sendable {
    nonisolated func fetchThreads(for _: UUID) async throws -> [EncryptedConversation] {
        []
    }

    nonisolated func upsertConversation(_ conversation: EncryptedConversation) async throws -> EncryptedConversation {
        conversation
    }
}

nonisolated struct RemoteConversationSync: MarketplaceConversationSyncing, Sendable {
    let client: MarketplaceHTTPClient

    nonisolated func fetchThreads(for userID: UUID) async throws -> [EncryptedConversation] {
        let response: MarketplaceWireConversationListEnvelope = try await client.get(
            path: "v1/conversations",
            queryItems: [URLQueryItem(name: "userId", value: userID.uuidString)]
        )
        return response.conversations.map { $0.toAppModel() }
    }

    nonisolated func upsertConversation(_ conversation: EncryptedConversation) async throws -> EncryptedConversation {
        let response: MarketplaceWireConversationEnvelope = try await client.put(
            path: "v1/conversations/\(conversation.id.uuidString)",
            body: MarketplaceWireConversation(conversation)
        )
        return response.conversation.toAppModel()
    }
}

protocol MarketplaceLegalProfessionalSearching: Sendable {
    nonisolated func searchProfessionals(near listing: PropertyListing) async throws -> [LegalProfessional]
}

protocol MarketplacePostSaleConciergeSearching: Sendable {
    nonisolated func searchProviders(
        near listing: PropertyListing,
        serviceKind: PostSaleConciergeServiceKind
    ) async throws -> [PostSaleConciergeProvider]
}

nonisolated struct LocalLegalProfessionalSearch: MarketplaceLegalProfessionalSearching, Sendable {
    private static let fallbackProfessionals: [LegalProfessional] = [
        LegalProfessional(
            id: "local-brisbane-conveyancing-group",
            name: "Brisbane Conveyancing Group",
            specialties: ["Conveyancing", "Contract review"],
            address: "Level 8, 123 Adelaide Street, Brisbane City QLD 4000",
            suburb: "Brisbane City",
            phoneNumber: "(07) 3123 4501",
            websiteURL: URL(string: "https://www.google.com/search?q=Brisbane+Conveyancing+Group+Brisbane+City+QLD"),
            mapsURL: URL(string: "https://maps.google.com/?q=123+Adelaide+Street+Brisbane+City+QLD+4000"),
            latitude: -27.4685,
            longitude: 153.0286,
            rating: 4.8,
            reviewCount: 61,
            source: .localFallback,
            searchSummary: "Handles private-sale contracts, cooling-off clauses, and settlement coordination."
        ),
        LegalProfessional(
            id: "local-rivercity-property-law",
            name: "Rivercity Property Law",
            specialties: ["Property solicitor", "Settlement support"],
            address: "42 Eagle Street, Brisbane City QLD 4000",
            suburb: "Brisbane City",
            phoneNumber: "(07) 3555 1180",
            websiteURL: URL(string: "https://www.google.com/search?q=Rivercity+Property+Law+Brisbane+Property+Solicitor"),
            mapsURL: URL(string: "https://maps.google.com/?q=42+Eagle+Street+Brisbane+City+QLD+4000"),
            latitude: -27.4708,
            longitude: 153.0304,
            rating: 4.7,
            reviewCount: 49,
            source: .localFallback,
            searchSummary: "Property-law team with contract preparation and buyer-seller signing support."
        ),
        LegalProfessional(
            id: "local-west-end-settlement",
            name: "West End Settlement Co",
            specialties: ["Conveyancing", "Buyer support"],
            address: "19 Boundary Street, West End QLD 4101",
            suburb: "West End",
            phoneNumber: "(07) 3844 9082",
            websiteURL: URL(string: "https://www.google.com/search?q=West+End+Settlement+Co+Property+Law+Brisbane"),
            mapsURL: URL(string: "https://maps.google.com/?q=19+Boundary+Street+West+End+QLD+4101"),
            latitude: -27.4812,
            longitude: 153.0099,
            rating: 4.6,
            reviewCount: 34,
            source: .localFallback,
            searchSummary: "Popular with owner-sellers wanting fixed-fee contract work and settlement checklists."
        ),
        LegalProfessional(
            id: "local-bulimba-legal",
            name: "Bulimba Legal & Conveyancing",
            specialties: ["Property lawyer", "Contract negotiation"],
            address: "77 Oxford Street, Bulimba QLD 4171",
            suburb: "Bulimba",
            phoneNumber: "(07) 3399 4412",
            websiteURL: URL(string: "https://www.google.com/search?q=Bulimba+Legal+Conveyancing+QLD"),
            mapsURL: URL(string: "https://maps.google.com/?q=77+Oxford+Street+Bulimba+QLD+4171"),
            latitude: -27.4523,
            longitude: 153.0577,
            rating: 4.8,
            reviewCount: 27,
            source: .localFallback,
            searchSummary: "Focuses on residential contracts, amendments, and pre-settlement issue resolution."
        ),
        LegalProfessional(
            id: "local-logan-private-sale-law",
            name: "Logan Private Sale Law",
            specialties: ["Solicitor", "Private sale paperwork"],
            address: "3 Wembley Road, Logan Central QLD 4114",
            suburb: "Logan Central",
            phoneNumber: "(07) 3290 7750",
            websiteURL: URL(string: "https://www.google.com/search?q=Logan+Private+Sale+Law+Logan+QLD"),
            mapsURL: URL(string: "https://maps.google.com/?q=3+Wembley+Road+Logan+Central+QLD+4114"),
            latitude: -27.6394,
            longitude: 153.1093,
            rating: 4.5,
            reviewCount: 18,
            source: .localFallback,
            searchSummary: "Helps private buyers and sellers handle contract exchange and settlement scheduling."
        ),
        LegalProfessional(
            id: "local-gold-coast-conveyancing",
            name: "Gold Coast Conveyancing Studio",
            specialties: ["Conveyancing", "e-signing support"],
            address: "9 Short Street, Southport QLD 4215",
            suburb: "Southport",
            phoneNumber: "(07) 5528 4100",
            websiteURL: URL(string: "https://www.google.com/search?q=Gold+Coast+Conveyancing+Studio+Southport+QLD"),
            mapsURL: URL(string: "https://maps.google.com/?q=9+Short+Street+Southport+QLD+4215"),
            latitude: -27.9682,
            longitude: 153.4086,
            rating: 4.7,
            reviewCount: 39,
            source: .localFallback,
            searchSummary: "Supports contract review, disclosure questions, and settlement on South East Queensland sales."
        )
    ]

    nonisolated func searchProfessionals(near listing: PropertyListing) async throws -> [LegalProfessional] {
        let normalizedSuburb = listing.address.suburb.lowercased()

        return Self.fallbackProfessionals
            .map { professional in
                (
                    professional: professional,
                    distanceKm: Self.distanceInKm(
                        latitudeA: listing.latitude,
                        longitudeA: listing.longitude,
                        latitudeB: professional.latitude,
                        longitudeB: professional.longitude
                    )
                )
            }
            .filter { item in
                item.distanceKm <= 120 || item.professional.suburb.lowercased().contains(normalizedSuburb)
            }
            .sorted { left, right in
                if left.distanceKm == right.distanceKm {
                    return (left.professional.rating ?? 0) > (right.professional.rating ?? 0)
                }

                return left.distanceKm < right.distanceKm
            }
            .prefix(8)
            .map { item in
                var professional = item.professional
                professional.searchSummary = "\(professional.searchSummary) Approx. \(item.distanceKm.formatted(.number.precision(.fractionLength(1)))) km from the property."
                return professional
            }
    }

    private static func distanceInKm(
        latitudeA: Double,
        longitudeA: Double,
        latitudeB: Double,
        longitudeB: Double
    ) -> Double {
        let earthRadiusKm = 6_371.0
        let deltaLatitude = (latitudeB - latitudeA) * .pi / 180
        let deltaLongitude = (longitudeB - longitudeA) * .pi / 180
        let startLatitude = latitudeA * .pi / 180
        let endLatitude = latitudeB * .pi / 180

        let a = sin(deltaLatitude / 2) * sin(deltaLatitude / 2) +
            cos(startLatitude) * cos(endLatitude) *
            sin(deltaLongitude / 2) * sin(deltaLongitude / 2)

        return earthRadiusKm * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}

nonisolated struct LocalPostSaleConciergeSearch: MarketplacePostSaleConciergeSearching, Sendable {
    private static let fallbackProviders: [PostSaleConciergeProvider] = [
        PostSaleConciergeProvider(
            id: "local-brisbane-move-right",
            serviceKind: .removalist,
            name: "Move Right Brisbane",
            specialties: ["House moves", "Packing", "Furniture assembly"],
            address: "27 Montague Road, South Brisbane QLD 4101",
            suburb: "South Brisbane",
            phoneNumber: "(07) 3211 2044",
            websiteURL: URL(string: "https://www.google.com/search?q=Move+Right+Brisbane+Removalists"),
            mapsURL: URL(string: "https://maps.google.com/?q=27+Montague+Road+South+Brisbane+QLD+4101"),
            latitude: -27.4734,
            longitude: 153.0134,
            rating: 4.8,
            reviewCount: 88,
            indicativePriceLow: 780,
            indicativePriceHigh: 1_150,
            estimatedResponseHours: 2,
            source: .localFallback,
            searchSummary: "Handles owner-seller moves, same-day truck support, and packing help after settlement."
        ),
        PostSaleConciergeProvider(
            id: "local-river-city-removals",
            serviceKind: .removalist,
            name: "River City Removals",
            specialties: ["Apartment moves", "Boxes supplied", "Local storage"],
            address: "6 Longland Street, Newstead QLD 4006",
            suburb: "Newstead",
            phoneNumber: "(07) 3180 7721",
            websiteURL: URL(string: "https://www.google.com/search?q=River+City+Removals+Brisbane"),
            mapsURL: URL(string: "https://maps.google.com/?q=6+Longland+Street+Newstead+QLD+4006"),
            latitude: -27.4506,
            longitude: 153.0455,
            rating: 4.7,
            reviewCount: 61,
            indicativePriceLow: 690,
            indicativePriceHigh: 980,
            estimatedResponseHours: 3,
            source: .localFallback,
            searchSummary: "Popular for inner-city townhouse and apartment moves with fast handover turnarounds."
        ),
        PostSaleConciergeProvider(
            id: "local-handover-clean-co",
            serviceKind: .cleaner,
            name: "Handover Clean Co",
            specialties: ["Exit clean", "Windows", "Carpet refresh"],
            address: "14 Logan Road, Woolloongabba QLD 4102",
            suburb: "Woolloongabba",
            phoneNumber: "(07) 3559 1420",
            websiteURL: URL(string: "https://www.google.com/search?q=Handover+Clean+Co+Brisbane"),
            mapsURL: URL(string: "https://maps.google.com/?q=14+Logan+Road+Woolloongabba+QLD+4102"),
            latitude: -27.4918,
            longitude: 153.0352,
            rating: 4.9,
            reviewCount: 54,
            indicativePriceLow: 320,
            indicativePriceHigh: 520,
            estimatedResponseHours: 4,
            source: .localFallback,
            searchSummary: "Specialises in pre-settlement touch-ups and final cleans for private-sale handovers."
        ),
        PostSaleConciergeProvider(
            id: "local-settlement-sparkle",
            serviceKind: .cleaner,
            name: "Settlement Sparkle Services",
            specialties: ["Move-in clean", "Bathrooms", "Outdoor sweep"],
            address: "88 Oxford Street, Bulimba QLD 4171",
            suburb: "Bulimba",
            phoneNumber: "(07) 3395 6108",
            websiteURL: URL(string: "https://www.google.com/search?q=Settlement+Sparkle+Services+Bulimba"),
            mapsURL: URL(string: "https://maps.google.com/?q=88+Oxford+Street+Bulimba+QLD+4171"),
            latitude: -27.4521,
            longitude: 153.0574,
            rating: 4.7,
            reviewCount: 31,
            indicativePriceLow: 260,
            indicativePriceHigh: 430,
            estimatedResponseHours: 6,
            source: .localFallback,
            searchSummary: "Good fit for fast occupancy changes where the buyer wants the property refreshed before move-in."
        ),
        PostSaleConciergeProvider(
            id: "local-switch-on-connect",
            serviceKind: .utilitiesConnection,
            name: "Switch On Move Connect",
            specialties: ["Electricity", "Gas", "Internet setup"],
            address: "Level 3, 99 Creek Street, Brisbane City QLD 4000",
            suburb: "Brisbane City",
            phoneNumber: "(07) 3222 5400",
            websiteURL: URL(string: "https://www.google.com/search?q=Switch+On+Move+Connect+Brisbane"),
            mapsURL: URL(string: "https://maps.google.com/?q=99+Creek+Street+Brisbane+City+QLD+4000"),
            latitude: -27.4662,
            longitude: 153.0298,
            rating: 4.6,
            reviewCount: 45,
            indicativePriceLow: 120,
            indicativePriceHigh: 260,
            estimatedResponseHours: 2,
            source: .localFallback,
            searchSummary: "Coordinates electricity, gas, and internet activation around settlement and move day."
        ),
        PostSaleConciergeProvider(
            id: "local-meter-to-modem",
            serviceKind: .utilitiesConnection,
            name: "Meter to Modem Concierge",
            specialties: ["Utility transfers", "NBN support", "Move-day checklist"],
            address: "52 Thomas Drive, Chevron Island QLD 4217",
            suburb: "Chevron Island",
            phoneNumber: "(07) 5531 3309",
            websiteURL: URL(string: "https://www.google.com/search?q=Meter+to+Modem+Concierge+QLD"),
            mapsURL: URL(string: "https://maps.google.com/?q=52+Thomas+Drive+Chevron+Island+QLD+4217"),
            latitude: -27.9982,
            longitude: 153.4286,
            rating: 4.5,
            reviewCount: 24,
            indicativePriceLow: 90,
            indicativePriceHigh: 180,
            estimatedResponseHours: 5,
            source: .localFallback,
            searchSummary: "Helpful for buyers who want utilities switched on before the first night in the property."
        ),
        PostSaleConciergeProvider(
            id: "local-key-bridge-handover",
            serviceKind: .keyHandover,
            name: "KeyBridge Handover",
            specialties: ["Key exchange", "Final walkthrough", "Remote inventory"],
            address: "19 Breakfast Creek Road, Newstead QLD 4006",
            suburb: "Newstead",
            phoneNumber: "(07) 3077 4120",
            websiteURL: URL(string: "https://www.google.com/search?q=KeyBridge+Handover+Brisbane"),
            mapsURL: URL(string: "https://maps.google.com/?q=19+Breakfast+Creek+Road+Newstead+QLD+4006"),
            latitude: -27.4424,
            longitude: 153.0435,
            rating: 4.8,
            reviewCount: 19,
            indicativePriceLow: 140,
            indicativePriceHigh: 260,
            estimatedResponseHours: 3,
            source: .localFallback,
            searchSummary: "Schedules key swaps, garage remote handover, and a short final property walk-through."
        ),
        PostSaleConciergeProvider(
            id: "local-settle-and-keys",
            serviceKind: .keyHandover,
            name: "Settle & Keys",
            specialties: ["Access packs", "Lockbox support", "Buyer-seller meetup"],
            address: "4 Wembley Road, Logan Central QLD 4114",
            suburb: "Logan Central",
            phoneNumber: "(07) 3299 8804",
            websiteURL: URL(string: "https://www.google.com/search?q=Settle+and+Keys+Logan+QLD"),
            mapsURL: URL(string: "https://maps.google.com/?q=4+Wembley+Road+Logan+Central+QLD+4114"),
            latitude: -27.6398,
            longitude: 153.1096,
            rating: 4.6,
            reviewCount: 22,
            indicativePriceLow: 110,
            indicativePriceHigh: 220,
            estimatedResponseHours: 5,
            source: .localFallback,
            searchSummary: "Useful for private sellers who want a neutral key and handover coordinator on settlement day."
        )
    ]

    nonisolated func searchProviders(
        near listing: PropertyListing,
        serviceKind: PostSaleConciergeServiceKind
    ) async throws -> [PostSaleConciergeProvider] {
        let normalizedSuburb = listing.address.suburb.lowercased()

        return Self.fallbackProviders
            .filter { $0.serviceKind == serviceKind }
            .map { provider in
                (
                    provider: provider,
                    distanceKm: Self.distanceInKm(
                        latitudeA: listing.latitude,
                        longitudeA: listing.longitude,
                        latitudeB: provider.latitude,
                        longitudeB: provider.longitude
                    )
                )
            }
            .filter { item in
                item.distanceKm <= 120 || item.provider.suburb.lowercased().contains(normalizedSuburb)
            }
            .sorted { left, right in
                if left.distanceKm == right.distanceKm {
                    return (left.provider.rating ?? 0) > (right.provider.rating ?? 0)
                }

                return left.distanceKm < right.distanceKm
            }
            .prefix(6)
            .map { item in
                var provider = item.provider
                provider.searchSummary = "\(provider.searchSummary) Approx. \(item.distanceKm.formatted(.number.precision(.fractionLength(1)))) km from the property."
                return provider
            }
    }

    private static func distanceInKm(
        latitudeA: Double,
        longitudeA: Double,
        latitudeB: Double,
        longitudeB: Double
    ) -> Double {
        let earthRadiusKm = 6_371.0
        let deltaLatitude = (latitudeB - latitudeA) * .pi / 180
        let deltaLongitude = (longitudeB - longitudeA) * .pi / 180
        let startLatitude = latitudeA * .pi / 180
        let endLatitude = latitudeB * .pi / 180

        let a = sin(deltaLatitude / 2) * sin(deltaLatitude / 2) +
            cos(startLatitude) * cos(endLatitude) *
            sin(deltaLongitude / 2) * sin(deltaLongitude / 2)

        return earthRadiusKm * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}

nonisolated struct RemoteLegalProfessionalSearch: MarketplaceLegalProfessionalSearching, Sendable {
    let client: MarketplaceHTTPClient

    nonisolated func searchProfessionals(near listing: PropertyListing) async throws -> [LegalProfessional] {
        let response: MarketplaceWireLegalProfessionalEnvelope = try await client.get(
            path: "v1/legal-professionals/search",
            queryItems: [
                URLQueryItem(name: "lat", value: String(listing.latitude)),
                URLQueryItem(name: "lng", value: String(listing.longitude)),
                URLQueryItem(name: "suburb", value: listing.address.suburb),
                URLQueryItem(name: "state", value: listing.address.state),
                URLQueryItem(name: "postcode", value: listing.address.postcode)
            ]
        )
        return response.professionals.map { $0.toAppModel() }
    }
}

nonisolated struct RemotePostSaleConciergeSearch: MarketplacePostSaleConciergeSearching, Sendable {
    let client: MarketplaceHTTPClient

    nonisolated func searchProviders(
        near listing: PropertyListing,
        serviceKind: PostSaleConciergeServiceKind
    ) async throws -> [PostSaleConciergeProvider] {
        let response: MarketplaceWirePostSaleConciergeEnvelope = try await client.get(
            path: "v1/post-sale-concierge/search",
            queryItems: [
                URLQueryItem(name: "kind", value: serviceKind.rawValue),
                URLQueryItem(name: "lat", value: String(listing.latitude)),
                URLQueryItem(name: "lng", value: String(listing.longitude)),
                URLQueryItem(name: "suburb", value: listing.address.suburb),
                URLQueryItem(name: "state", value: listing.address.state),
                URLQueryItem(name: "postcode", value: listing.address.postcode)
            ]
        )
        return response.providers.map { $0.toAppModel() }
    }
}

nonisolated struct FallbackPostSaleConciergeSearch: MarketplacePostSaleConciergeSearching, Sendable {
    let remote: RemotePostSaleConciergeSearch
    let local: LocalPostSaleConciergeSearch
    let configuration: MarketplaceBackendConfiguration

    nonisolated func searchProviders(
        near listing: PropertyListing,
        serviceKind: PostSaleConciergeServiceKind
    ) async throws -> [PostSaleConciergeProvider] {
        guard configuration.mode == .remotePreferred else {
            return try await local.searchProviders(near: listing, serviceKind: serviceKind)
        }

        do {
            let remoteResults = try await remote.searchProviders(near: listing, serviceKind: serviceKind)
            if remoteResults.isEmpty {
                return try await local.searchProviders(near: listing, serviceKind: serviceKind)
            }
            return remoteResults
        } catch let error as MarketplaceHTTPError where error.canFallbackToLocal {
            return try await local.searchProviders(near: listing, serviceKind: serviceKind)
        }
    }
}

nonisolated struct FallbackLegalProfessionalSearch: MarketplaceLegalProfessionalSearching, Sendable {
    let remote: RemoteLegalProfessionalSearch
    let local: LocalLegalProfessionalSearch
    let configuration: MarketplaceBackendConfiguration

    nonisolated func searchProfessionals(near listing: PropertyListing) async throws -> [LegalProfessional] {
        guard configuration.mode == .remotePreferred else {
            return try await local.searchProfessionals(near: listing)
        }

        do {
            let remoteResults = try await remote.searchProfessionals(near: listing)
            if remoteResults.isEmpty {
                return try await local.searchProfessionals(near: listing)
            }
            return remoteResults
        } catch let error as MarketplaceHTTPError where error.canFallbackToLocal {
            return try await local.searchProfessionals(near: listing)
        }
    }
}

protocol MarketplaceSaleSyncing: Sendable {
    nonisolated func fetchSales(for userID: UUID) async throws -> [OfferRecord]
    nonisolated func fetchSale(for listingID: UUID) async throws -> OfferRecord?
    nonisolated func fetchLegalWorkspace(inviteCode: String) async throws -> (listing: PropertyListing, offer: OfferRecord, invite: SaleWorkspaceInvite)?
    nonisolated func upsertSale(_ offer: OfferRecord) async throws -> OfferRecord
}

protocol MarketplaceListingSyncing: Sendable {
    nonisolated func fetchListings() async throws -> [PropertyListing]
    nonisolated func fetchListing(id: UUID) async throws -> PropertyListing?
    nonisolated func upsertListing(_ listing: PropertyListing) async throws -> PropertyListing
}

protocol MarketplaceUserStateSyncing: Sendable {
    nonisolated func fetchState(for userID: UUID) async throws -> UserMarketplaceState
    nonisolated func upsertState(_ state: UserMarketplaceState) async throws -> UserMarketplaceState
}

protocol MarketplaceTaskSnapshotStateSyncing: Sendable {
    nonisolated func fetchState(for viewerID: String) async throws -> SaleTaskSnapshotViewerState
    nonisolated func upsertState(_ state: SaleTaskSnapshotViewerState) async throws -> SaleTaskSnapshotViewerState
}

nonisolated struct DisabledUserStateSync: MarketplaceUserStateSyncing, Sendable {
    nonisolated func fetchState(for userID: UUID) async throws -> UserMarketplaceState {
        MarketplaceSeed.marketplaceState(for: userID)
    }

    nonisolated func upsertState(_ state: UserMarketplaceState) async throws -> UserMarketplaceState {
        state
    }
}

nonisolated struct DisabledTaskSnapshotStateSync: MarketplaceTaskSnapshotStateSyncing, Sendable {
    nonisolated func fetchState(for viewerID: String) async throws -> SaleTaskSnapshotViewerState {
        SaleTaskSnapshotViewerState(viewerID: viewerID, seenUrgentSnapshotKeysByMessageID: [:])
    }

    nonisolated func upsertState(_ state: SaleTaskSnapshotViewerState) async throws -> SaleTaskSnapshotViewerState {
        state
    }
}

nonisolated struct DisabledListingSync: MarketplaceListingSyncing, Sendable {
    nonisolated func fetchListings() async throws -> [PropertyListing] {
        []
    }

    nonisolated func fetchListing(id _: UUID) async throws -> PropertyListing? {
        nil
    }

    nonisolated func upsertListing(_ listing: PropertyListing) async throws -> PropertyListing {
        listing
    }
}

nonisolated struct RemoteListingSync: MarketplaceListingSyncing, Sendable {
    let client: MarketplaceHTTPClient

    nonisolated func fetchListings() async throws -> [PropertyListing] {
        let response: MarketplaceWireListingListEnvelope = try await client.get(path: "v1/listings")
        return response.listings
    }

    nonisolated func fetchListing(id: UUID) async throws -> PropertyListing? {
        let response: MarketplaceWireListingEnvelope = try await client.get(path: "v1/listings/\(id.uuidString)")
        return response.listing
    }

    nonisolated func upsertListing(_ listing: PropertyListing) async throws -> PropertyListing {
        let response: MarketplaceWireListingEnvelope = try await client.put(
            path: "v1/listings/\(listing.id.uuidString)",
            body: MarketplaceWireListingEnvelope(listing: listing)
        )
        return response.listing ?? listing
    }
}

nonisolated struct RemoteUserStateSync: MarketplaceUserStateSyncing, Sendable {
    let client: MarketplaceHTTPClient

    nonisolated func fetchState(for userID: UUID) async throws -> UserMarketplaceState {
        let response: MarketplaceWireUserMarketplaceStateEnvelope = try await client.get(
            path: "v1/marketplace-state/\(userID.uuidString)"
        )
        return response.state
    }

    nonisolated func upsertState(_ state: UserMarketplaceState) async throws -> UserMarketplaceState {
        let response: MarketplaceWireUserMarketplaceStateEnvelope = try await client.put(
            path: "v1/marketplace-state/\(state.userID.uuidString)",
            body: MarketplaceWireUserMarketplaceStateEnvelope(state: state)
        )
        return response.state
    }
}

nonisolated struct RemoteTaskSnapshotStateSync: MarketplaceTaskSnapshotStateSyncing, Sendable {
    let client: MarketplaceHTTPClient

    nonisolated func fetchState(for viewerID: String) async throws -> SaleTaskSnapshotViewerState {
        let response: MarketplaceWireSaleTaskSnapshotViewerStateEnvelope = try await client.get(
            path: "v1/task-snapshot-state/\(viewerID)"
        )
        return response.state
    }

    nonisolated func upsertState(_ state: SaleTaskSnapshotViewerState) async throws -> SaleTaskSnapshotViewerState {
        let response: MarketplaceWireSaleTaskSnapshotViewerStateEnvelope = try await client.put(
            path: "v1/task-snapshot-state/\(state.viewerID)",
            body: MarketplaceWireSaleTaskSnapshotViewerStateEnvelope(state: state)
        )
        return response.state
    }
}

nonisolated struct DisabledSaleSync: MarketplaceSaleSyncing, Sendable {
    nonisolated func fetchSales(for _: UUID) async throws -> [OfferRecord] {
        []
    }

    nonisolated func fetchSale(for _: UUID) async throws -> OfferRecord? {
        nil
    }

    nonisolated func fetchLegalWorkspace(inviteCode _: String) async throws -> (listing: PropertyListing, offer: OfferRecord, invite: SaleWorkspaceInvite)? {
        nil
    }

    nonisolated func upsertSale(_ offer: OfferRecord) async throws -> OfferRecord {
        offer
    }
}

nonisolated struct RemoteSaleSync: MarketplaceSaleSyncing, Sendable {
    let client: MarketplaceHTTPClient

    nonisolated func fetchSales(for userID: UUID) async throws -> [OfferRecord] {
        let response: MarketplaceWireSaleListEnvelope = try await client.get(
            path: "v1/sales",
            queryItems: [URLQueryItem(name: "userId", value: userID.uuidString)]
        )
        return response.sales.map { $0.toAppModel() }
    }

    nonisolated func fetchSale(for listingID: UUID) async throws -> OfferRecord? {
        let response: MarketplaceWireSaleEnvelope = try await client.get(
            path: "v1/sales/by-listing/\(listingID.uuidString)"
        )
        return response.sale?.toAppModel()
    }

    nonisolated func fetchLegalWorkspace(inviteCode: String) async throws -> (listing: PropertyListing, offer: OfferRecord, invite: SaleWorkspaceInvite)? {
        let response: MarketplaceWireLegalWorkspaceEnvelope = try await client.get(
            path: "v1/legal-workspace/\(inviteCode)"
        )
        guard let listing = response.listing,
              let offer = response.sale?.toAppModel(),
              let invite = response.invite?.toAppModel() else {
            return nil
        }

        return (listing: listing, offer: offer, invite: invite)
    }

    nonisolated func upsertSale(_ offer: OfferRecord) async throws -> OfferRecord {
        let response: MarketplaceWireSaleEnvelope = try await client.put(
            path: "v1/sales/by-listing/\(offer.listingID.uuidString)",
            body: MarketplaceWireSaleEnvelope(sale: MarketplaceWireSaleRecord(offer))
        )
        return response.sale?.toAppModel() ?? offer
    }
}

nonisolated struct MarketplaceLiveServices: Sendable {
    var authService: any MarketplaceAuthServing
    var conversationSync: any MarketplaceConversationSyncing
    var listingSync: any MarketplaceListingSyncing
    var userStateSync: any MarketplaceUserStateSyncing
    var taskSnapshotStateSync: any MarketplaceTaskSnapshotStateSyncing
    var legalProfessionalSearch: any MarketplaceLegalProfessionalSearching
    var postSaleConciergeSearch: any MarketplacePostSaleConciergeSearching
    var saleSync: any MarketplaceSaleSyncing
    var configuration: MarketplaceBackendConfiguration
}

nonisolated enum MarketplaceServiceFactory {
    static func makeLiveServices(launchConfiguration: AppLaunchConfiguration) -> MarketplaceLiveServices {
        let configuration = MarketplaceBackendConfiguration.launchDefault(launchConfiguration: launchConfiguration)
        let localAuth = LocalMarketplaceAuthService()

        guard configuration.mode == .remotePreferred else {
            return MarketplaceLiveServices(
                authService: localAuth,
                conversationSync: DisabledConversationSync(),
                listingSync: DisabledListingSync(),
                userStateSync: DisabledUserStateSync(),
                taskSnapshotStateSync: DisabledTaskSnapshotStateSync(),
                legalProfessionalSearch: LocalLegalProfessionalSearch(),
                postSaleConciergeSearch: LocalPostSaleConciergeSearch(),
                saleSync: DisabledSaleSync(),
                configuration: configuration
            )
        }

        let client = MarketplaceHTTPClient(configuration: configuration)
        return MarketplaceLiveServices(
            authService: FallbackMarketplaceAuthService(
                remote: RemoteMarketplaceAuthService(client: client),
                local: localAuth,
                configuration: configuration
            ),
            conversationSync: RemoteConversationSync(client: client),
            listingSync: RemoteListingSync(client: client),
            userStateSync: RemoteUserStateSync(client: client),
            taskSnapshotStateSync: RemoteTaskSnapshotStateSync(client: client),
            legalProfessionalSearch: FallbackLegalProfessionalSearch(
                remote: RemoteLegalProfessionalSearch(client: client),
                local: LocalLegalProfessionalSearch(),
                configuration: configuration
            ),
            postSaleConciergeSearch: FallbackPostSaleConciergeSearch(
                remote: RemotePostSaleConciergeSearch(client: client),
                local: LocalPostSaleConciergeSearch(),
                configuration: configuration
            ),
            saleSync: RemoteSaleSync(client: client),
            configuration: configuration
        )
    }
}
