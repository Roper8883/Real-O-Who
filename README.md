# Homeowner

Australia-first private property sale platform for direct owner-to-buyer residential sales, with a market layer designed to expand beyond Australia without rewriting core workflows.

## Repository layout

- `apps/web`: customer-facing marketplace and seller/buyer dashboard flows
- `apps/admin`: moderation, compliance, and operations console
- `apps/api`: Fastify modular-monolith API
- `packages/*`: shared domain, auth, config, DB, search, integrations, notifications, and UI
- `Real A Who/`: native iOS companion shell
- `docs/*`: product, architecture, market assumptions, security, operations, legal, and help content

## Start locally

1. Copy `.env.example` to `.env`
2. Start local services:
   - `docker-compose up -d`
3. Install dependencies:
   - `pnpm install`
4. Generate Prisma client:
   - `pnpm db:generate`
5. Run the web and API surfaces:
   - `pnpm dev:web`
   - `pnpm dev:admin`
   - `pnpm dev:api`
6. Optional native iOS shell:
   - open [Real A Who.xcodeproj](/Users/roper/Documents/Xcode%20Projects/Real%20A%20Who/Real%20A%20Who.xcodeproj) in Xcode

## Quality gates

- `pnpm lint`
- `pnpm typecheck`
- `pnpm test`
- `pnpm build`

## Core docs

- [docs/private-sale-master-plan.md](/Users/roper/Documents/Xcode%20Projects/Real%20A%20Who/docs/private-sale-master-plan.md)
- [docs/architecture.md](/Users/roper/Documents/Xcode%20Projects/Real%20A%20Who/docs/architecture.md)
- [docs/data-model.md](/Users/roper/Documents/Xcode%20Projects/Real%20A%20Who/docs/data-model.md)
- [docs/market-assumptions.md](/Users/roper/Documents/Xcode%20Projects/Real%20A%20Who/docs/market-assumptions.md)
- [docs/README.md](/Users/roper/Documents/Xcode%20Projects/Real%20A%20Who/docs/README.md)
