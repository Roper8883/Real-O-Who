# Data Model

## Core entities

- `User`, `SellerVerification`, `BuyerPreference`, `ConsentRecord`, `Session`, `DeviceHistory`
- `Property`, `PropertyAddress`, `Listing`, `ListingMedia`, `PropertyDocument`, `DisclosureBundle`
- `Conversation`, `Message`, `Attachment`, `ReadReceipt`, `AbuseReport`, `ModerationAction`
- `InspectionSlot`, `InspectionBooking`, `InspectionReminder`, `InspectionOrder`, `InspectionReport`
- `OfferThread`, `OfferVersion`, `OfferCondition`, `OfferEvidence`, `OfferStatusEvent`
- `SavedProperty`, `SavedSearch`, `SearchAlert`, `Notification`, `AuditLog`, `FeatureFlag`, `RuleSet`

## Modeling principles

- All important actions need timestamps.
- Legal-finality steps are never implied by offer records alone.
- Jurisdiction-specific requirements live in data instead of scattered conditionals.
- Documents and messages are audit-friendly and role-aware.
- Soft delete is preferred for core records with compliance implications.

## Persistence strategy

- PostgreSQL stores canonical data.
- JSON fields are used where requirements are state-specific or evolve rapidly, but major workflows still have first-class tables.
- Media objects live in object storage with signed URL access.
