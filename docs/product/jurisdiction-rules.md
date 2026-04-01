# Jurisdiction Rules

## Design approach

The product uses a data-driven rules engine keyed by:

- country
- state or territory
- sale method
- property type
- listing mode

Each rule set defines:

- publishing prerequisites
- required and recommended documents
- cooling-off messaging
- offer warnings
- inspection guidance
- settlement defaults
- feature flags

## State summaries

- `NSW`: contract of sale prepared before advertising, pool/certificate prompts, exchange and cooling-off milestone support.
- `VIC`: Section 32 required before signing, private sale cooling-off messaging, conditional offer support.
- `QLD`: seller disclosure bundle and proof of delivery, planning/contamination/heritage/pool/body corporate prompts.
- `SA`: Form 1 workflow, amendment notice support, service-date tracking.
- `ACT`: draft contract before sale, seller-provided building and pest report workflow, reimbursement metadata.
- `NT`: approved contract-form placeholder, cooling-off support, offer-to-contract progression.
- `WA`: no default statutory cooling-off, strong emphasis on finance/building/pest/sale-of-home conditions.
- `TAS`: buyer-beware presentation, no implied disclosure obligations beyond applicable law, due diligence prompts.

## Admin guidance

Rules should be editable without widespread code changes. Product logic reads rule content centrally and exposes it to the listing wizard, property detail page, offer flow, document centre, and admin console.
