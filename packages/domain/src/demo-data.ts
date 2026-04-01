import type {
  Conversation,
  DashboardMetrics,
  InspectionBooking,
  InspectionSlot,
  ListingDetail,
  OfferThread,
  SavedProperty,
  SavedSearch,
  ServiceProvider,
  UserProfile,
} from "@homeowner/types";
import { getRequiredDocuments } from "./rules/engine";

const now = "2026-03-31T08:00:00.000Z";

export const sellers: UserProfile[] = [
  {
    id: "user-seller-1",
    role: "seller_buyer",
    displayName: "Sophie Turner",
    email: "sophie@example.com",
    verifiedEmail: true,
    verifiedPhone: true,
    identityVerificationStatus: "verified",
    responseRate: 96,
    averageResponseHours: 1.8,
  },
  {
    id: "user-seller-2",
    role: "seller",
    displayName: "Lachlan Reid",
    email: "lachlan@example.com",
    verifiedEmail: true,
    verifiedPhone: false,
    identityVerificationStatus: "pending",
    responseRate: 88,
    averageResponseHours: 4.3,
  },
];

export const buyers: UserProfile[] = [
  {
    id: "user-buyer-1",
    role: "buyer",
    displayName: "Mia Harper",
    email: "mia@example.com",
    verifiedEmail: true,
    verifiedPhone: true,
    preferredLocations: ["Paddington", "West End", "New Farm"],
  },
  {
    id: "user-buyer-2",
    role: "buyer",
    displayName: "Oliver Ng",
    email: "oliver@example.com",
    verifiedEmail: true,
    verifiedPhone: false,
    preferredLocations: ["Fremantle", "Subiaco"],
  },
  {
    id: "user-buyer-3",
    role: "buyer",
    displayName: "Emma Collins",
    email: "emma@example.com",
    verifiedEmail: true,
    verifiedPhone: true,
    preferredLocations: ["Canberra", "Kingston", "Narrabundah"],
  },
];

export const inspectors: UserProfile[] = [
  {
    id: "user-inspector-1",
    role: "inspector",
    displayName: "Cedar Building Inspections",
    email: "cedar@example.com",
    verifiedEmail: true,
    verifiedPhone: true,
  },
  {
    id: "user-inspector-2",
    role: "inspector",
    displayName: "Blue Gum Pest & Property",
    email: "bluegum@example.com",
    verifiedEmail: true,
    verifiedPhone: true,
  },
];

export const admins: UserProfile[] = [
  {
    id: "user-admin-1",
    role: "admin",
    displayName: "Admin Ops",
    email: "ops@example.com",
    verifiedEmail: true,
    verifiedPhone: true,
  },
];

function inspectionSlots(listingId: string, starts: string[]): InspectionSlot[] {
  return starts.map((startAt, index) => ({
    id: `${listingId}-slot-${index + 1}`,
    listingId,
    type: index === 0 ? "open_home" : "private_inspection",
    startAt,
    endAt: new Date(new Date(startAt).getTime() + 45 * 60 * 1000).toISOString(),
    capacity: index === 0 ? 20 : 1,
    bookedCount: index === 0 ? 6 : 0,
    note:
      index === 0
        ? "Street parking available. Please check in at the front gate."
        : "Private appointments by request with 24 hours notice.",
  }));
}

const baseListings: Omit<ListingDetail, "requiredDocuments">[] = [
  {
    id: "listing-nsw-paddington",
    slug: "paddington-terrace-renovated-family-home",
    title: "Renovated terrace with north-facing courtyard",
    address: {
      line1: "16 Windsor Street",
      suburb: "Paddington",
      postcode: "2021",
      state: "NSW",
      country: "Australia",
      councilArea: "City of Sydney",
      coordinates: { latitude: -33.883, longitude: 151.231 },
    },
    propertyType: "house",
    saleMethod: "private_treaty",
    listingMode: "owner_direct",
    status: "active",
    priceLabel: "$2.45m",
    askingPrice: 2450000,
    facts: {
      bedrooms: 3,
      bathrooms: 2,
      carSpaces: 1,
      landSizeSqm: 183,
      buildingSizeSqm: 162,
      yearBuilt: 1910,
      study: true,
      pool: false,
      outdoorArea: true,
      accessibilityFeatures: [],
      heatingCooling: ["Ducted air conditioning", "Hydronic heating"],
      energyFeatures: ["8kW solar"],
      internetNotes: "FTTP available",
      currentlyTenanted: false,
      occupancyStatus: "owner_occupied",
      councilRatesAnnual: 2650,
      waterRatesAnnual: 920,
    },
    coverImage:
      "https://images.unsplash.com/photo-1600585154340-be6161a56a0c?auto=format&fit=crop&w=1200&q=80",
    sellerId: sellers[0].id,
    sellerName: sellers[0].displayName,
    sellerVerified: true,
    legalDisclosureStatus: "complete",
    inspectionSlots: inspectionSlots("listing-nsw-paddington", [
      "2026-04-05T00:00:00.000Z",
      "2026-04-08T08:30:00.000Z",
    ]),
    tags: ["new", "seller verified", "documents ready"],
    publishedAt: "2026-03-28T00:00:00.000Z",
    heroMedia: [
      {
        id: "nsw-photo-1",
        kind: "photo",
        title: "Street appeal",
        url: "https://images.unsplash.com/photo-1600585154340-be6161a56a0c?auto=format&fit=crop&w=1600&q=80",
        altText: "Renovated Paddington terrace viewed from the street",
        isCover: true,
      },
      {
        id: "nsw-photo-2",
        kind: "photo",
        title: "Kitchen and dining",
        url: "https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?auto=format&fit=crop&w=1600&q=80",
        altText: "Open-plan kitchen and dining area",
      },
      {
        id: "nsw-floorplan",
        kind: "floorplan",
        title: "Floorplan",
        url: "https://images.unsplash.com/photo-1505693416388-ac5ce068fe85?auto=format&fit=crop&w=1200&q=80",
        altText: "Floorplan placeholder",
      }
    ],
    description:
      "A polished Paddington terrace designed for modern family life, with calm natural light, flexible living, and a courtyard built for year-round entertaining.",
    ownerLoves: [
      "Morning light in the rear living space",
      "Walkability to Five Ways and Centennial Park",
      "A proper home office without sacrificing a bedroom"
    ],
    neighbourhoodHighlights: [
      "Paddington Markets and Oxford Street dining nearby",
      "Easy city and eastern suburbs access",
      "Strong school options within a short drive"
    ],
    documents: [
      {
        id: "doc-nsw-contract",
        category: "contract",
        name: "Contract of sale",
        required: true,
        access: "buyer_on_request",
        uploadedAt: now,
        provenance: "seller_supplied"
      },
      {
        id: "doc-nsw-brochure",
        category: "brochure",
        name: "Digital brochure",
        required: false,
        access: "public",
        uploadedAt: now,
        provenance: "seller_supplied"
      }
    ],
    risks: [
      { key: "flood", label: "Flood overlay", status: "no", provenance: "seller_supplied" },
      { key: "heritage", label: "Heritage controls", status: "yes", provenance: "public_record" }
    ],
    comparableSales: [
      {
        id: "comp-nsw-1",
        address: "18 Windsor Street, Paddington NSW",
        soldAt: "2025-11-21",
        soldPrice: 2385000,
        distanceKm: 0.12,
        bedrooms: 3,
        bathrooms: 2,
        landSizeSqm: 176,
        provenance: "licensed_provider"
      }
    ],
    timelines: [
      { label: "Listed", value: "28 Mar 2026" },
      { label: "Contract ready", value: "Confirmed" }
    ],
    schools: [{ name: "Paddington Public School", distanceKm: 0.6 }],
    amenities: [
      { label: "Centennial Park", distanceKm: 1.3 },
      { label: "Edgecliff Station", distanceKm: 1.7 }
    ],
    settlementPreference: "Flexible 42-60 day settlement available."
  },
  {
    id: "listing-vic-south-yarra",
    slug: "south-yarra-apartment-with-terrace-and-study",
    title: "Architect-designed apartment with terrace and study",
    address: {
      line1: "402/87 Toorak Road",
      suburb: "South Yarra",
      postcode: "3141",
      state: "VIC",
      country: "Australia",
      councilArea: "City of Melbourne",
      coordinates: { latitude: -37.84, longitude: 144.992 }
    },
    propertyType: "apartment",
    saleMethod: "private_treaty",
    listingMode: "owner_direct",
    status: "active",
    priceLabel: "$1.18m - $1.24m",
    askingPrice: 1210000,
    facts: {
      bedrooms: 2,
      bathrooms: 2,
      carSpaces: 1,
      buildingSizeSqm: 118,
      yearBuilt: 2018,
      study: true,
      pool: false,
      outdoorArea: true,
      accessibilityFeatures: ["Lift access", "Step-free shower"],
      heatingCooling: ["Reverse-cycle split systems"],
      energyFeatures: ["Double glazing"],
      internetNotes: "NBN Fibre to the Building",
      currentlyTenanted: false,
      occupancyStatus: "owner_occupied",
      bodyCorporateFeesQuarterly: 1680,
      councilRatesAnnual: 1760,
      waterRatesAnnual: 720
    },
    coverImage:
      "https://images.unsplash.com/photo-1494526585095-c41746248156?auto=format&fit=crop&w=1200&q=80",
    sellerId: sellers[0].id,
    sellerName: sellers[0].displayName,
    sellerVerified: true,
    legalDisclosureStatus: "complete",
    inspectionSlots: inspectionSlots("listing-vic-south-yarra", [
      "2026-04-06T02:00:00.000Z",
      "2026-04-09T09:00:00.000Z"
    ]),
    tags: ["video", "seller verified", "section 32 ready"],
    publishedAt: "2026-03-25T00:00:00.000Z",
    heroMedia: [
      {
        id: "vic-photo-1",
        kind: "photo",
        title: "Living and terrace",
        url: "https://images.unsplash.com/photo-1494526585095-c41746248156?auto=format&fit=crop&w=1600&q=80",
        altText: "Modern apartment living room opening to terrace",
        isCover: true
      },
      {
        id: "vic-video-1",
        kind: "video",
        title: "Walkthrough",
        url: "https://example.com/media/vic-walkthrough.mp4",
        thumbnailUrl:
          "https://images.unsplash.com/photo-1484154218962-a197022b5858?auto=format&fit=crop&w=1200&q=80",
        altText: "Video walkthrough thumbnail"
      }
    ],
    description:
      "A refined South Yarra apartment with generous indoor-outdoor living, a genuine study zone, and direct access to transport, dining, and river trails.",
    ownerLoves: ["Evening light on the terrace", "Secure building with low-maintenance living"],
    neighbourhoodHighlights: ["Walk to Toorak Road dining", "Tram and train options nearby"],
    documents: [
      {
        id: "doc-vic-s32",
        category: "section_32",
        name: "Section 32 statement",
        required: true,
        access: "buyer_on_request",
        uploadedAt: now,
        provenance: "seller_supplied"
      }
    ],
    risks: [{ key: "strata", label: "Owners corporation", status: "yes", provenance: "seller_supplied" }],
    comparableSales: [],
    timelines: [{ label: "Section 32", value: "Uploaded" }],
    schools: [{ name: "Melbourne Girls College", distanceKm: 3.2 }],
    amenities: [{ label: "South Yarra Station", distanceKm: 0.4 }],
    settlementPreference: "60-day settlement preferred."
  },
  {
    id: "listing-qld-bardon",
    slug: "bardon-queenslander-with-pool-and-city-glimpses",
    title: "Renovated Queenslander with pool and city glimpses",
    address: {
      line1: "22 Mornington Street",
      suburb: "Bardon",
      postcode: "4065",
      state: "QLD",
      country: "Australia",
      councilArea: "Brisbane City Council",
      coordinates: { latitude: -27.461, longitude: 152.994 }
    },
    propertyType: "house",
    saleMethod: "private_treaty",
    listingMode: "owner_direct",
    status: "under_offer",
    priceLabel: "Offers over $1.95m",
    askingPrice: 1950000,
    facts: {
      bedrooms: 4,
      bathrooms: 3,
      carSpaces: 2,
      landSizeSqm: 607,
      buildingSizeSqm: 242,
      yearBuilt: 1934,
      study: true,
      pool: true,
      outdoorArea: true,
      accessibilityFeatures: ["Ground-floor bedroom"],
      heatingCooling: ["Split system air conditioning", "Ceiling fans"],
      energyFeatures: ["Solar hot water", "5kW solar"],
      currentlyTenanted: false,
      occupancyStatus: "owner_occupied",
      councilRatesAnnual: 3250,
      waterRatesAnnual: 1180
    },
    coverImage:
      "https://images.unsplash.com/photo-1512917774080-9991f1c4c750?auto=format&fit=crop&w=1200&q=80",
    sellerId: sellers[1].id,
    sellerName: sellers[1].displayName,
    sellerVerified: false,
    legalDisclosureStatus: "awaiting_review",
    inspectionSlots: inspectionSlots("listing-qld-bardon", [
      "2026-04-04T23:30:00.000Z",
      "2026-04-07T08:00:00.000Z"
    ]),
    tags: ["pool", "documents", "under offer"],
    publishedAt: "2026-03-18T00:00:00.000Z",
    heroMedia: [
      {
        id: "qld-photo-1",
        kind: "photo",
        title: "Pool and rear deck",
        url: "https://images.unsplash.com/photo-1512917774080-9991f1c4c750?auto=format&fit=crop&w=1600&q=80",
        altText: "Queenslander rear deck overlooking pool",
        isCover: true
      }
    ],
    description:
      "Classic Queensland character, a family pool, and flexible living zones come together in a polished Bardon home close to schools and city access.",
    ownerLoves: ["Breezes through the upper deck", "A pool big enough for real summer use"],
    neighbourhoodHighlights: ["School catchments nearby", "Easy commute to Paddington and the CBD"],
    documents: [
      {
        id: "doc-qld-bundle",
        category: "disclosure_bundle",
        name: "Queensland disclosure bundle",
        required: true,
        access: "buyer_on_request",
        uploadedAt: now,
        provenance: "seller_supplied"
      },
      {
        id: "doc-qld-pool",
        category: "pool_certificate",
        name: "Pool compliance certificate",
        required: false,
        access: "buyer_on_request",
        uploadedAt: now,
        provenance: "seller_supplied"
      }
    ],
    risks: [
      { key: "flood", label: "Flood overlay", status: "unknown", provenance: "unavailable" },
      { key: "pool", label: "Pool on site", status: "yes", provenance: "seller_supplied" }
    ],
    comparableSales: [],
    timelines: [{ label: "Disclosure bundle", value: "Awaiting compliance review" }],
    schools: [{ name: "Bardon State School", distanceKm: 0.9 }],
    amenities: [{ label: "Rosalie Village", distanceKm: 1.1 }],
    settlementPreference: "Flexible 30-45 day settlement."
  },
  {
    id: "listing-sa-glenelg",
    slug: "glenelg-townhouse-near-beach-and-tram",
    title: "Low-maintenance townhouse near beach and tram",
    address: {
      line1: "4/18 Essex Street",
      suburb: "Glenelg",
      postcode: "5045",
      state: "SA",
      country: "Australia",
      councilArea: "City of Holdfast Bay",
      coordinates: { latitude: -34.98, longitude: 138.515 }
    },
    propertyType: "townhouse",
    saleMethod: "private_treaty",
    listingMode: "owner_direct",
    status: "active",
    priceLabel: "$865,000",
    askingPrice: 865000,
    facts: {
      bedrooms: 3,
      bathrooms: 2,
      carSpaces: 1,
      buildingSizeSqm: 146,
      study: false,
      pool: false,
      outdoorArea: true,
      accessibilityFeatures: [],
      heatingCooling: ["Ducted reverse-cycle"],
      energyFeatures: [],
      currentlyTenanted: false,
      occupancyStatus: "vacant",
      councilRatesAnnual: 1840,
      waterRatesAnnual: 690
    },
    coverImage:
      "https://images.unsplash.com/photo-1568605114967-8130f3a36994?auto=format&fit=crop&w=1200&q=80",
    sellerId: sellers[1].id,
    sellerName: sellers[1].displayName,
    sellerVerified: false,
    legalDisclosureStatus: "in_progress",
    inspectionSlots: inspectionSlots("listing-sa-glenelg", ["2026-04-10T00:30:00.000Z"]),
    tags: ["near beach", "tram access"],
    publishedAt: "2026-03-29T00:00:00.000Z",
    heroMedia: [
      {
        id: "sa-photo-1",
        kind: "photo",
        title: "Facade",
        url: "https://images.unsplash.com/photo-1568605114967-8130f3a36994?auto=format&fit=crop&w=1600&q=80",
        altText: "Townhouse facade",
        isCover: true
      }
    ],
    description: "A lock-up-and-leave townhouse close to the beach, dining, and light rail with clean modern finishes and an easy layout.",
    ownerLoves: ["The tram stop being so close", "Easy entertaining courtyard"],
    neighbourhoodHighlights: ["Walk to Jetty Road", "Quick beach access"],
    documents: [
      {
        id: "doc-sa-form1",
        category: "form_1",
        name: "Form 1",
        required: true,
        access: "buyer_on_request",
        uploadedAt: now,
        provenance: "seller_supplied"
      }
    ],
    risks: [],
    comparableSales: [],
    timelines: [{ label: "Form 1 served", value: "Pending" }],
    schools: [],
    amenities: [{ label: "Glenelg tram stop", distanceKm: 0.4 }],
    settlementPreference: "Standard 45-day settlement."
  },
  {
    id: "listing-act-kingston",
    slug: "kingston-character-home-with-act-reports-ready",
    title: "Character home with ACT reports ready for buyers",
    address: {
      line1: "11 Leichhardt Street",
      suburb: "Kingston",
      postcode: "2604",
      state: "ACT",
      country: "Australia",
      councilArea: "ACT",
      coordinates: { latitude: -35.318, longitude: 149.145 }
    },
    propertyType: "house",
    saleMethod: "private_treaty",
    listingMode: "owner_direct",
    status: "active",
    priceLabel: "$1.68m",
    askingPrice: 1680000,
    facts: {
      bedrooms: 3,
      bathrooms: 2,
      carSpaces: 2,
      landSizeSqm: 502,
      buildingSizeSqm: 176,
      study: true,
      pool: false,
      outdoorArea: true,
      accessibilityFeatures: [],
      heatingCooling: ["Ducted gas heating", "Evaporative cooling"],
      energyFeatures: ["Ceiling insulation upgraded"],
      currentlyTenanted: false,
      occupancyStatus: "owner_occupied"
    },
    coverImage:
      "https://images.unsplash.com/photo-1448630360428-65456885c650?auto=format&fit=crop&w=1200&q=80",
    sellerId: sellers[0].id,
    sellerName: sellers[0].displayName,
    sellerVerified: true,
    legalDisclosureStatus: "complete",
    inspectionSlots: inspectionSlots("listing-act-kingston", [
      "2026-04-05T01:00:00.000Z",
      "2026-04-07T06:30:00.000Z"
    ]),
    tags: ["building report ready", "pest report ready"],
    publishedAt: "2026-03-22T00:00:00.000Z",
    heroMedia: [
      {
        id: "act-photo-1",
        kind: "photo",
        title: "Front garden",
        url: "https://images.unsplash.com/photo-1448630360428-65456885c650?auto=format&fit=crop&w=1600&q=80",
        altText: "ACT home with leafy front garden",
        isCover: true
      }
    ],
    description: "A tightly held Kingston home with the draft contract, building report, and pest report ready for serious buyers who want a clearer path to legal review.",
    ownerLoves: ["Walking to the foreshore", "The calm garden outlook from the study"],
    neighbourhoodHighlights: ["Kingston Foreshore nearby", "Canberra CBD access"],
    documents: [
      {
        id: "doc-act-contract",
        category: "contract",
        name: "Draft contract",
        required: true,
        access: "buyer_on_request",
        uploadedAt: now,
        provenance: "seller_supplied"
      },
      {
        id: "doc-act-building",
        category: "building_report",
        name: "Building and compliance report",
        required: true,
        access: "buyer_on_request",
        uploadedAt: now,
        provenance: "seller_supplied"
      },
      {
        id: "doc-act-pest",
        category: "pest_report",
        name: "Pest inspection report",
        required: true,
        access: "buyer_on_request",
        uploadedAt: now,
        provenance: "seller_supplied"
      }
    ],
    risks: [],
    comparableSales: [],
    timelines: [{ label: "Reports ready", value: "Available" }],
    schools: [],
    amenities: [{ label: "Kingston Foreshore", distanceKm: 0.7 }],
    settlementPreference: "45-day settlement preferred."
  },
  {
    id: "listing-wa-fremantle",
    slug: "fremantle-character-home-with-flexible-conditions",
    title: "Character cottage with flexible settlement options",
    address: {
      line1: "7 Ellen Street",
      suburb: "Fremantle",
      postcode: "6160",
      state: "WA",
      country: "Australia",
      councilArea: "City of Fremantle",
      coordinates: { latitude: -32.055, longitude: 115.746 }
    },
    propertyType: "house",
    saleMethod: "private_treaty",
    listingMode: "owner_direct",
    status: "active",
    priceLabel: "Contact for price",
    askingPrice: 1320000,
    facts: {
      bedrooms: 3,
      bathrooms: 1,
      carSpaces: 1,
      landSizeSqm: 356,
      study: false,
      pool: false,
      outdoorArea: true,
      accessibilityFeatures: [],
      heatingCooling: ["Split system"],
      energyFeatures: [],
      currentlyTenanted: false,
      occupancyStatus: "owner_occupied"
    },
    coverImage:
      "https://images.unsplash.com/photo-1570129477492-45c003edd2be?auto=format&fit=crop&w=1200&q=80",
    sellerId: sellers[1].id,
    sellerName: sellers[1].displayName,
    sellerVerified: false,
    legalDisclosureStatus: "in_progress",
    inspectionSlots: inspectionSlots("listing-wa-fremantle", ["2026-04-11T02:00:00.000Z"]),
    tags: ["finance condition friendly"],
    publishedAt: "2026-03-21T00:00:00.000Z",
    heroMedia: [
      {
        id: "wa-photo-1",
        kind: "photo",
        title: "Front elevation",
        url: "https://images.unsplash.com/photo-1570129477492-45c003edd2be?auto=format&fit=crop&w=1600&q=80",
        altText: "WA character cottage exterior",
        isCover: true
      }
    ],
    description: "A Fremantle cottage set up for a buyer who wants transparent communication and clear conditional offer options.",
    ownerLoves: ["Coffee and dining nearby", "Low-maintenance courtyard"],
    neighbourhoodHighlights: ["Walkable Fremantle lifestyle"],
    documents: [],
    risks: [],
    comparableSales: [],
    timelines: [{ label: "Conditional offer support", value: "Enabled" }],
    schools: [],
    amenities: [{ label: "Fremantle train station", distanceKm: 0.9 }],
    settlementPreference: "Flexible 30-60 day settlement."
  },
  {
    id: "listing-tas-battery-point",
    slug: "battery-point-cottage-with-buyer-beware-prompts",
    title: "Battery Point cottage with strong due diligence guidance",
    address: {
      line1: "3 Arthur Circus",
      suburb: "Battery Point",
      postcode: "7004",
      state: "TAS",
      country: "Australia",
      councilArea: "City of Hobart",
      coordinates: { latitude: -42.889, longitude: 147.336 }
    },
    propertyType: "house",
    saleMethod: "private_treaty",
    listingMode: "owner_direct",
    status: "active",
    priceLabel: "$1.12m",
    askingPrice: 1120000,
    facts: {
      bedrooms: 2,
      bathrooms: 1,
      carSpaces: 0,
      study: false,
      pool: false,
      outdoorArea: true,
      accessibilityFeatures: [],
      heatingCooling: ["Wood heater"],
      energyFeatures: [],
      currentlyTenanted: false,
      occupancyStatus: "vacant"
    },
    coverImage:
      "https://images.unsplash.com/photo-1564013799919-ab600027ffc6?auto=format&fit=crop&w=1200&q=80",
    sellerId: sellers[0].id,
    sellerName: sellers[0].displayName,
    sellerVerified: true,
    legalDisclosureStatus: "complete",
    inspectionSlots: inspectionSlots("listing-tas-battery-point", ["2026-04-06T01:30:00.000Z"]),
    tags: ["buyer due diligence prompts"],
    publishedAt: "2026-03-24T00:00:00.000Z",
    heroMedia: [
      {
        id: "tas-photo-1",
        kind: "photo",
        title: "Street view",
        url: "https://images.unsplash.com/photo-1564013799919-ab600027ffc6?auto=format&fit=crop&w=1600&q=80",
        altText: "Tasmanian cottage",
        isCover: true
      }
    ],
    description: "A charming Battery Point home presented with clear buyer-beware prompts and a transparent request-for-documents flow.",
    ownerLoves: ["Historic street character", "Walks to Salamanca"],
    neighbourhoodHighlights: ["Nearby cafes and waterfront"],
    documents: [],
    risks: [{ key: "heritage", label: "Heritage overlay", status: "unknown", provenance: "unavailable" }],
    comparableSales: [],
    timelines: [{ label: "Buyer due diligence prompts", value: "Enabled" }],
    schools: [],
    amenities: [{ label: "Salamanca Place", distanceKm: 0.7 }],
    settlementPreference: "42-day settlement preferred."
  },
  {
    id: "listing-nt-parap",
    slug: "parap-home-with-contract-placeholder-ready",
    title: "Family home with NT contract workflow placeholder ready",
    address: {
      line1: "14 Gregory Street",
      suburb: "Parap",
      postcode: "0820",
      state: "NT",
      country: "Australia",
      councilArea: "Darwin",
      coordinates: { latitude: -12.43, longitude: 130.84 }
    },
    propertyType: "house",
    saleMethod: "private_treaty",
    listingMode: "owner_direct",
    status: "active",
    priceLabel: "$980,000",
    askingPrice: 980000,
    facts: {
      bedrooms: 4,
      bathrooms: 2,
      carSpaces: 2,
      landSizeSqm: 817,
      study: true,
      pool: false,
      outdoorArea: true,
      accessibilityFeatures: [],
      heatingCooling: ["Split system air conditioning"],
      energyFeatures: ["Solar PV"],
      currentlyTenanted: false,
      occupancyStatus: "owner_occupied"
    },
    coverImage:
      "https://images.unsplash.com/photo-1576941089067-2de3c901e126?auto=format&fit=crop&w=1200&q=80",
    sellerId: sellers[1].id,
    sellerName: sellers[1].displayName,
    sellerVerified: false,
    legalDisclosureStatus: "in_progress",
    inspectionSlots: inspectionSlots("listing-nt-parap", ["2026-04-12T00:30:00.000Z"]),
    tags: ["nt contract placeholder"],
    publishedAt: "2026-03-27T00:00:00.000Z",
    heroMedia: [
      {
        id: "nt-photo-1",
        kind: "photo",
        title: "Exterior",
        url: "https://images.unsplash.com/photo-1576941089067-2de3c901e126?auto=format&fit=crop&w=1600&q=80",
        altText: "Northern Territory family home exterior",
        isCover: true
      }
    ],
    description: "A family home prepared for private treaty progression with clear non-binding offer language and an NT contract workflow placeholder.",
    ownerLoves: ["Room for caravans and gear", "Short drive to markets and city"],
    neighbourhoodHighlights: ["Parap village nearby"],
    documents: [],
    risks: [],
    comparableSales: [],
    timelines: [{ label: "Approved form contract placeholder", value: "Tracked" }],
    schools: [],
    amenities: [{ label: "Parap Village Markets", distanceKm: 0.5 }],
    settlementPreference: "Flexible settlement."
  }
];

export const listings: ListingDetail[] = baseListings.map((listing) => ({
  ...listing,
  requiredDocuments: getRequiredDocuments(listing.address.state, listing),
}));

export const savedProperties: SavedProperty[] = [
  {
    id: "saved-1",
    listingId: listings[0].id,
    collection: "Inner city shortlist",
    note: "Great courtyard and office layout.",
    tags: ["walkable", "contract ready"],
    status: "saved",
  },
  {
    id: "saved-2",
    listingId: listings[4].id,
    collection: "Canberra move",
    tags: ["reports ready"],
    status: "inspected",
  },
];

export const savedSearches: SavedSearch[] = [
  {
    id: "search-1",
    name: "Brisbane family homes with pool",
    instantAlert: true,
    filters: {
      state: "QLD",
      minBedrooms: 4,
      pool: true,
      sort: "newest",
    },
  },
];

export const conversations: Conversation[] = [
  {
    id: "conversation-1",
    listingId: listings[0].id,
    participantIds: [buyers[0].id, sellers[0].id],
    lastMessagePreview: "Can I review the contract before the Wednesday private inspection?",
    unreadCount: 1,
    flagged: false,
    messages: [
      {
        id: "message-1",
        senderId: buyers[0].id,
        sentAt: "2026-03-30T06:12:00.000Z",
        body: "Hi Sophie, could I review the contract before the Wednesday private inspection?",
      },
      {
        id: "message-2",
        senderId: sellers[0].id,
        sentAt: "2026-03-30T06:43:00.000Z",
        body: "Absolutely. I can share it through the document panel today.",
      },
      {
        id: "message-3",
        senderId: "system",
        sentAt: "2026-03-30T06:44:00.000Z",
        body: "System notice: Contract of sale shared with secure access until 6 Apr 2026.",
        system: true,
      }
    ],
  },
];

export const inspectionBookings: InspectionBooking[] = [
  {
    id: "booking-1",
    listingId: listings[0].id,
    slotId: listings[0].inspectionSlots[1].id,
    buyerId: buyers[0].id,
    status: "approved",
    attendeeCount: 2,
    note: "Will attend with conveyancer.",
  },
];

export const offerThreads: OfferThread[] = [
  {
    id: "offer-thread-wa",
    listingId: listings[5].id,
    buyerId: buyers[1].id,
    sellerId: sellers[1].id,
    status: "countered",
    lastUpdatedAt: "2026-03-31T03:00:00.000Z",
    disclaimers: [
      "Offers submitted through the platform are non-binding until a valid written contract is executed.",
      "Western Australia does not generally provide a statutory cooling-off period by default.",
    ],
    versions: [
      {
        id: "offer-v1",
        amount: 1260000,
        depositIntent: 25000,
        settlementDays: 45,
        subjectToFinance: true,
        subjectToBuildingInspection: true,
        subjectToPestInspection: false,
        subjectToSaleOfHome: false,
        requestedInclusions: ["Garden shed"],
        acknowledgedExclusions: [],
        expiresAt: "2026-04-02T08:00:00.000Z",
        message: "We love the home and can move quickly subject to finance.",
        evidenceUploaded: true,
        legalRepresentativeName: "Harper Legal",
        createdAt: "2026-03-29T01:00:00.000Z",
      },
      {
        id: "offer-v2",
        amount: 1295000,
        depositIntent: 30000,
        settlementDays: 35,
        subjectToFinance: true,
        subjectToBuildingInspection: true,
        subjectToPestInspection: true,
        subjectToSaleOfHome: false,
        requestedInclusions: ["Garden shed", "Garage shelving"],
        acknowledgedExclusions: [],
        expiresAt: "2026-04-03T08:00:00.000Z",
        message: "Counter offer from seller. Contract pack available upon request.",
        evidenceUploaded: true,
        createdAt: "2026-03-31T03:00:00.000Z",
      }
    ],
  },
];

export const serviceProviders: ServiceProvider[] = [
  {
    id: "provider-1",
    businessName: "Cedar Building Inspections",
    serviceTypes: ["building", "combined"],
    serviceArea: ["ACT", "NSW"],
    turnaroundHours: 48,
    insured: true,
    licenceVerified: true,
    description: "Pre-purchase building inspections with same-week booking options."
  },
  {
    id: "provider-2",
    businessName: "Blue Gum Pest & Property",
    serviceTypes: ["pest", "combined"],
    serviceArea: ["QLD", "NSW"],
    turnaroundHours: 72,
    insured: true,
    licenceVerified: true,
    description: "Combined building and pest service with insurance and clear scope notes."
  }
];

export const sellerDashboardMetrics: DashboardMetrics = {
  activeListings: 5,
  draftListings: 2,
  savedByBuyers: 48,
  enquiryThreads: 17,
  upcomingInspections: 8,
  liveOffers: 3,
  complianceTasks: 4,
};

export const allUsers = [...sellers, ...buyers, ...inspectors, ...admins];
