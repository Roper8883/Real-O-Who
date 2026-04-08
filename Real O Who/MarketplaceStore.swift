import Combine
import Foundation

@MainActor
final class MarketplaceStore: ObservableObject {
    @Published private(set) var users: [UserProfile] = MarketplaceSeed.users
    @Published private(set) var listings: [PropertyListing] = MarketplaceSeed.listings()
    @Published private(set) var savedSearches: [SavedSearch] = MarketplaceSeed.savedSearches
    @Published private(set) var favoriteListingIDs: Set<UUID> = []
    @Published private(set) var plannedInspectionIDs: Set<UUID> = MarketplaceSeed.plannedInspectionIDs
    @Published private(set) var offers: [OfferRecord] = []
    @Published var currentUserID: UUID = MarketplaceSeed.buyerOliviaID

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let fileManager: FileManager
    private let fileURL: URL
    private let isEphemeral: Bool

    init(
        fileManager: FileManager = .default,
        launchConfiguration: AppLaunchConfiguration? = nil
    ) {
        let launchConfiguration = launchConfiguration ?? .shared

        self.fileManager = fileManager
        self.isEphemeral = launchConfiguration.isScreenshotMode

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

        if favoriteListingIDs.isEmpty {
            favoriteListingIDs = [
                MarketplaceSeed.listings().first?.id,
                MarketplaceSeed.listings().last?.id
            ]
            .compactMap { $0 }
            .reduce(into: Set<UUID>()) { $0.insert($1) }
        }
    }

    var currentUser: UserProfile {
        users.first(where: { $0.id == currentUserID }) ?? users[0]
    }

    var buyers: [UserProfile] {
        users.filter { $0.role == .buyer }
    }

    var sellers: [UserProfile] {
        users.filter { $0.role == .seller }
    }

    var activeListings: [PropertyListing] {
        listings.filter { $0.status == .active }
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

    func user(id: UUID) -> UserProfile? {
        users.first { $0.id == id }
    }

    func listing(id: UUID) -> PropertyListing? {
        listings.first { $0.id == id }
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
        persist()
    }

    func toggleFavorite(listingID: UUID) {
        if favoriteListingIDs.contains(listingID) {
            favoriteListingIDs.remove(listingID)
        } else {
            favoriteListingIDs.insert(listingID)
        }

        persist()
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
    }

    func toggleSavedSearchAlerts(id: UUID) {
        guard let index = savedSearches.firstIndex(where: { $0.id == id }) else { return }
        savedSearches[index].alertsEnabled.toggle()
        persist()
    }

    @discardableResult
    func submitOffer(
        listingID: UUID,
        buyerID: UUID,
        amount: Int,
        conditions: String
    ) -> OfferRecord? {
        guard let listingIndex = listings.firstIndex(where: { $0.id == listingID }),
              let listing = listings[safe: listingIndex],
              let seller = user(id: listing.sellerID),
              amount > 0 else {
            return nil
        }

        let record = OfferRecord(
            id: UUID(),
            listingID: listing.id,
            buyerID: buyerID,
            sellerID: seller.id,
            amount: amount,
            conditions: conditions.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: .now,
            status: .underOffer
        )

        offers.insert(record, at: 0)
        listings[listingIndex].status = .underOffer
        listings[listingIndex].updatedAt = .now
        persist()
        return record
    }

    func createListing(from draft: ListingDraft, sellerID: UUID) {
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
            palette: .ocean,
            latitude: draft.latitude,
            longitude: draft.longitude,
            isFeatured: false,
            publishedAt: .now,
            updatedAt: .now
        )

        listings.insert(listing, at: 0)
        persist()
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
            listings = snapshot.listings
            savedSearches = snapshot.savedSearches
            favoriteListingIDs = snapshot.favoriteListingIDs
            plannedInspectionIDs = snapshot.plannedInspectionIDs
            offers = snapshot.offers
            currentUserID = snapshot.currentUserID
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

            let snapshot = MarketplaceSnapshot(
                users: users,
                listings: listings,
                savedSearches: savedSearches,
                favoriteListingIDs: favoriteListingIDs,
                plannedInspectionIDs: plannedInspectionIDs,
                offers: offers,
                currentUserID: currentUserID
            )

            let data = try encoder.encode(snapshot)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            assertionFailure("Failed to persist marketplace state: \(error.localizedDescription)")
        }
    }
}

struct SellerDashboardStats {
    var activeListings: Int
    var draftListings: Int
    var totalOffers: Int
    var averageDemandScore: Int
}

private struct MarketplaceSnapshot: Codable {
    var users: [UserProfile]
    var listings: [PropertyListing]
    var savedSearches: [SavedSearch]
    var favoriteListingIDs: Set<UUID>
    var plannedInspectionIDs: Set<UUID>
    var offers: [OfferRecord]
    var currentUserID: UUID
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
