# 7.1 Vendor Discovery

**Area:** 7. Vendor, Booking, and Marketplace Layer

Carecierge provides a private, owner-scoped vendor shortlist that can be searched
on its own or opened from an active event plan. The current provider-neutral MVP
uses vendor records saved by the user; external discovery providers can populate
the same sourced records in a later integration.

## Vendor Categories

- Restaurants
- Florists
- Bakeries
- Caterers
- Private chefs
- Photographers
- Venues
- Musicians
- Entertainers
- Decorators
- Gift shops
- Local artisans
- Spas
- Tour operators
- Transportation
- Childcare
- Party rentals

## Current Capabilities

- Search saved vendors by name and source details.
- Filter by category, location, occasion, preference, budget, and timing.
- Use an event plan's occasion and budget as search defaults.
- Explain fit from an encrypted owner-authored note or matched criteria.
- Save and edit manual or externally sourced vendor records. A saved vendor can
  be deleted after the owner removes it from every comparison, preserving any
  comparison notes and decisions until that explicit removal.
- Attribute external records to a named source and optional validated HTTP(S)
  source URL.
- Attach or detach a saved vendor from an active event plan owned by the same
  user.
- Export saved vendor details, provenance, and plan attachments with account
  data.
- Present the complete workflow in English and Spanish.

Saving or attaching a vendor is review-only. Carecierge does not contact, book,
purchase from, pay, or otherwise act through a vendor.

## Data Objects

- `Vendor`
- `EventPlanVendor`

## Implementation Notes

The current search is intentionally provider-neutral and queries only the
authenticated owner's saved catalog. Commerce and booking provider integration
is tracked separately in CAR-74. Vendor registration and management of
marketplace profiles is tracked separately in CAR-83.
