# Test Plan

## Unit tests

- rules engine state behavior and required document derivation
- auth validation and permission checks
- search serialization and filter behavior
- notification template helpers

## Integration tests

- API listing search
- saved property creation
- messaging and offer endpoints
- future Prisma-backed repository tests

## End-to-end priorities

- seller publishes state-compliant listing
- buyer finds listing and books inspection
- buyer requests building/pest pathway
- buyer makes offer and seller counters
- admin reviews flagged conversation
- account deletion request workflow

## Non-functional checks

- accessibility audits
- build-time verification
- performance budgets on search and property pages
- security linting and dependency review
