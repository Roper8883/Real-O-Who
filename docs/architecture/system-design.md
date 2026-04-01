# System Design

## Monorepo structure

- `apps/web`: customer-facing marketplace
- `apps/admin`: internal operations console
- `apps/api`: API and service orchestration layer
- `packages/domain`: rules engine, shared fixtures, and business types
- `packages/db`: Prisma schema and seed
- `packages/auth`: auth, permissions, and credential helpers
- `packages/search`: filter parsing and search behavior
- `packages/notifications`: notification event helpers
- `packages/integrations`: provider adapter contracts
- `packages/ui`: shared UI primitives

## Runtime shape

- Next.js powers the web and admin surfaces.
- Fastify powers the API.
- PostgreSQL is the source of truth.
- Redis is reserved for caching, queues, and rate limiting.
- S3-compatible storage is used for media and document objects.
- A CDN/media transformation layer is expected in production.

## Design choices

- Shared domain logic avoids state-rule drift between API and UI.
- Separate admin and marketplace apps prevent internal workflows from leaking into customer-facing surfaces.
- The API is ready for provider adapters rather than hard-wiring external services directly into page code.
- Offers, messages, and disclosure states are modeled as auditable event streams rather than opaque status fields alone.
