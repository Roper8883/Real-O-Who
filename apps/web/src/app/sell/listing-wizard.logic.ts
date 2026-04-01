import {
  getOfferWarnings,
  getRequiredDocuments,
  getRuleSet,
} from "@homeowner/domain";
import type {
  AustralianState,
  ListingDocumentRequirement,
  RuleSet,
} from "@homeowner/types";

export type ListingMode =
  | "public"
  | "off_market"
  | "invite_only"
  | "password_protected"
  | "coming_soon";

export type PropertyType = "house" | "townhouse" | "apartment" | "land" | "acreage";
export type StateCode = AustralianState;

export interface ListingWizardDraft {
  addressLine: string;
  suburb: string;
  postcode: string;
  state: StateCode;
  propertyType: PropertyType;
  bedrooms: string;
  bathrooms: string;
  parking: string;
  landSize: string;
  buildingSize: string;
  askingPrice: string;
  priceStrategy: string;
  listingMode: ListingMode;
  headline: string;
  description: string;
  ownerLoves: string;
  mediaLinks: string;
  floorplanLink: string;
  inspectionTimes: string;
  legalRepresentative: string;
  sellerAuthorityConfirmed: boolean;
  contractReadyConfirmed: boolean;
  disclosureNotes: string;
  lastPublishedAt?: string;
}

export function labelForListingMode(listingMode: ListingMode) {
  switch (listingMode) {
    case "public":
      return "Public listing";
    case "off_market":
      return "Off-market";
    case "invite_only":
      return "Invite only";
    case "password_protected":
      return "Password-protected data room";
    case "coming_soon":
      return "Coming soon";
  }
}

export function publishBlockers(draft: ListingWizardDraft) {
  const blockers: string[] = [];

  if (!draft.addressLine || !draft.suburb || !draft.postcode) {
    blockers.push("Address details are incomplete.");
  }

  if (!draft.headline || !draft.description) {
    blockers.push("Headline and description are required.");
  }

  if (!draft.askingPrice) {
    blockers.push("Price guide is missing.");
  }

  if (!draft.mediaLinks) {
    blockers.push("At least one media asset is required.");
  }

  if (!draft.inspectionTimes) {
    blockers.push("At least one inspection slot or scheduling note is required.");
  }

  if (!draft.sellerAuthorityConfirmed) {
    blockers.push("Seller authority must be confirmed.");
  }

  if (!draft.contractReadyConfirmed) {
    blockers.push("Contract or disclosure readiness confirmation is still missing.");
  }

  return blockers;
}

export function isReadyToPublish(draft: ListingWizardDraft) {
  return publishBlockers(draft).length === 0;
}

export function calculateLaunchScore(draft: ListingWizardDraft) {
  const blockers = publishBlockers(draft).length;
  const bonus =
    (draft.ownerLoves ? 5 : 0) +
    (draft.floorplanLink ? 5 : 0) +
    (draft.legalRepresentative ? 5 : 0) +
    (draft.disclosureNotes ? 5 : 0);

  return Math.max(0, Math.min(100, 100 - blockers * 15 + bonus));
}

export function getJurisdictionSnapshot(state: AustralianState): {
  ruleSet: RuleSet;
  requiredDocuments: ListingDocumentRequirement[];
  offerWarnings: string[];
} {
  return {
    ruleSet: getRuleSet(state),
    requiredDocuments: getRequiredDocuments(state),
    offerWarnings: getOfferWarnings(state),
  };
}
