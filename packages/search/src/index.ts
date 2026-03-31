import type { ListingSummary, SearchFilters } from "@homeowner/types";
import { z } from "zod";

export const searchFiltersSchema = z.object({
  query: z.string().optional(),
  state: z
    .enum(["NSW", "VIC", "QLD", "SA", "ACT", "NT", "WA", "TAS"])
    .optional(),
  suburb: z.string().optional(),
  postcode: z.string().optional(),
  propertyTypes: z
    .array(z.enum(["house", "townhouse", "apartment", "land", "acreage", "strata_home"]))
    .optional(),
  minPrice: z.coerce.number().optional(),
  maxPrice: z.coerce.number().optional(),
  minBedrooms: z.coerce.number().optional(),
  minBathrooms: z.coerce.number().optional(),
  parking: z.coerce.number().optional(),
  hasVideo: z.coerce.boolean().optional(),
  hasFloorplan: z.coerce.boolean().optional(),
  hasDocuments: z.coerce.boolean().optional(),
  sellerVerified: z.coerce.boolean().optional(),
  openHomeOnly: z.coerce.boolean().optional(),
  includeUnderOffer: z.coerce.boolean().optional(),
  pool: z.coerce.boolean().optional(),
  study: z.coerce.boolean().optional(),
  outdoorArea: z.coerce.boolean().optional(),
  accessibilityFeature: z.string().optional(),
  sort: z
    .enum(["relevance", "newest", "price_asc", "price_desc", "land_desc"])
    .optional(),
});

export function serializeSearchFilters(filters: SearchFilters): string {
  const params = new URLSearchParams();

  Object.entries(filters).forEach(([key, value]) => {
    if (value === undefined || value === null) {
      return;
    }

    if (Array.isArray(value)) {
      params.set(key, value.join(","));
      return;
    }

    params.set(key, String(value));
  });

  return params.toString();
}

export function deserializeSearchFilters(queryString: string): SearchFilters {
  const params = Object.fromEntries(
    new URLSearchParams(queryString).entries(),
  ) as Record<string, string | string[]>;

  if (params.propertyTypes) {
    params.propertyTypes = String(params.propertyTypes).split(",");
  }

  return searchFiltersSchema.parse(params) as SearchFilters;
}

export function applyListingFilters(
  listings: ListingSummary[],
  filters: SearchFilters,
): ListingSummary[] {
  return listings
    .filter((listing) => {
      if (filters.state && listing.address.state !== filters.state) {
        return false;
      }

      if (
        filters.query &&
        !`${listing.title} ${listing.address.suburb}`
          .toLowerCase()
          .includes(filters.query.toLowerCase())
      ) {
        return false;
      }

      if (filters.suburb && listing.address.suburb !== filters.suburb) {
        return false;
      }

      if (filters.propertyTypes?.length && !filters.propertyTypes.includes(listing.propertyType)) {
        return false;
      }

      if (filters.minPrice && (!listing.askingPrice || listing.askingPrice < filters.minPrice)) {
        return false;
      }

      if (filters.maxPrice && (!listing.askingPrice || listing.askingPrice > filters.maxPrice)) {
        return false;
      }

      if (filters.minBedrooms && listing.facts.bedrooms < filters.minBedrooms) {
        return false;
      }

      if (filters.minBathrooms && listing.facts.bathrooms < filters.minBathrooms) {
        return false;
      }

      if (filters.parking && listing.facts.carSpaces < filters.parking) {
        return false;
      }

      if (filters.openHomeOnly && !listing.inspectionSlots.some((slot) => slot.type === "open_home")) {
        return false;
      }

      if (filters.hasDocuments && listing.legalDisclosureStatus === "not_started") {
        return false;
      }

      if (filters.sellerVerified && !listing.sellerVerified) {
        return false;
      }

      if (!filters.includeUnderOffer && listing.status === "under_offer") {
        return false;
      }

      if (filters.pool && !listing.facts.pool) {
        return false;
      }

      if (filters.study && !listing.facts.study) {
        return false;
      }

      if (filters.outdoorArea && !listing.facts.outdoorArea) {
        return false;
      }

      if (
        filters.accessibilityFeature &&
        !listing.facts.accessibilityFeatures.includes(filters.accessibilityFeature)
      ) {
        return false;
      }

      return true;
    })
    .sort((left, right) => {
      switch (filters.sort) {
        case "price_asc":
          return (left.askingPrice ?? Number.MAX_SAFE_INTEGER) - (right.askingPrice ?? Number.MAX_SAFE_INTEGER);
        case "price_desc":
          return (right.askingPrice ?? 0) - (left.askingPrice ?? 0);
        case "land_desc":
          return (right.facts.landSizeSqm ?? 0) - (left.facts.landSizeSqm ?? 0);
        case "newest":
        default:
          return new Date(right.publishedAt).getTime() - new Date(left.publishedAt).getTime();
      }
    });
}
