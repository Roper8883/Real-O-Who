import Foundation

enum UserRole: String, CaseIterable, Codable, Identifiable {
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

enum PropertyType: String, CaseIterable, Codable, Identifiable {
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

enum ListingStatus: String, CaseIterable, Codable, Identifiable {
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

enum ListingSortOrder: String, CaseIterable, Identifiable {
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

enum BuyerStage: String, Codable {
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

enum ListingPalette: String, Codable {
    case ocean
    case sand
    case gumleaf
    case dusk
}

struct UserProfile: Identifiable, Codable, Hashable {
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

struct PropertyAddress: Codable, Hashable {
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

struct InspectionSlot: Identifiable, Codable, Hashable {
    let id: UUID
    var startsAt: Date
    var endsAt: Date
    var note: String
}

struct ComparableSale: Identifiable, Codable, Hashable {
    let id: UUID
    var address: String
    var soldPrice: Int
    var soldAt: Date
    var bedrooms: Int
}

struct SchoolInsight: Codable, Hashable {
    var catchmentName: String
    var walkMinutes: Int
    var score: Int
}

struct MarketPulse: Codable, Hashable {
    var valueEstimateLow: Int
    var valueEstimateHigh: Int
    var suburbMedian: Int
    var buyerDemandScore: Int
    var averageDaysOnMarket: Int
    var schoolInsight: SchoolInsight
}

struct PropertyListing: Identifiable, Codable, Hashable {
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

struct SavedSearch: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var suburb: String
    var minimumPrice: Int
    var maximumPrice: Int
    var minimumBedrooms: Int
    var propertyTypes: [PropertyType]
    var alertsEnabled: Bool
}

struct OfferRecord: Identifiable, Codable, Hashable {
    let id: UUID
    var listingID: UUID
    var buyerID: UUID
    var sellerID: UUID
    var amount: Int
    var conditions: String
    var createdAt: Date
    var status: ListingStatus
}

struct ListingDraft {
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

enum MarketplaceSeed {
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
}
