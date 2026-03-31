import { describe, expect, it } from "vitest";
import { listings } from "@homeowner/domain";
import { applyListingFilters, deserializeSearchFilters, serializeSearchFilters } from "./index.js";

describe("search package", () => {
  it("serializes and deserializes filters", () => {
    const query = serializeSearchFilters({
      state: "QLD",
      pool: true,
      minBedrooms: 4,
      propertyTypes: ["house"],
    });

    const parsed = deserializeSearchFilters(query);
    expect(parsed.state).toBe("QLD");
    expect(parsed.propertyTypes).toEqual(["house"]);
  });

  it("filters listings by state and amenities", () => {
    const filtered = applyListingFilters(listings, {
      state: "QLD",
      pool: true,
      minBedrooms: 4,
      includeUnderOffer: true,
    });

    expect(filtered.length).toBe(1);
    expect(filtered[0]?.address.state).toBe("QLD");
  });
});
