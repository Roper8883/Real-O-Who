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

    init(_ user: UserProfile) {
        id = user.id
        name = user.name
        role = user.role
        suburb = user.suburb
        headline = user.headline
        verificationNote = user.verificationNote
        buyerStage = user.buyerStage
    }

    nonisolated func toAppModel() -> UserProfile {
        UserProfile(
            id: id,
            name: name,
            role: role,
            suburb: suburb,
            headline: headline,
            verificationNote: verificationNote,
            buyerStage: buyerStage
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
    var buyerLegalSelection: MarketplaceWireLegalSelection?
    var sellerLegalSelection: MarketplaceWireLegalSelection?
    var contractPacket: MarketplaceWireContractPacket?
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
        buyerLegalSelection = offer.buyerLegalSelection.map(MarketplaceWireLegalSelection.init)
        sellerLegalSelection = offer.sellerLegalSelection.map(MarketplaceWireLegalSelection.init)
        contractPacket = offer.contractPacket.map(MarketplaceWireContractPacket.init)
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
            buyerLegalSelection: buyerLegalSelection?.toAppModel(),
            sellerLegalSelection: sellerLegalSelection?.toAppModel(),
            contractPacket: contractPacket?.toAppModel(),
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

nonisolated struct LocalLegalProfessionalSearch: MarketplaceLegalProfessionalSearching, Sendable {
    private static let fallbackProfessionals: [LegalProfessional] = [
        LegalProfessional(
            id: "local-brisbane-conveyancing-group",
            name: "Brisbane Conveyancing Group",
            specialties: ["Conveyancing", "Contract review"],
            address: "Level 8, 123 Adelaide Street, Brisbane City QLD 4000",
            suburb: "Brisbane City",
            phoneNumber: "(07) 3123 4501",
            websiteURL: URL(string: "https://example.com/brisbane-conveyancing-group"),
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
            websiteURL: URL(string: "https://example.com/rivercity-property-law"),
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
            websiteURL: URL(string: "https://example.com/west-end-settlement"),
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
            websiteURL: URL(string: "https://example.com/bulimba-legal"),
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
            websiteURL: URL(string: "https://example.com/logan-private-sale-law"),
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
            websiteURL: URL(string: "https://example.com/gold-coast-conveyancing"),
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
            saleSync: RemoteSaleSync(client: client),
            configuration: configuration
        )
    }
}
