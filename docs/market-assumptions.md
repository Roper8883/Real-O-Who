# Market Assumptions

## Inferred launch market

The repository clearly points to an Australia-first launch:

- Australia-specific listing copy and disclosure docs
- states and territories modeled directly in the domain
- `ap-southeast-2` defaults in environment configuration
- private treaty terminology and Australian property workflow language

## Launch assumptions

- country: Australia
- language: English
- currency: AUD
- property scope: residential sales
- primary model: homeowner-led private sales / off-market / invite-only listings
- sale method: private treaty required for the first production release

## Product boundary assumptions

- the platform is a marketplace and workflow tool
- the platform is not a real estate agent, law firm, escrow service, or trust account holder
- property transaction funds must stay outside the platform unless a compliant regulated partner is integrated later

## Market configuration requirements

The jurisdiction layer must be able to change:

- legal disclaimers
- disclosure bundles
- privacy notices
- fees and taxes
- supported currencies
- listing states
- offer workflows
- document templates
- retention rules
- consent text

## Expansion readiness

The repo should be structured so future markets can be added through configuration and provider adapters instead of forking the product:

- AU first
- NZ next
- UK/US only after legal workflow templates and fair-housing compliance rules are ready
