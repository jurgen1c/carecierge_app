---
id: vendor_discovery.marketplace_listings_are_curated_shared_content_with_private_explicit_handoffs
type: fact
system: vendor_discovery
status: current
confidence: verified
severity: critical

title: Marketplace listings are curated shared content with private explicit handoffs

claim: >
  Authenticated owners browse only published shared marketplace listings using
  bounded Ransack filters, twenty-item pages, and comparisons of at most five
  selected listings. Invalid comparison selections return localized recovery
  feedback and retain up to twenty checked options without JavaScript. App-curated descriptions and relationship/event use cases
  remain visibly separate from provider details with named credential-free
  HTTP(S) sources and reviewed dates; no application endpoint mutates the shared
  catalog or fetches external URLs. Saving locks the owner before the listing,
  rechecks publication, and reuses one private Vendor per owner/listing pair,
  enforced by a partial unique index. The private copy preserves name, category,
  service area, occasions and external attribution; later catalog changes do
  not overwrite it. Withdrawal hides shared listings while existing private
  vendor records remain available, and hard deletion nullifies only their
  listing link. Explicit owner-scoped handoffs open active plan vendor catalogs,
  with the selected vendor retained independently of plan search defaults,
  prefilled booking or gift drafts, and preselected new shortlists. Standalone
  gift drafts include the surrounding Turbo completion target. These GET
  requests persist nothing, and normal existing forms remain the confirmation
  boundary. English and Spanish workflows never contact, book, purchase, pay,
  or disclose relationship data externally. Catalog maintenance is an authorized
  maintainer workflow, not provider onboarding or a safety guarantee.

source_files:
  - app/models/marketplace_listing.rb
  - app/policies/marketplace_listing_policy.rb
  - app/controllers/marketplace_listings_controller.rb
  - app/services/marketplace_listings/save.rb
  - app/models/vendor.rb
  - app/controllers/vendors_controller.rb
  - app/controllers/bookings_controller.rb
  - app/controllers/gifts_controller.rb
  - app/controllers/vendor_shortlists_controller.rb
  - db/migrate/20260905125815_create_marketplace_listings.rb
  - config/routes.rb
related_files:
  - app/views/components/marketplace_listing_component.rb
  - app/views/components/marketplace_listing_component.html.erb
  - app/views/marketplace_listings/index.html.erb
  - app/views/marketplace_listings/show.html.erb
  - app/views/marketplace_listings/compare.html.erb
  - app/views/vendors/index.html.erb
  - app/views/gifts/new.html.erb
  - config/locales/marketplace.en.yml
  - config/locales/marketplace.es.yml
  - config/initializers/filter_parameter_logging.rb
  - docs/features/07-05-local-marketplace.md
  - spec/models/marketplace_listing_spec.rb
  - spec/requests/marketplace_listings_spec.rb
  - spec/services/marketplace_listings/save_spec.rb
  - spec/system/marketplace_listings_spec.rb
symbols:
  - MarketplaceListing
  - MarketplaceListingPolicy
  - MarketplaceListingsController
  - MarketplaceListings::Save
  - MarketplaceListingComponent
routes:
  - marketplace_listings
  - marketplace_listing
  - compare_marketplace_listings
  - save_marketplace_listing
  - use_marketplace_listing
tags:
  - vendor_discovery
  - marketplace
  - privacy
  - provenance
  - review_only
verification:
  - bundle exec rspec spec/models/marketplace_listing_spec.rb spec/requests/marketplace_listings_spec.rb spec/services/marketplace_listings/save_spec.rb spec/system/marketplace_listings_spec.rb
  - bin/memory validate
  - bin/memory audit --git-diff
  - bin/ci
last_verified_commit: 9231a3278f49d408ea7471d75e6b349fc7e91638
---

# Marketplace listings are curated shared content with private explicit handoffs

## Claim

Shared curation and provider claims are distinct from owner-controlled saved
vendor copies. Every downstream action enters an existing private review flow.

## Why It Matters

Catalog content must never be mistaken for trusted instructions, current
availability, tenant-private information, or authorization to transact.

## Evidence

- `app/models/marketplace_listing.rb`
- `app/controllers/marketplace_listings_controller.rb`
- `app/services/marketplace_listings/save.rb`
- `spec/requests/marketplace_listings_spec.rb`

## Verification

- `bundle exec rspec spec/models/marketplace_listing_spec.rb spec/requests/marketplace_listings_spec.rb spec/services/marketplace_listings/save_spec.rb spec/system/marketplace_listings_spec.rb`
- `bin/ci`
