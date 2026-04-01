# AGENTS

## Product context

This repository powers a homeowner-led private property sale platform. The product must prioritize trust, clarity, speed, and market-aware compliance. It should never imply that the platform is providing legal advice, acting as a licensed agent, or holding transaction funds unless a clearly regulated mode has been introduced.

## Engineering principles

- reuse healthy monorepo boundaries already present in the repo
- prefer modular-monolith service boundaries over premature microservices
- keep market-specific logic configurable through rules, templates, and feature flags
- preserve auditability for listings, offers, documents, messaging, moderation, and support actions
- never route sensitive documents through public storage
- never present valuations, legal text, or compliance states as guaranteed truth

## UX principles

- mobile first
- one obvious primary action per screen
- plain-language copy
- progressive disclosure for advanced settings
- fast autosave flows for listing creation and offer flows
- accessible defaults for forms, focus, contrast, and hit targets

## Delivery rules

- ship in vertical slices
- update docs and tests with code changes
- document assumptions rather than blocking on minor uncertainty
- use provider abstractions for external services
- keep premium AI and partner-service features behind flags

## Repo guidance

- `apps/web` is the primary customer surface
- `apps/admin` is the internal operations surface
- `apps/api` is the orchestration layer
- `packages/domain` owns rules and business vocabulary
- `packages/db` owns schema and seeds
- `packages/ui` owns reusable primitives

## Current priority

Turn the existing foundation into a production-grade private-sale platform for Australia first, while keeping the jurisdiction layer extensible for future markets.
