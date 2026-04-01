import { describe, expect, it } from "vitest";
import {
  calculateLaunchScore,
  getJurisdictionSnapshot,
  isReadyToPublish,
  publishBlockers,
  type ListingWizardDraft,
} from "./listing-wizard.logic";

const baseDraft: ListingWizardDraft = {
  addressLine: "16 Windsor Street",
  suburb: "Paddington",
  postcode: "2021",
  state: "NSW",
  propertyType: "house",
  bedrooms: "3",
  bathrooms: "2",
  parking: "1",
  landSize: "183",
  buildingSize: "162",
  askingPrice: "$2.45m",
  priceStrategy: "Private treaty",
  listingMode: "public",
  headline: "Renovated terrace with north-facing courtyard",
  description: "Calm, honest copy.",
  ownerLoves: "Morning light",
  mediaLinks: "https://example.com/front.jpg",
  floorplanLink: "https://example.com/floorplan.pdf",
  inspectionTimes: "Sat 10:30am open home",
  legalRepresentative: "Lumen Legal",
  sellerAuthorityConfirmed: true,
  contractReadyConfirmed: true,
  disclosureNotes: "Contract is ready.",
};

describe("listing wizard logic", () => {
  it("blocks publish when core trust fields are missing", () => {
    const blockers = publishBlockers({
      ...baseDraft,
      mediaLinks: "",
      sellerAuthorityConfirmed: false,
    });

    expect(blockers).toContain("At least one media asset is required.");
    expect(blockers).toContain("Seller authority must be confirmed.");
  });

  it("identifies a ready-to-publish draft", () => {
    expect(isReadyToPublish(baseDraft)).toBe(true);
    expect(calculateLaunchScore(baseDraft)).toBeGreaterThan(90);
  });

  it("returns rule-driven jurisdiction guidance", () => {
    const snapshot = getJurisdictionSnapshot("ACT");

    expect(snapshot.ruleSet.coolingOff.enabled).toBe(true);
    expect(snapshot.requiredDocuments.some((item) => item.key === "building_report")).toBe(true);
    expect(snapshot.offerWarnings.length).toBeGreaterThan(0);
  });
});
