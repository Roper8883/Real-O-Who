# Data Model Summary

## Modeling goals

- one source of truth for listings, offers, inspections, documents, and audits
- no ambiguity around listing or offer state transitions
- market-specific requirements represented as configuration plus explicit records
- auditability for every material state change

## Core entity groups

### Identity and trust

- `users`
- `user_identities`
- `verification_sessions`
- `seller_verifications`
- `buyer_preferences`
- `consent_records`
- `sessions`
- `device_history`

### Property and listing

- `properties`
- `property_addresses`
- `listings`
- `listing_versions`
- `listing_media`
- `floor_plans`
- `tours`
- `listing_access_rules`
- `disclosure_bundles`
- `documents`

### Buyer activity and CRM

- `favorites`
- `saved_searches`
- `alerts`
- `inquiries`
- `conversations`
- `messages`
- `message_attachments`

### Scheduling and inspections

- `inspections`
- `bookings`
- `attendance`
- `availability_windows`
- `reminders`

### Offers and closing workflow

- `offers`
- `counteroffers`
- `offer_conditions`
- `milestones`
- `signature_envelopes`
- `signatures`

### Platform and operations

- `audit_logs`
- `moderation_cases`
- `analytics_events`
- `provider_events`
- `jurisdiction_rules`
- `disclosure_templates`
- `legal_text_versions`
- `payment_plans`
- `invoices`
- `transactions`

## Modeling notes

- listing state and offer state must use explicit state machines
- audit entries should capture actor, action, entity type, entity id, diff payload, and trace id
- documents require role-based access and immutable metadata even when replaced by newer versions
- offers must remain clearly non-binding until downstream legal milestones mark otherwise

## Current repo status

The Prisma schema already covers a large portion of the required domain and is a strong base to extend. The next step is wiring repository and service layers so runtime flows persist these records instead of relying on in-memory fixtures.
