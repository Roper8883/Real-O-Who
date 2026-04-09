import Combine
import CryptoKit
import Foundation
import Security

@MainActor
final class EncryptedMessagingService: ObservableObject {
    @Published private(set) var conversations: [EncryptedConversation] = []

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let fileManager: FileManager
    private let fileURL: URL
    private let isEphemeral: Bool
    private let keychain = MessagingKeychain()
    private let remoteSync: any MarketplaceConversationSyncing

    init(
        fileManager: FileManager = .default,
        launchConfiguration: AppLaunchConfiguration? = nil,
        remoteSync: (any MarketplaceConversationSyncing)? = nil
    ) {
        let launchConfiguration = launchConfiguration ?? .shared

        self.fileManager = fileManager
        self.isEphemeral = launchConfiguration.isScreenshotMode
        self.remoteSync = remoteSync ?? DisabledConversationSync()

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
        fileURL = directory.appendingPathComponent("conversations.bin")

        if isEphemeral {
            conversations = EncryptedConversation.seedThreads
        } else {
            load()
        }
    }

    func activateSession(for userID: UUID) async {
        guard !isEphemeral else { return }

        do {
            let threads = try await remoteSync.fetchThreads(for: userID)
            mergeRemoteThreads(threads)
        } catch {
            return
        }
    }

    func threads(for userID: UUID) -> [EncryptedConversation] {
        conversations
            .filter { $0.participantIDs.contains(userID) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func thread(id: UUID) -> EncryptedConversation? {
        conversations.first { $0.id == id }
    }

    func ensureConversation(
        listing: PropertyListing,
        buyer: UserProfile,
        seller: UserProfile
    ) -> EncryptedConversation {
        if let existing = conversations.first(where: {
            $0.listingID == listing.id &&
            Set($0.participantIDs) == Set([buyer.id, seller.id])
        }) {
            return existing
        }

        let thread = EncryptedConversation(
            id: UUID(),
            listingID: listing.id,
            participantIDs: [buyer.id, seller.id],
            encryptionLabel: "AES-256-GCM local vault",
            updatedAt: .now,
            messages: [
                EncryptedMessage(
                    id: UUID(),
                    senderID: seller.id,
                    sentAt: .now,
                    body: "Secure private channel opened for \(listing.title). Ask about inspections, contracts, or terms here.",
                    isSystem: true,
                    saleTaskTarget: nil
                )
            ]
        )

        conversations.insert(thread, at: 0)
        persist()
        syncConversationInBackground(thread)
        return thread
    }

    @discardableResult
    func sendMessage(
        listing: PropertyListing,
        from sender: UserProfile,
        to recipient: UserProfile,
        body: String,
        isSystem: Bool = false,
        saleTaskTarget: SaleReminderNavigationTarget? = nil
    ) -> EncryptedConversation? {
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBody.isEmpty || isSystem else { return nil }

        let thread = ensureConversation(listing: listing, buyer: sender.role == .buyer ? sender : recipient, seller: sender.role == .seller ? sender : recipient)
        guard let index = conversations.firstIndex(where: { $0.id == thread.id }) else { return nil }

        conversations[index].messages.append(
            EncryptedMessage(
                id: UUID(),
                senderID: sender.id,
                sentAt: .now,
                body: trimmedBody,
                isSystem: isSystem,
                saleTaskTarget: saleTaskTarget
            )
        )
        conversations[index].updatedAt = .now
        sortThreads()
        persist()
        let updatedThread = conversations.first(where: { $0.id == thread.id })
        if let updatedThread {
            syncConversationInBackground(updatedThread)
        }
        return updatedThread
    }

    func sendOfferSummary(
        listing: PropertyListing,
        buyer: UserProfile,
        seller: UserProfile,
        amount: Int,
        conditions: String
    ) {
        let summary = """
        Offer submitted: \(Currency.aud.string(from: NSNumber(value: amount)) ?? "$\(amount)")
        \(conditions.isEmpty ? "No extra conditions supplied." : conditions)
        """

        _ = sendMessage(
            listing: listing,
            from: buyer,
            to: seller,
            body: summary,
            isSystem: true
        )
    }

    func sendContractPacket(
        listing: PropertyListing,
        offerID: UUID,
        buyer: UserProfile,
        seller: UserProfile,
        packet: ContractPacket,
        triggeredBy sender: UserProfile
    ) {
        let recipient = sender.id == buyer.id ? seller : buyer
        let summary = """
        Contract packet sent to both parties.
        Buyer legal representative: \(packet.buyerRepresentative.name) (\(legalContactLine(for: packet.buyerRepresentative)))
        Seller legal representative: \(packet.sellerRepresentative.name) (\(legalContactLine(for: packet.sellerRepresentative)))
        \(packet.summary)
        """

        _ = sendMessage(
            listing: listing,
            from: sender,
            to: recipient,
            body: summary,
            isSystem: true,
            saleTaskTarget: .saleTask(
                listingID: listing.id,
                offerID: offerID,
                checklistItemID: "contract-packet"
            )
        )
    }

    private func sortThreads() {
        conversations.sort { $0.updatedAt > $1.updatedAt }
    }

    private func mergeRemoteThreads(_ remoteThreads: [EncryptedConversation]) {
        guard !remoteThreads.isEmpty else { return }

        for remoteThread in remoteThreads {
            if let index = conversations.firstIndex(where: { $0.id == remoteThread.id }) {
                conversations[index] = remoteThread
            } else {
                conversations.append(remoteThread)
            }
        }

        sortThreads()
        persist()
    }

    private func syncConversationInBackground(_ thread: EncryptedConversation) {
        guard !isEphemeral else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                let syncedThread = try await remoteSync.upsertConversation(thread)
                self.mergeRemoteThreads([syncedThread])
            } catch {
                return
            }
        }
    }

    private func load() {
        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )

            guard fileManager.fileExists(atPath: fileURL.path) else { return }

            let encryptedData = try Data(contentsOf: fileURL)
            let key = try keychain.loadOrCreateKey()
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decrypted = try AES.GCM.open(sealedBox, using: key)
            let snapshot = try decoder.decode(ConversationSnapshot.self, from: decrypted)
            conversations = snapshot.conversations
            sortThreads()
        } catch {
            assertionFailure("Failed to load encrypted conversations: \(error.localizedDescription)")
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

            let snapshot = ConversationSnapshot(conversations: conversations)
            let plaintext = try encoder.encode(snapshot)
            let key = try keychain.loadOrCreateKey()
            let sealed = try AES.GCM.seal(plaintext, using: key)

            guard let combined = sealed.combined else {
                throw NSError(domain: "EncryptedMessagingService", code: 1)
            }

            try combined.write(to: fileURL, options: [.atomic])
        } catch {
            assertionFailure("Failed to persist encrypted conversations: \(error.localizedDescription)")
        }
    }

    private func legalContactLine(for professional: LegalProfessional) -> String {
        if let phoneNumber = professional.phoneNumber,
           !phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return phoneNumber
        }

        if let websiteURL = professional.websiteURL {
            return websiteURL.absoluteString
        }

        return professional.primarySpecialty
    }
}

struct EncryptedConversation: Identifiable, Codable, Hashable {
    let id: UUID
    var listingID: UUID
    var participantIDs: [UUID]
    var encryptionLabel: String
    var updatedAt: Date
    var messages: [EncryptedMessage]

    var lastMessagePreview: String {
        messages.last?.body ?? "No messages yet"
    }

    static let seedThreads: [EncryptedConversation] = [
        EncryptedConversation(
            id: UUID(uuidString: "ED43B85D-4F12-44D2-80DB-7D5879D33001") ?? UUID(),
            listingID: UUID(uuidString: "DAA3A4D1-0FE6-4FD7-8A81-68D7E1971001") ?? UUID(),
            participantIDs: [
                MarketplaceSeed.buyerOliviaID,
                MarketplaceSeed.sellerAvaID
            ],
            encryptionLabel: "AES-256-GCM local vault",
            updatedAt: .now.addingTimeInterval(-1_200),
            messages: [
                EncryptedMessage(
                    id: UUID(),
                    senderID: MarketplaceSeed.sellerAvaID,
                    sentAt: .now.addingTimeInterval(-7_200),
                    body: "Secure private channel opened for Renovated Queenslander with pool and studio.",
                    isSystem: true,
                    saleTaskTarget: nil
                ),
                EncryptedMessage(
                    id: UUID(),
                    senderID: MarketplaceSeed.buyerOliviaID,
                    sentAt: .now.addingTimeInterval(-3_600),
                    body: "Hi Ava, can you confirm whether the studio has its own bathroom?",
                    isSystem: false,
                    saleTaskTarget: nil
                ),
                EncryptedMessage(
                    id: UUID(),
                    senderID: MarketplaceSeed.sellerAvaID,
                    sentAt: .now.addingTimeInterval(-1_200),
                    body: "Yes, it has a shower and powder room, and I can show you during Saturday's inspection.",
                    isSystem: false,
                    saleTaskTarget: nil
                )
            ]
        )
    ]
}

struct EncryptedMessage: Identifiable, Codable, Hashable {
    let id: UUID
    var senderID: UUID
    var sentAt: Date
    var body: String
    var isSystem: Bool
    var saleTaskTarget: SaleReminderNavigationTarget?
}

private struct ConversationSnapshot: Codable {
    var conversations: [EncryptedConversation]
}

private struct MessagingKeychain {
    private let service = "RealOWhoMarketplace"
    private let account = "EncryptedConversationMasterKey"

    func loadOrCreateKey() throws -> SymmetricKey {
        if let existing = try load() {
            return SymmetricKey(data: existing)
        }

        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data(Array($0)) }
        try save(keyData)
        return key
    }

    private func load() throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            return item as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    private func save(_ data: Data) throws {
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }
}

enum Currency {
    static let aud: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "AUD"
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}
