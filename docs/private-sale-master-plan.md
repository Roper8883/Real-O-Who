# Private Sale Master Plan

## Mission

Transform `Real A Who` from a lightweight private-sale prototype into a production-ready homeowner-led property transaction platform that feels calm, transparent, and materially safer than a typical FSBO tool.

The product should help:

- sellers list and manage private sales without behaving like a licensed agent
- buyers search, compare, inquire, book, and offer with trust signals throughout
- admins moderate, audit, configure markets, and support users

## Current repo audit

### Healthy assets worth reusing

- `apps/web`: premium-feeling marketplace shell with buyer and seller routes
- `apps/admin`: early back-office shell for listings, rules, users, and reports
- `apps/api`: modular Fastify API entry point with route registration
- `packages/domain`: Australia-first listings, rules engine, and demo data
- `packages/db`: strong initial Prisma schema covering users, listings, offers, documents, notifications, and auditability
- `docs/*`: unusually complete product, legal, and operations drafting for this stage
- `docker-compose.yml` and `.github/workflows/ci.yml`: local infra and baseline CI already in place
- `Real A Who/`: native iOS shell that can act as a companion demo surface

### Gaps that block a production launch

- runtime data is still fixture-backed in the API instead of fully database-backed
- auth is only a schema and permission helper, not a real identity system
- provider abstractions exist, but concrete adapters and selection logic are thin
- observability is not centralized yet
- feature flags are interface-level only
- seller/buyer journeys are mostly UI scaffolds and demo flows, not persisted end-to-end workflows
- no real migration history or deployment infrastructure code yet
- no persisted background job layer for media, reminders, moderation, and notifications

## Target market assumptions

- default launch market: Australia
- default currency: AUD
- default sale method: private treaty / private sale
- default property class: residential
- default legal workflow stance: the platform coordinates actions but does not provide legal advice, hold trust funds, or act as an agent

Jurisdiction configuration must remain data-driven so the same product can later support the UK, New Zealand, the US, or region-specific submarkets without rewriting core workflows.

## Delivery strategy

### Phase 1: foundations

- promote the TypeScript monorepo as the primary product architecture
- keep the iOS shell as a companion surface, not the system of record
- finalize env validation, logging, feature flags, and provider registries
- create missing top-level planning docs and operator guidance
- clean generated files and repo hygiene issues

### Phase 2: seller MVP vertical slice

- seller signup shell and onboarding state
- listing wizard with autosave draft progression
- media upload abstraction
- preview and publish workflow
- seller dashboard tasks, status, and compliance panel

### Phase 3: buyer MVP vertical slice

- search and map/list browsing
- property detail page with sticky CTAs
- save/share/compare foundation
- inquiry flow with masked contact rules

### Phase 4: conversion

- inspection scheduling and booking
- conversation threads and seller CRM stages
- offers, comparison, countering, and milestone timeline

### Phase 5: compliance and trust

- disclosures, document requests, and audit metadata
- e-sign abstraction and consent capture
- moderation rules, anti-discrimination guardrails, fraud hooks

### Phase 6: commercialization and operations

- listing plans, billing, receipts, and partner services
- production deploys, backups, dashboards, alerts, and release runbook

## Non-negotiables

- no custody of property transaction funds in v1
- no misleading legal or valuation certainty
- no public storage for sensitive documents or PII
- all material state changes must be auditable
- market rules must be configurable, not buried across UI conditionals

## Success bar

- clean clone can run locally with documented commands
- seller and buyer critical paths are functional end-to-end using persisted data
- admin can review moderation and audit history
- staging deployment is reproducible from CI
- legal, ops, and architecture docs are accurate enough for a small team to operate from
