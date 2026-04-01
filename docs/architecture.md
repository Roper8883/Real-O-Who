# Architecture Summary

## Chosen architecture

The repository will ship as a TypeScript modular monolith:

- `apps/web`: public marketplace and authenticated buyer/seller product
- `apps/admin`: internal operations console
- `apps/api`: API, orchestration, workflow rules, and provider coordination
- `packages/*`: shared domain, DB, config, auth, integrations, notifications, search, and UI

This is the right balance for the current repo because:

- it already contains healthy monorepo boundaries
- the product needs strong consistency across listings, offers, inspections, documents, and audits
- splitting services now would add operational cost without improving delivery speed

## Primary runtime responsibilities

### Web

- server-rendered public pages for performance and SEO
- authenticated buyer and seller dashboards
- listing wizard, messaging, inspections, offers, and document UX

### Admin

- moderation queue
- user verification review
- fraud, abuse, and audit review
- market rule configuration

### API

- auth and session orchestration
- listing lifecycle state machine
- messaging and CRM workflows
- inspection scheduling and reminders
- offer negotiation workflows
- document and disclosure access control
- analytics fan-out and audit logging

## Data and infra

- PostgreSQL is the system of record
- PostGIS will be enabled for geo search and map bounds
- Redis backs caching, rate limits, queues, and ephemeral coordination
- object storage handles media and private documents
- CDN serves public media
- signed URLs protect sensitive downloads

## Market layer

All market-sensitive behavior should resolve through configurable rule definitions:

- locale
- currency
- taxes and fees
- sale methods
- disclosure requirements
- privacy copy
- legal disclaimers
- offer steps
- listing states and optional milestones

Australia remains the default market, but the market layer must not assume Australia in every code path.

## Immediate engineering priorities

- replace fixture-backed writes with DB-backed repositories
- harden config and provider selection
- centralize structured logging and error handling
- formalize feature flags for risky flows and premium features
- keep the native iOS app as a lightweight companion rather than the source of truth
