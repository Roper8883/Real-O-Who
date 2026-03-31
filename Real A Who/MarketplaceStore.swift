import Combine
import Foundation

@MainActor
final class MarketplaceStore: ObservableObject {
    @Published private(set) var listings: [PropertyListing]
    @Published private(set) var savedListingIDs: Set<UUID>
    @Published private(set) var conversations: [ConversationThread]
    @Published private(set) var offers: [OfferRecord]
    @Published private(set) var inspections: [InspectionRequest]
    @Published private(set) var sellerTasks: [SellerTask]

    private let fileManager: FileManager
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.listings = MarketplaceSeed.defaultListings
        self.savedListingIDs = MarketplaceSeed.defaultSavedListingIDs
        self.conversations = MarketplaceSeed.defaultConversations
        self.offers = MarketplaceSeed.defaultOffers
        self.inspections = MarketplaceSeed.defaultInspections
        self.sellerTasks = MarketplaceSeed.defaultTasks

        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        let supportDirectory = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fileManager.temporaryDirectory

        let directory = supportDirectory.appendingPathComponent("RealAWhoMarketplace", isDirectory: true)
        fileURL = directory.appendingPathComponent("marketplace_state.json")

        load()
    }

    var featuredListings: [PropertyListing] {
        listings.filter { $0.status != .sold }
    }

    var savedListings: [PropertyListing] {
        listings.filter { savedListingIDs.contains($0.id) }
    }

    var unreadMessageCount: Int {
        conversations.reduce(0) { $0 + $1.unreadCount }
    }

    var activeListingCount: Int {
        listings.filter { $0.status == .active || $0.status == .underOffer || $0.status == .acceptedInPrinciple }.count
    }

    var sellerOfferCount: Int {
        offers.count
    }

    var upcomingInspectionCount: Int {
        inspections.count
    }

    func listing(id: UUID) -> PropertyListing? {
        listings.first { $0.id == id }
    }

    func thread(id: UUID) -> ConversationThread? {
        conversations.first { $0.id == id }
    }

    func searchListings(query: String, stateFilter: AustralianState?) -> [PropertyListing] {
        listings.filter { listing in
            let matchesState = stateFilter == nil || listing.state == stateFilter
            guard matchesState else { return false }

            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return true }

            let haystack = [
                listing.heroTitle,
                listing.addressLine,
                listing.suburb,
                listing.postcode,
                listing.priceGuide,
                listing.headline,
                listing.features.joined(separator: " "),
                listing.neighbourhoodHighlights.joined(separator: " ")
            ].joined(separator: " ").lowercased()

            return haystack.contains(trimmed.lowercased())
        }
    }

    func isSaved(_ listingID: UUID) -> Bool {
        savedListingIDs.contains(listingID)
    }

    func toggleSaved(listingID: UUID) {
        if savedListingIDs.contains(listingID) {
            savedListingIDs.remove(listingID)
        } else {
            savedListingIDs.insert(listingID)
        }

        persist()
    }

    func sendMessage(threadID: UUID, text: String) {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        guard let index = conversations.firstIndex(where: { $0.id == threadID }) else { return }

        conversations[index].messages.append(
            ConversationMessage(
                id: UUID(),
                senderName: "You",
                senderRole: "Buyer",
                sentAt: .now,
                body: body,
                isFromCurrentUser: true,
                isPinnedFAQ: false
            )
        )
        conversations[index].unreadCount = 0
        sortConversations()
        persist()
    }

    func startConversation(for listingID: UUID, openingMessage: String) {
        let body = openingMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        guard let listing = listing(id: listingID) else { return }

        if let existingThread = conversations.first(where: { $0.listingID == listingID }) {
            sendMessage(threadID: existingThread.id, text: body)
            return
        }

        let newThread = ConversationThread(
            id: UUID(),
            listingID: listingID,
            listingTitle: listing.heroTitle,
            participantName: listing.sellerName,
            unreadCount: 0,
            messages: [
                ConversationMessage(
                    id: UUID(),
                    senderName: "You",
                    senderRole: "Buyer",
                    sentAt: .now,
                    body: body,
                    isFromCurrentUser: true,
                    isPinnedFAQ: false
                )
            ]
        )

        conversations.insert(newThread, at: 0)
        persist()
    }

    func submitOffer(
        listingID: UUID,
        amount: Int,
        depositIntention: String,
        settlementDays: Int,
        subjectToFinance: Bool,
        subjectToBuildingInspection: Bool,
        subjectToPestInspection: Bool,
        subjectToSaleOfHome: Bool,
        buyerMessage: String
    ) {
        guard let listing = listing(id: listingID) else { return }

        offers.insert(
            OfferRecord(
                id: UUID(),
                listingID: listingID,
                propertyTitle: listing.heroTitle,
                buyerName: "You",
                amount: amount,
                depositIntention: depositIntention.trimmingCharacters(in: .whitespacesAndNewlines),
                settlementDays: settlementDays,
                subjectToFinance: subjectToFinance,
                subjectToBuildingInspection: subjectToBuildingInspection,
                subjectToPestInspection: subjectToPestInspection,
                subjectToSaleOfHome: subjectToSaleOfHome,
                buyerMessage: buyerMessage.trimmingCharacters(in: .whitespacesAndNewlines),
                submittedAt: .now,
                status: .submitted
            ),
            at: 0
        )

        sellerTasks.insert(
            SellerTask(
                id: UUID(),
                listingID: listingID,
                title: "Review new private offer",
                detail: "A buyer submitted a non-binding offer for \(listing.heroTitle). Route it to contract only after legal review.",
                dueLabel: "Now",
                isBlocking: true
            ),
            at: 0
        )

        persist()
    }

    func requestInspection(listingID: UUID, slotID: UUID, attendees: Int) {
        guard let listingIndex = listings.firstIndex(where: { $0.id == listingID }) else { return }
        guard let slotIndex = listings[listingIndex].inspectionSlots.firstIndex(where: { $0.id == slotID }) else { return }

        let slot = listings[listingIndex].inspectionSlots[slotIndex]
        listings[listingIndex].inspectionSlots[slotIndex].bookedCount += 1

        inspections.insert(
            InspectionRequest(
                id: UUID(),
                listingID: listingID,
                propertyTitle: listings[listingIndex].heroTitle,
                slotTitle: slot.title,
                requestedAt: .now,
                status: slot.isPrivateAppointment ? .requested : .confirmed,
                attendees: attendees
            ),
            at: 0
        )

        sellerTasks.insert(
            SellerTask(
                id: UUID(),
                listingID: listingID,
                title: slot.isPrivateAppointment ? "Confirm private inspection request" : "Prepare for upcoming open home",
                detail: "\(attendees) attendee\(attendees == 1 ? "" : "s") booked against \(slot.title).",
                dueLabel: "Scheduled",
                isBlocking: slot.isPrivateAppointment
            ),
            at: 0
        )

        persist()
    }

    func markConversationRead(threadID: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == threadID }) else { return }
        conversations[index].unreadCount = 0
        persist()
    }

    private func sortConversations() {
        conversations.sort { $0.lastUpdatedAt > $1.lastUpdatedAt }
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
            listings = snapshot.listings
            savedListingIDs = Set(snapshot.savedListingIDs)
            conversations = snapshot.conversations
            offers = snapshot.offers
            inspections = snapshot.inspections
            sellerTasks = snapshot.sellerTasks
            sortConversations()
        } catch {
            assertionFailure("Failed to load marketplace state: \(error.localizedDescription)")
        }
    }

    private func persist() {
        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )

            let snapshot = MarketplaceSnapshot(
                listings: listings,
                savedListingIDs: Array(savedListingIDs),
                conversations: conversations,
                offers: offers,
                inspections: inspections,
                sellerTasks: sellerTasks
            )

            let data = try encoder.encode(snapshot)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            assertionFailure("Failed to save marketplace state: \(error.localizedDescription)")
        }
    }
}

private struct MarketplaceSnapshot: Codable {
    var listings: [PropertyListing]
    var savedListingIDs: [UUID]
    var conversations: [ConversationThread]
    var offers: [OfferRecord]
    var inspections: [InspectionRequest]
    var sellerTasks: [SellerTask]
}
