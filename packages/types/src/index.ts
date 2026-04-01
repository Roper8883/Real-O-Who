export type UserRole =
  | "guest"
  | "buyer"
  | "seller"
  | "seller_buyer"
  | "inspector"
  | "admin"
  | "support"
  | "compliance";

export type AustralianState =
  | "NSW"
  | "VIC"
  | "QLD"
  | "SA"
  | "ACT"
  | "NT"
  | "WA"
  | "TAS";

export type SaleMethod = "private_treaty";

export type PropertyType =
  | "house"
  | "townhouse"
  | "apartment"
  | "land"
  | "acreage"
  | "strata_home";

export type ListingMode =
  | "owner_direct"
  | "public"
  | "off_market"
  | "invite_only"
  | "password_protected"
  | "coming_soon";

export type ListingStatus =
  | "draft"
  | "scheduled"
  | "pending_compliance"
  | "published"
  | "active"
  | "paused"
  | "off_market"
  | "under_offer"
  | "accepted_in_principle"
  | "contract_requested"
  | "exchanged"
  | "settled"
  | "sold"
  | "hidden"
  | "archived";

export type OfferStatus =
  | "draft"
  | "submitted"
  | "under_review"
  | "countered"
  | "accepted"
  | "accepted_in_principle"
  | "declined"
  | "rejected"
  | "expired"
  | "withdrawn"
  | "contract_requested"
  | "under_contract"
  | "completed";

export type BookingType = "open_home" | "private_inspection";

export type ServiceType = "building" | "pest" | "combined";

export type DisclosureStatus =
  | "not_started"
  | "in_progress"
  | "complete"
  | "awaiting_review";

export type DataProvenance =
  | "seller_supplied"
  | "public_record"
  | "licensed_provider"
  | "estimated"
  | "unavailable";

export interface Coordinates {
  latitude: number;
  longitude: number;
}

export interface PropertyAddress {
  line1: string;
  suburb: string;
  postcode: string;
  state: AustralianState;
  country: "Australia";
  coordinates: Coordinates;
  councilArea?: string;
}

export interface PropertyFacts {
  bedrooms: number;
  bathrooms: number;
  carSpaces: number;
  landSizeSqm?: number;
  buildingSizeSqm?: number;
  yearBuilt?: number;
  study: boolean;
  pool: boolean;
  outdoorArea: boolean;
  accessibilityFeatures: string[];
  heatingCooling: string[];
  energyFeatures: string[];
  internetNotes?: string;
  currentlyTenanted: boolean;
  weeklyRent?: number;
  occupancyStatus: "owner_occupied" | "vacant" | "tenanted";
  bodyCorporateFeesQuarterly?: number;
  councilRatesAnnual?: number;
  waterRatesAnnual?: number;
}

export interface PropertyMedia {
  id: string;
  kind: "photo" | "video" | "floorplan" | "site_plan" | "brochure";
  title: string;
  url: string;
  thumbnailUrl?: string;
  altText: string;
  isCover?: boolean;
}

export interface PropertyDocument {
  id: string;
  category:
    | "contract"
    | "section_32"
    | "form_1"
    | "disclosure_bundle"
    | "pool_certificate"
    | "body_corporate"
    | "title_search"
    | "survey"
    | "building_report"
    | "pest_report"
    | "council"
    | "brochure";
  name: string;
  required: boolean;
  access: "public" | "buyer_on_request" | "seller_only" | "admin_only";
  uploadedAt?: string;
  expiresAt?: string;
  provenance: DataProvenance;
}

export interface ListingDocumentRequirement {
  key: string;
  title: string;
  description: string;
  required: boolean;
  status: "required" | "recommended" | "optional";
}

export interface RiskFlag {
  key: string;
  label: string;
  status: "yes" | "no" | "unknown";
  provenance: DataProvenance;
}

export interface ComparableSale {
  id: string;
  address: string;
  soldAt: string;
  soldPrice: number | null;
  distanceKm: number;
  bedrooms: number;
  bathrooms: number;
  landSizeSqm?: number;
  provenance: DataProvenance;
}

export interface InspectionSlot {
  id: string;
  listingId: string;
  type: BookingType;
  startAt: string;
  endAt: string;
  capacity?: number;
  bookedCount: number;
  note?: string;
}

export interface InspectionBooking {
  id: string;
  listingId: string;
  slotId: string;
  buyerId: string;
  status: "requested" | "approved" | "rejected" | "cancelled";
  attendeeCount: number;
  note?: string;
}

export interface OfferVersion {
  id: string;
  amount: number;
  depositIntent: number;
  settlementDays: number;
  subjectToFinance: boolean;
  subjectToBuildingInspection: boolean;
  subjectToPestInspection: boolean;
  subjectToSaleOfHome: boolean;
  requestedInclusions: string[];
  acknowledgedExclusions: string[];
  expiresAt: string;
  message: string;
  evidenceUploaded: boolean;
  legalRepresentativeName?: string;
  createdAt: string;
}

export interface OfferThread {
  id: string;
  listingId: string;
  buyerId: string;
  sellerId: string;
  status: OfferStatus;
  versions: OfferVersion[];
  disclaimers: string[];
  lastUpdatedAt: string;
}

export interface ConversationMessage {
  id: string;
  senderId: string;
  sentAt: string;
  body: string;
  attachments?: { id: string; name: string; type: "image" | "pdf" | "doc" }[];
  system?: boolean;
}

export interface Conversation {
  id: string;
  listingId: string;
  participantIds: string[];
  lastMessagePreview: string;
  unreadCount: number;
  flagged: boolean;
  messages: ConversationMessage[];
}

export interface ServiceProvider {
  id: string;
  businessName: string;
  serviceTypes: ServiceType[];
  serviceArea: string[];
  turnaroundHours: number;
  insured: boolean;
  licenceVerified: boolean;
  description: string;
}

export interface UserProfile {
  id: string;
  role: UserRole;
  displayName: string;
  email: string;
  phone?: string;
  verifiedEmail: boolean;
  verifiedPhone: boolean;
  avatarUrl?: string;
  responseRate?: number;
  averageResponseHours?: number;
  identityVerificationStatus?: "not_started" | "pending" | "verified";
  preferredLocations?: string[];
}

export interface ListingSummary {
  id: string;
  slug: string;
  title: string;
  address: PropertyAddress;
  propertyType: PropertyType;
  saleMethod: SaleMethod;
  listingMode: ListingMode;
  status: ListingStatus;
  priceLabel: string;
  askingPrice?: number;
  facts: PropertyFacts;
  coverImage: string;
  sellerId: string;
  sellerName: string;
  sellerVerified: boolean;
  legalDisclosureStatus: DisclosureStatus;
  inspectionSlots: InspectionSlot[];
  tags: string[];
  publishedAt: string;
}

export interface ListingDetail extends ListingSummary {
  heroMedia: PropertyMedia[];
  description: string;
  ownerLoves: string[];
  neighbourhoodHighlights: string[];
  documents: PropertyDocument[];
  requiredDocuments: ListingDocumentRequirement[];
  risks: RiskFlag[];
  comparableSales: ComparableSale[];
  timelines: { label: string; value: string }[];
  schools: { name: string; distanceKm: number }[];
  amenities: { label: string; distanceKm: number }[];
  settlementPreference?: string;
}

export interface SearchFilters {
  query?: string;
  state?: AustralianState;
  suburb?: string;
  postcode?: string;
  propertyTypes?: PropertyType[];
  minPrice?: number;
  maxPrice?: number;
  minBedrooms?: number;
  minBathrooms?: number;
  parking?: number;
  hasVideo?: boolean;
  hasFloorplan?: boolean;
  hasDocuments?: boolean;
  sellerVerified?: boolean;
  openHomeOnly?: boolean;
  includeUnderOffer?: boolean;
  pool?: boolean;
  study?: boolean;
  outdoorArea?: boolean;
  accessibilityFeature?: string;
  sort?: "relevance" | "newest" | "price_asc" | "price_desc" | "land_desc";
}

export interface RuleSet {
  state: AustralianState;
  saleMethod: SaleMethod;
  disclosureSummary: string;
  coolingOff: {
    enabled: boolean;
    label: string;
    note: string;
  };
  publishingPrerequisites: string[];
  requiredDocuments: ListingDocumentRequirement[];
  inspectionGuidance: string[];
  offerWarnings: string[];
  settlementDefaults: {
    minDays: number;
    maxDays: number;
    defaultDays: number;
  };
  featureFlags: Record<string, boolean>;
}

export interface SavedProperty {
  id: string;
  listingId: string;
  collection: string;
  note?: string;
  tags: string[];
  status: "saved" | "viewed" | "inspected" | "offered";
}

export interface SavedSearch {
  id: string;
  name: string;
  filters: SearchFilters;
  instantAlert: boolean;
}

export interface DashboardMetrics {
  activeListings: number;
  draftListings: number;
  savedByBuyers: number;
  enquiryThreads: number;
  upcomingInspections: number;
  liveOffers: number;
  complianceTasks: number;
}
