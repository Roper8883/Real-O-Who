import { describe, expect, it } from "vitest";
import {
  canTransitionListingStatus,
  canTransitionOfferStatus,
  getRequiredDocuments,
  getRuleSet,
} from "./engine";

describe("jurisdiction rules", () => {
  it("loads NSW publishing prerequisites", () => {
    const rules = getRuleSet("NSW");

    expect(rules.publishingPrerequisites[0]).toContain("lawful authority");
    expect(rules.featureFlags.contractRequiredBeforePublish).toBe(true);
  });

  it("marks ACT building reports as required", () => {
    const requirements = getRequiredDocuments("ACT");
    expect(requirements.some((item) => item.key === "building_report" && item.required)).toBe(true);
  });

  it("guards listing status transitions", () => {
    expect(canTransitionListingStatus("draft", "pending_compliance")).toBe(true);
    expect(canTransitionListingStatus("draft", "sold")).toBe(false);
  });

  it("guards offer status transitions", () => {
    expect(canTransitionOfferStatus("submitted", "countered")).toBe(true);
    expect(canTransitionOfferStatus("completed", "submitted")).toBe(false);
  });
});
