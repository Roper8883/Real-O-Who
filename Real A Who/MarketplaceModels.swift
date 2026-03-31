import Foundation

enum AustralianState: String, CaseIterable, Codable, Identifiable {
    case nsw = "NSW"
    case vic = "VIC"
    case qld = "QLD"
    case sa = "SA"
    case act = "ACT"
    case nt = "NT"
    case wa = "WA"
    case tas = "TAS"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nsw: return "New South Wales"
        case .vic: return "Victoria"
        case .qld: return "Queensland"
        case .sa: return "South Australia"
        case .act: return "Australian Capital Territory"
        case .nt: return "Northern Territory"
        case .wa: return "Western Australia"
        case .tas: return "Tasmania"
        }
    }

    var complianceSummary: String {
        switch self {
        case .nsw:
            return "Contract of sale prepared before advertising and cooling-off tracked after exchange."
        case .vic:
            return "Section 32 ready for buyers before contract signing, with conditional offer support."
        case .qld:
            return "Seller disclosure bundle and delivery proof required before signing."
        case .sa:
            return "Form 1 service date and amendment workflow tracked for private treaty sales."
        case .act:
            return "Draft contract and seller-provided building and pest reporting supported up front."
        case .nt:
            return "Approved form placeholder plus non-auction cooling-off workflow."
        case .wa:
            return "No default cooling-off, so finance and inspection conditions are made prominent."
        case .tas:
            return "Buyer-beware prompts stay prominent and due diligence reminders are explicit."
        }
    }
}

enum PropertyType: String, CaseIterable, Codable, Identifiable {
    case house = "House"
    case townhouse = "Townhouse"
    case apartment = "Apartment / Unit"
    case land = "Land"
    case acreage = "Acreage / Lifestyle"

    var id: String { rawValue }
}

enum ListingStatus: String, Codable, Identifiable {
    case active = "Active"
    case underOffer = "Under Offer"
    case acceptedInPrinciple = "Accepted in Principle"
    case contractRequested = "Contract Requested"
    case exchanged = "Exchanged"
    case sold = "Sold"

    var id: String { rawValue }
}

enum DisclosureStatus: String, Codable, Identifiable {
    case ready = "Ready"
    case needsReview = "Needs review"
    case waitingOnSeller = "Waiting on seller"
    case recommended = "Recommended"

    var id: String { rawValue }
}

enum DataProvenance: String, Codable, Identifiable {
    case sellerSupplied = "Seller supplied"
    case publicRecord = "Public record"
    case licensedData = "Licensed data"
    case estimated = "Estimated"
    case unavailable = "Unavailable"

    var id: String { rawValue }
}

struct ListingDocument: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var statusText: String
    var provenance: DataProvenance
    var isRequired: Bool
}

struct InspectionSlot: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var startsAt: Date
    var capacity: Int
    var bookedCount: Int
    var isPrivateAppointment: Bool
}

struct PropertyListing: Identifiable, Codable, Hashable {
    let id: UUID
    var slug: String
    var heroTitle: String
    var addressLine: String
    var suburb: String
    var postcode: String
    var state: AustralianState
    var propertyType: PropertyType
    var priceGuide: String
    var headline: String
    var summary: String
    var bedrooms: Int
    var bathrooms: Int
    var parking: Int
    var landSize: String
    var buildingSize: String
    var sellerName: String
    var sellerVerified: Bool
    var responseRate: Int
    var averageResponseTime: String
    var legalStatusText: String
    var disclosureStatus: DisclosureStatus
    var saleMethod: String
    var status: ListingStatus
    var whatOwnerLoves: String
    var dueDiligencePrompt: String
    var features: [String]
    var neighbourhoodHighlights: [String]
    var documents: [ListingDocument]
    var inspectionSlots: [InspectionSlot]

    var locationLine: String {
        "\(suburb), \(state.rawValue) \(postcode)"
    }
}

struct ConversationMessage: Identifiable, Codable, Hashable {
    let id: UUID
    var senderName: String
    var senderRole: String
    var sentAt: Date
    var body: String
    var isFromCurrentUser: Bool
    var isPinnedFAQ: Bool
}

struct ConversationThread: Identifiable, Codable, Hashable {
    let id: UUID
    var listingID: UUID
    var listingTitle: String
    var participantName: String
    var unreadCount: Int
    var messages: [ConversationMessage]

    var lastMessagePreview: String {
        messages.last?.body ?? "No messages yet."
    }

    var lastUpdatedAt: Date {
        messages.last?.sentAt ?? .now
    }
}

enum OfferStatus: String, Codable, Identifiable {
    case submitted = "Submitted"
    case countered = "Countered"
    case acceptedInPrinciple = "Accepted in Principle"
    case contractRequested = "Contract Requested"
    case expired = "Expired"

    var id: String { rawValue }
}

struct OfferRecord: Identifiable, Codable, Hashable {
    let id: UUID
    var listingID: UUID
    var propertyTitle: String
    var buyerName: String
    var amount: Int
    var depositIntention: String
    var settlementDays: Int
    var subjectToFinance: Bool
    var subjectToBuildingInspection: Bool
    var subjectToPestInspection: Bool
    var subjectToSaleOfHome: Bool
    var buyerMessage: String
    var submittedAt: Date
    var status: OfferStatus
}

enum InspectionRequestStatus: String, Codable, Identifiable {
    case requested = "Requested"
    case confirmed = "Confirmed"
    case rescheduled = "Rescheduled"

    var id: String { rawValue }
}

struct InspectionRequest: Identifiable, Codable, Hashable {
    let id: UUID
    var listingID: UUID
    var propertyTitle: String
    var slotTitle: String
    var requestedAt: Date
    var status: InspectionRequestStatus
    var attendees: Int
}

struct SellerTask: Identifiable, Codable, Hashable {
    let id: UUID
    var listingID: UUID?
    var title: String
    var detail: String
    var dueLabel: String
    var isBlocking: Bool
}

enum MarketplaceSeed {
    static var defaultListings: [PropertyListing] {
        [
            PropertyListing(
                id: UUID(uuidString: "A4B1A920-9E31-4604-9F70-5E4D42A47801") ?? UUID(),
                slug: "paddington-terrace-nsw",
                heroTitle: "Renovated Paddington terrace with contract ready",
                addressLine: "34 Oxford Street",
                suburb: "Paddington",
                postcode: "2021",
                state: .nsw,
                propertyType: .house,
                priceGuide: "$2.45m",
                headline: "Private treaty sale with legal pack already prepared.",
                summary: "A light-filled terrace with three living zones, rear entertaining courtyard, and a seller who has the contract of sale ready for buyer review.",
                bedrooms: 3,
                bathrooms: 2,
                parking: 1,
                landSize: "164 sqm",
                buildingSize: "198 sqm",
                sellerName: "Harper Cole",
                sellerVerified: true,
                responseRate: 97,
                averageResponseTime: "41 mins",
                legalStatusText: "NSW contract of sale confirmed as prepared before advertising.",
                disclosureStatus: .ready,
                saleMethod: "Private treaty",
                status: .active,
                whatOwnerLoves: "Morning light in the rear kitchen, the walkability to Five Ways, and how easy inspections are to run privately with the courtyard entry.",
                dueDiligencePrompt: "Cooling-off and exchange timing vary. Buyers should review the contract and obtain independent legal advice.",
                features: ["Renovated kitchen", "Rear courtyard", "Study nook", "Ducted air", "Walk to cafes"],
                neighbourhoodHighlights: ["Oxford Street buses", "Paddington Public catchment", "Centennial Park nearby"],
                documents: [
                    ListingDocument(id: UUID(), title: "Contract of sale", statusText: "Uploaded by seller's solicitor", provenance: .sellerSupplied, isRequired: true),
                    ListingDocument(id: UUID(), title: "Pool compliance", statusText: "Not applicable", provenance: .unavailable, isRequired: false),
                    ListingDocument(id: UUID(), title: "Title search", statusText: "Current copy available", provenance: .publicRecord, isRequired: true)
                ],
                inspectionSlots: [
                    InspectionSlot(id: UUID(), title: "Open home · Sat 11:00am", startsAt: daysFromNow(3, hour: 11), capacity: 20, bookedCount: 7, isPrivateAppointment: false),
                    InspectionSlot(id: UUID(), title: "Private inspection · Tue 5:30pm", startsAt: daysFromNow(6, hour: 17), capacity: 2, bookedCount: 1, isPrivateAppointment: true)
                ]
            ),
            PropertyListing(
                id: UUID(uuidString: "A4B1A920-9E31-4604-9F70-5E4D42A47802") ?? UUID(),
                slug: "fitzroy-north-apartment-vic",
                heroTitle: "Architect apartment with Section 32 ready",
                addressLine: "12/182 Scotchmer Street",
                suburb: "Fitzroy North",
                postcode: "3068",
                state: .vic,
                propertyType: .apartment,
                priceGuide: "$845k - $895k",
                headline: "Section 32 uploaded and conditional offers supported.",
                summary: "Warehouse-style apartment with oversized balcony, storage cage, and seller transparency around body corporate fees and recent works.",
                bedrooms: 2,
                bathrooms: 2,
                parking: 1,
                landSize: "N/A",
                buildingSize: "96 sqm internal",
                sellerName: "Jules Parker",
                sellerVerified: true,
                responseRate: 93,
                averageResponseTime: "1 hr 12 mins",
                legalStatusText: "Section 32 vendor statement available before contract stage.",
                disclosureStatus: .ready,
                saleMethod: "Private treaty",
                status: .underOffer,
                whatOwnerLoves: "The north-facing light, bike paths at the door, and how buyers can review documents before inspections.",
                dueDiligencePrompt: "Conditional offers should still be reviewed by a buyer's conveyancer or lawyer.",
                features: ["North balcony", "Lift access", "Storage cage", "Split system", "Stone kitchen"],
                neighbourhoodHighlights: ["Merri Creek trails", "Tram access", "Brunswick Street cafes"],
                documents: [
                    ListingDocument(id: UUID(), title: "Section 32", statusText: "Ready for download", provenance: .sellerSupplied, isRequired: true),
                    ListingDocument(id: UUID(), title: "Owners corporation certificate", statusText: "Current financials attached", provenance: .sellerSupplied, isRequired: true),
                    ListingDocument(id: UUID(), title: "Comparable sales snapshot", statusText: "Licensed enrichment pending", provenance: .licensedData, isRequired: false)
                ],
                inspectionSlots: [
                    InspectionSlot(id: UUID(), title: "Private inspection · Thu 6:15pm", startsAt: daysFromNow(2, hour: 18), capacity: 2, bookedCount: 2, isPrivateAppointment: true)
                ]
            ),
            PropertyListing(
                id: UUID(uuidString: "A4B1A920-9E31-4604-9F70-5E4D42A47803") ?? UUID(),
                slug: "noosa-heads-pool-home-qld",
                heroTitle: "Noosa family home with pool and disclosure bundle",
                addressLine: "8 Witta Circle",
                suburb: "Noosa Heads",
                postcode: "4567",
                state: .qld,
                propertyType: .house,
                priceGuide: "Offers over $1.98m",
                headline: "Disclosure bundle issued before signing, with proof of delivery tracked.",
                summary: "Private canal-front home with updated pool fencing, integrated outdoor kitchen, and a seller using the platform's QLD disclosure workflow.",
                bedrooms: 4,
                bathrooms: 3,
                parking: 2,
                landSize: "612 sqm",
                buildingSize: "284 sqm",
                sellerName: "Amelia Grant",
                sellerVerified: true,
                responseRate: 98,
                averageResponseTime: "28 mins",
                legalStatusText: "Queensland disclosure statement ready with prescribed certificates and delivery proof.",
                disclosureStatus: .ready,
                saleMethod: "Private treaty",
                status: .active,
                whatOwnerLoves: "Sunset by the water, fast access to Hastings Street, and having every disclosure item ready before buyers ask.",
                dueDiligencePrompt: "Incomplete disclosure can affect contract rights. Buyers should still verify finance, planning, and body corporate information independently where relevant.",
                features: ["Canal frontage", "Pool", "Outdoor kitchen", "Home office", "Solar"],
                neighbourhoodHighlights: ["Noosa Main Beach access", "School run friendly", "Waterfront walking trails"],
                documents: [
                    ListingDocument(id: UUID(), title: "QLD disclosure statement", statusText: "Delivered to active buyer leads", provenance: .sellerSupplied, isRequired: true),
                    ListingDocument(id: UUID(), title: "Pool compliance certificate", statusText: "Current through 2027", provenance: .sellerSupplied, isRequired: true),
                    ListingDocument(id: UUID(), title: "Flood overlay extract", statusText: "Council copy requested", provenance: .publicRecord, isRequired: false)
                ],
                inspectionSlots: [
                    InspectionSlot(id: UUID(), title: "Open home · Sun 10:30am", startsAt: daysFromNow(4, hour: 10), capacity: 24, bookedCount: 12, isPrivateAppointment: false),
                    InspectionSlot(id: UUID(), title: "Private inspection · Mon 4:00pm", startsAt: daysFromNow(5, hour: 16), capacity: 2, bookedCount: 0, isPrivateAppointment: true)
                ]
            ),
            PropertyListing(
                id: UUID(uuidString: "A4B1A920-9E31-4604-9F70-5E4D42A47804") ?? UUID(),
                slug: "braddon-townhouse-act",
                heroTitle: "Braddon townhouse with seller-provided ACT reports",
                addressLine: "16 Torrens Street",
                suburb: "Braddon",
                postcode: "2612",
                state: .act,
                propertyType: .townhouse,
                priceGuide: "$1.18m",
                headline: "Draft contract plus building and pest reports available now.",
                summary: "Modern tri-level townhouse set up for private sale, with seller-provided reports and reimbursement metadata recorded for buyers.",
                bedrooms: 3,
                bathrooms: 2,
                parking: 2,
                landSize: "220 sqm",
                buildingSize: "171 sqm",
                sellerName: "Nina Walsh",
                sellerVerified: true,
                responseRate: 95,
                averageResponseTime: "53 mins",
                legalStatusText: "ACT draft contract and inspection reports prepared before offering for sale.",
                disclosureStatus: .ready,
                saleMethod: "Private treaty",
                status: .acceptedInPrinciple,
                whatOwnerLoves: "The separate studio space, Braddon dining nearby, and the trust buyers feel when the reports are ready from day one.",
                dueDiligencePrompt: "Buyers should still obtain their own legal advice before proceeding to exchange or reimbursement arrangements.",
                features: ["Tri-level layout", "Double garage", "Separate studio", "Energy-efficient glazing", "Courtyard"],
                neighbourhoodHighlights: ["Light rail nearby", "Braddon precinct", "Easy City access"],
                documents: [
                    ListingDocument(id: UUID(), title: "Draft contract", statusText: "Prepared by solicitor", provenance: .sellerSupplied, isRequired: true),
                    ListingDocument(id: UUID(), title: "Building report", statusText: "Seller report available", provenance: .sellerSupplied, isRequired: true),
                    ListingDocument(id: UUID(), title: "Pest report", statusText: "Seller report available", provenance: .sellerSupplied, isRequired: true)
                ],
                inspectionSlots: [
                    InspectionSlot(id: UUID(), title: "Private inspection · Wed 5:45pm", startsAt: daysFromNow(7, hour: 17), capacity: 2, bookedCount: 1, isPrivateAppointment: true)
                ]
            )
        ]
    }

    static var defaultConversations: [ConversationThread] {
        [
            ConversationThread(
                id: UUID(uuidString: "D556F561-08FE-4C44-8AA1-8EC885EE8101") ?? UUID(),
                listingID: defaultListings[0].id,
                listingTitle: defaultListings[0].heroTitle,
                participantName: defaultListings[0].sellerName,
                unreadCount: 1,
                messages: [
                    ConversationMessage(id: UUID(), senderName: defaultListings[0].sellerName, senderRole: "Owner", sentAt: minutesAgo(95), body: "Happy to share the contract pack before you inspect. Let me know if you want the title documents as well.", isFromCurrentUser: false, isPinnedFAQ: true),
                    ConversationMessage(id: UUID(), senderName: "You", senderRole: "Buyer", sentAt: minutesAgo(72), body: "Yes please. I'm mainly checking easements and any recent works approvals.", isFromCurrentUser: true, isPinnedFAQ: false),
                    ConversationMessage(id: UUID(), senderName: defaultListings[0].sellerName, senderRole: "Owner", sentAt: minutesAgo(26), body: "I've uploaded the title search and renovation approvals. The solicitor-prepared contract is ready too.", isFromCurrentUser: false, isPinnedFAQ: false)
                ]
            ),
            ConversationThread(
                id: UUID(uuidString: "D556F561-08FE-4C44-8AA1-8EC885EE8102") ?? UUID(),
                listingID: defaultListings[2].id,
                listingTitle: defaultListings[2].heroTitle,
                participantName: defaultListings[2].sellerName,
                unreadCount: 0,
                messages: [
                    ConversationMessage(id: UUID(), senderName: "You", senderRole: "Buyer", sentAt: minutesAgo(180), body: "Can buyers request the pool certificate before inspection?", isFromCurrentUser: true, isPinnedFAQ: false),
                    ConversationMessage(id: UUID(), senderName: defaultListings[2].sellerName, senderRole: "Owner", sentAt: minutesAgo(151), body: "Yes. It's already in the disclosure bundle and I can resend the secure link here.", isFromCurrentUser: false, isPinnedFAQ: true)
                ]
            )
        ]
    }

    static var defaultOffers: [OfferRecord] {
        [
            OfferRecord(
                id: UUID(),
                listingID: defaultListings[3].id,
                propertyTitle: defaultListings[3].heroTitle,
                buyerName: "You",
                amount: 1_150_000,
                depositIntention: "5% on exchange",
                settlementDays: 45,
                subjectToFinance: true,
                subjectToBuildingInspection: false,
                subjectToPestInspection: false,
                subjectToSaleOfHome: false,
                buyerMessage: "Happy to proceed quickly once my conveyancer reviews the ACT contract pack.",
                submittedAt: hoursAgo(8),
                status: .acceptedInPrinciple
            ),
            OfferRecord(
                id: UUID(),
                listingID: defaultListings[1].id,
                propertyTitle: defaultListings[1].heroTitle,
                buyerName: "Buyer lead · Michael T",
                amount: 880_000,
                depositIntention: "$20,000 with contract",
                settlementDays: 30,
                subjectToFinance: true,
                subjectToBuildingInspection: true,
                subjectToPestInspection: false,
                subjectToSaleOfHome: false,
                buyerMessage: "Offer is subject to finance and a brief review of owners corporation records.",
                submittedAt: hoursAgo(14),
                status: .countered
            )
        ]
    }

    static var defaultInspections: [InspectionRequest] {
        [
            InspectionRequest(
                id: UUID(),
                listingID: defaultListings[0].id,
                propertyTitle: defaultListings[0].heroTitle,
                slotTitle: "Open home · Sat 11:00am",
                requestedAt: hoursAgo(3),
                status: .confirmed,
                attendees: 2
            ),
            InspectionRequest(
                id: UUID(),
                listingID: defaultListings[2].id,
                propertyTitle: defaultListings[2].heroTitle,
                slotTitle: "Private inspection · Mon 4:00pm",
                requestedAt: hoursAgo(1),
                status: .requested,
                attendees: 1
            )
        ]
    }

    static var defaultTasks: [SellerTask] {
        [
            SellerTask(id: UUID(), listingID: defaultListings[2].id, title: "Confirm flood overlay extract", detail: "QLD listing can publish stronger buyer context once the council extract is attached.", dueLabel: "Today", isBlocking: false),
            SellerTask(id: UUID(), listingID: defaultListings[3].id, title: "Invite conveyancer to contract stage", detail: "Buyer accepted in principle. Route draft contract and milestone tracking next.", dueLabel: "Next step", isBlocking: true),
            SellerTask(id: UUID(), listingID: defaultListings[1].id, title: "Respond to counter-offer conditions", detail: "Finance and owners corporation review are pending on the VIC apartment.", dueLabel: "Within 24 hours", isBlocking: true)
        ]
    }

    static let defaultSavedListingIDs: Set<UUID> = [defaultListings[0].id, defaultListings[2].id]

    private static func daysFromNow(_ days: Int, hour: Int) -> Date {
        let calendar = Calendar.current
        let base = calendar.startOfDay(for: .now)
        let dated = calendar.date(byAdding: .day, value: days, to: base) ?? .now
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: dated) ?? dated
    }

    private static func hoursAgo(_ hours: Int) -> Date {
        Calendar.current.date(byAdding: .hour, value: -hours, to: .now) ?? .now
    }

    private static func minutesAgo(_ minutes: Int) -> Date {
        Calendar.current.date(byAdding: .minute, value: -minutes, to: .now) ?? .now
    }
}
