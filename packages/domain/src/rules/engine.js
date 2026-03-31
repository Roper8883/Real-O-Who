import rawRules from "./au-private-treaty-rules.json" with { type: "json" };
const stateRules = new Map(rawRules.states.map((rule) => [
    rule.state,
    { ...rule, saleMethod: rawRules.saleMethod },
]));
const allowedTransitions = {
    draft: ["pending_compliance", "hidden"],
    pending_compliance: ["draft", "active", "hidden"],
    active: ["under_offer", "accepted_in_principle", "contract_requested", "hidden"],
    under_offer: ["active", "accepted_in_principle", "contract_requested", "sold"],
    accepted_in_principle: ["contract_requested", "under_offer", "sold"],
    contract_requested: ["accepted_in_principle", "exchanged", "sold"],
    exchanged: ["settled", "sold"],
    settled: ["sold"],
    sold: [],
    hidden: ["draft", "pending_compliance", "active"],
};
export function getRuleSet(state) {
    const ruleSet = stateRules.get(state);
    if (!ruleSet) {
        throw new Error(`No jurisdiction rule set found for ${state}`);
    }
    return ruleSet;
}
export function getRequiredDocuments(state, listing) {
    const ruleSet = getRuleSet(state);
    return ruleSet.requiredDocuments.map((document) => {
        if (document.key === "pool_certificate" && listing && !listing.facts.pool) {
            return {
                ...document,
                required: false,
                status: "optional",
            };
        }
        if (document.key === "body_corporate" &&
            listing &&
            listing.facts.bodyCorporateFeesQuarterly === undefined) {
            return {
                ...document,
                required: false,
                status: "optional",
            };
        }
        return document;
    });
}
export function getOfferWarnings(state) {
    return getRuleSet(state).offerWarnings;
}
export function canPublishListing(listing) {
    const blockers = [];
    for (const document of getRequiredDocuments(listing.address.state, listing)) {
        const uploaded = listing.documents.some((existingDocument) => existingDocument.category === document.key);
        if (document.required && !uploaded) {
            blockers.push(`${document.title} is required before publish.`);
        }
    }
    if (listing.status !== "draft" && listing.status !== "pending_compliance") {
        blockers.push("Listing must be in draft or pending compliance before publishing.");
    }
    return {
        allowed: blockers.length === 0,
        blockers,
    };
}
export function canTransitionListingStatus(currentStatus, nextStatus) {
    return allowedTransitions[currentStatus]?.includes(nextStatus) ?? false;
}
export function listFeatureFlags(state) {
    return getRuleSet(state).featureFlags;
}
