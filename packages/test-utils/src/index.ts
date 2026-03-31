import type { ListingDetail, SearchFilters } from "@homeowner/types";

export function createSearchFilters(
  overrides: Partial<SearchFilters> = {},
): SearchFilters {
  return {
    includeUnderOffer: true,
    sort: "newest",
    ...overrides,
  };
}

export function listingTitle(listing: ListingDetail): string {
  return `${listing.title} (${listing.address.suburb})`;
}
