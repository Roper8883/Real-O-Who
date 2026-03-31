import { nanoid } from "nanoid";
import {
  buyers,
  conversations as seedConversations,
  getOfferWarnings,
  getRuleSet,
  inspectionBookings as seedInspectionBookings,
  listings as seedListings,
  offerThreads as seedOfferThreads,
  savedProperties as seedSavedProperties,
  sellerDashboardMetrics,
  serviceProviders as seedServiceProviders,
} from "@homeowner/domain";
import { applyListingFilters } from "@homeowner/search";
import type {
  AustralianState,
  InspectionBooking,
  ListingDetail,
  OfferThread,
  SavedProperty,
  SearchFilters,
  UserProfile,
} from "@homeowner/types";

const listings = structuredClone(seedListings);
const conversations = structuredClone(seedConversations);
const offerThreads = structuredClone(seedOfferThreads);
const inspectionBookings = structuredClone(seedInspectionBookings);
const savedProperties = structuredClone(seedSavedProperties);
const serviceProviders = structuredClone(seedServiceProviders);
const users = structuredClone(buyers);

export const store = {
  listListings(filters: SearchFilters = {}) {
    return applyListingFilters(listings, filters);
  },
  getListingBySlug(slug: string) {
    return listings.find((listing) => listing.slug === slug);
  },
  createDraftListing(input: Partial<ListingDetail>) {
    const listing: ListingDetail = {
      id: nanoid(),
      slug: input.slug ?? `draft-${nanoid(8)}`,
      title: input.title ?? "Untitled listing draft",
      address:
        input.address ??
        ({
          line1: "Address pending",
          suburb: "TBD",
          postcode: "0000",
          state: "NSW",
          country: "Australia",
          coordinates: { latitude: -33.86, longitude: 151.21 },
        } as ListingDetail["address"]),
      propertyType: input.propertyType ?? "house",
      saleMethod: "private_treaty",
      listingMode: "owner_direct",
      status: "draft",
      priceLabel: input.priceLabel ?? "Price on request",
      askingPrice: input.askingPrice,
      facts:
        input.facts ??
        ({
          bedrooms: 0,
          bathrooms: 0,
          carSpaces: 0,
          study: false,
          pool: false,
          outdoorArea: false,
          accessibilityFeatures: [],
          heatingCooling: [],
          energyFeatures: [],
          currentlyTenanted: false,
          occupancyStatus: "vacant",
        } as ListingDetail["facts"]),
      coverImage:
        input.coverImage ??
        "https://images.unsplash.com/photo-1560518883-ce09059eeffa?auto=format&fit=crop&w=1200&q=80",
      sellerId: input.sellerId ?? "unknown-seller",
      sellerName: input.sellerName ?? "New seller",
      sellerVerified: false,
      legalDisclosureStatus: "not_started",
      inspectionSlots: [],
      tags: [],
      publishedAt: new Date().toISOString(),
      heroMedia: [],
      description: input.description ?? "",
      ownerLoves: [],
      neighbourhoodHighlights: [],
      documents: [],
      requiredDocuments: [],
      risks: [],
      comparableSales: [],
      timelines: [{ label: "Draft created", value: new Date().toISOString() }],
      schools: [],
      amenities: [],
      settlementPreference: "",
    };

    listings.unshift(listing);
    return listing;
  },
  getRules(state: AustralianState) {
    return getRuleSet(state);
  },
  getOfferWarnings(state: AustralianState) {
    return getOfferWarnings(state);
  },
  listSavedProperties() {
    return savedProperties;
  },
  saveProperty(input: Omit<SavedProperty, "id">) {
    const savedProperty = {
      ...input,
      id: nanoid(),
    };

    savedProperties.push(savedProperty);
    return savedProperty;
  },
  listConversations() {
    return conversations;
  },
  appendMessage(conversationId: string, senderId: string, body: string) {
    const conversation = conversations.find((entry) => entry.id === conversationId);
    if (!conversation) {
      throw new Error("Conversation not found");
    }

    conversation.messages.push({
      id: nanoid(),
      senderId,
      sentAt: new Date().toISOString(),
      body,
    });
    conversation.lastMessagePreview = body;
    conversation.unreadCount += 1;
    return conversation;
  },
  listInspectionBookings() {
    return inspectionBookings;
  },
  createInspectionBooking(input: Omit<InspectionBooking, "id" | "status">) {
    const booking: InspectionBooking = {
      ...input,
      id: nanoid(),
      status: "requested",
    };

    inspectionBookings.push(booking);
    return booking;
  },
  listOfferThreads() {
    return offerThreads;
  },
  createOfferThread(input: Omit<OfferThread, "id" | "lastUpdatedAt">) {
    const thread: OfferThread = {
      ...input,
      id: nanoid(),
      lastUpdatedAt: new Date().toISOString(),
    };

    offerThreads.push(thread);
    return thread;
  },
  counterOffer(threadId: string, version: OfferThread["versions"][number]) {
    const thread = offerThreads.find((entry) => entry.id === threadId);
    if (!thread) {
      throw new Error("Offer thread not found");
    }

    thread.versions.push(version);
    thread.status = "countered";
    thread.lastUpdatedAt = version.createdAt;
    return thread;
  },
  listServiceProviders() {
    return serviceProviders;
  },
  createUser(input: Pick<UserProfile, "displayName" | "email" | "role">) {
    const user: UserProfile = {
      ...input,
      id: nanoid(),
      verifiedEmail: false,
      verifiedPhone: false,
    };

    users.push(user);
    return user;
  },
  listUsers() {
    return users;
  },
  getAdminMetrics() {
    return sellerDashboardMetrics;
  },
};
