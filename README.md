# Homeowner

Australia-first private property sale platform for direct owner-to-buyer residential sales.

## What is here

- `apps/web`: buyer and seller marketplace
- `apps/admin`: admin, support, and compliance console
- `apps/api`: Fastify API service
- `packages/*`: shared domain, auth, search, database, notifications, integrations, test helpers, and UI
- `docs/*`: product, architecture, security, operations, API, legal, and help-centre drafts

## Local development

1. Copy `.env.example` to `.env`.
2. Start local infrastructure:
   - `docker-compose up -d`
3. Install dependencies:
   - `pnpm install`
4. Generate Prisma client:
   - `pnpm db:generate`
5. Run the apps:
   - `pnpm dev:web`
   - `pnpm dev:admin`
   - `pnpm dev:api`

## Quality gates

- `pnpm typecheck`
- `pnpm lint`
- `pnpm test`
- `pnpm build`

## Current scope

This foundation includes:

- state-aware listing and disclosure rules
- premium responsive marketplace and admin surfaces
- direct messaging, inspections, building and pest provider flows, and non-binding offers
- Prisma schema for the core platform entities
- rich demo data across NSW, VIC, QLD, SA, ACT, WA, TAS, and NT
- legal and help-centre draft documents

See [docs/README.md](/tmp/real-a-who-platform/docs/README.md) for the full documentation map.
