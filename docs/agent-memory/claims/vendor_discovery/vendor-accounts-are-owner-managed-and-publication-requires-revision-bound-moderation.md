---
id: vendor_discovery.vendor_accounts_are_owner_managed_and_publication_requires_revision_bound_moderation
type: constraint
system: vendor_discovery
status: current
confidence: high
severity: critical
title: Vendor accounts are owner managed and publication requires revision bound moderation
claim: >
  Confirmed Devise users enroll once into a UUID VendorAccount distinct from private saved Vendor and RelationshipProfiles::Vendor records. Owner-scoped native forms save bounded business identity, up to five categories, a 200-character combined service area, offerings, public contact channels and credential-free HTTP(S) provenance. The first category is the catalog filter category. Enrollment holds the owner lock and has a unique database owner key. Owner/account/listing lock order and mandatory optimistic versions serialize edits, submission and moderator decisions. Only user.admin? moderators approve submitted content, reject it with a reason, or suspend approved publication with a reason. Approval writes a shared MarketplaceListing snapshot explicitly labeled vendor-supplied; approved or submitted edits return to draft and withdraw publication. Rejected profiles can be corrected and resubmitted, while suspended profiles may be edited but cannot self-resubmit. Every status change appends encrypted profile and reason evidence with actor, timestamp and revision. Review records are readonly after persistence; failure to persist evidence rolls back both state and publication. Validation recovery retains the moderator decision/reason and restores persisted publication status while keeping invalid owner input. Owner/admin pages disable HTTP and Turbo snapshot caching and paginate review history and the admin queue twenty at a time. Vendor routes query only business records and grant no consumer-private authority. English and Spanish forms support no-JavaScript submission, labeled errors and visible keyboard focus. Request and model attributes are filtered from logs. Account exports include decrypted business and review data without moderator IDs; profile-only exports exclude it. Account deletion cascades business/review/listing data while consumer saved snapshots remain with a null listing link. No quotes, bookings, payments, provider synchronization or external contact occurs.
source_files:
  - app/models/vendor_account.rb
  - app/models/vendor_account_review.rb
  - app/models/user.rb
  - app/models/marketplace_listing.rb
  - app/policies/vendor_account_policy.rb
  - app/services/vendor_accounts/enroll.rb
  - app/services/vendor_accounts/save.rb
  - app/services/vendor_accounts/transition.rb
  - app/controllers/vendor_accounts_controller.rb
  - app/controllers/admin/vendor_accounts_controller.rb
  - app/serializers/data_exports/snapshot.rb
  - app/services/data_exports/prepare.rb
  - config/routes.rb
  - config/initializers/filter_parameter_logging.rb
  - app/views/vendor_accounts/show.html.erb
  - app/views/vendor_accounts/_pagination.html.erb
  - app/views/admin/vendor_accounts/index.html.erb
  - app/views/admin/vendor_accounts/show.html.erb
  - app/views/admin/dashboard/show.html.erb
  - app/views/components/vendor_account_profile_component.rb
  - app/views/components/vendor_account_profile_component.html.erb
  - app/views/components/vendor_account_history_component.rb
  - app/views/components/vendor_account_history_component.html.erb
  - app/views/components/marketplace_listing_component.html.erb
  - app/views/marketplace_listings/index.html.erb
  - config/locales/vendor_accounts.en.yml
  - config/locales/vendor_accounts.es.yml
  - db/migrate/20260906044421_create_vendor_accounts.rb
  - db/schema.rb
  - spec/models/vendor_account_spec.rb
  - spec/services/vendor_accounts/lifecycle_spec.rb
  - spec/requests/vendor_accounts_spec.rb
  - spec/policies/vendor_account_policy_spec.rb
  - spec/components/vendor_account_profile_component_spec.rb
  - spec/system/vendor_accounts_spec.rb
  - spec/factories/vendor_accounts.rb
  - docs/features/07-05-local-marketplace.md
symbols:
  - VendorAccount
  - VendorAccountReview
  - VendorAccounts::Enroll
  - VendorAccounts::Save
  - VendorAccounts::Transition
routes:
  - GET /vendor_account
  - POST /vendor_account
  - PATCH /vendor_account
  - POST /vendor_account/submit
  - GET /admin/vendor_accounts
  - GET /admin/vendor_accounts/:id
  - PATCH /admin/vendor_accounts/:id
tags:
  - vendor_discovery
  - ownership
  - moderation
  - publication
verification:
  - bundle exec rspec spec/services/vendor_accounts spec/models/vendor_account_spec.rb spec/requests/vendor_accounts_spec.rb spec/policies/vendor_account_policy_spec.rb spec/components/vendor_account_profile_component_spec.rb spec/system/vendor_accounts_spec.rb spec/requests/marketplace_listings_spec.rb
  - bin/memory validate
  - bin/memory coverage --git-diff
  - bin/ci
last_verified_commit: 330108f04efe6e63525a71603a6215f53fa1212a
---

# Vendor account moderation and ownership

## Claim

One confirmed owner has one UUID business aggregate, separate from private saved vendors and relationship records. Required optimistic revisions plus owner/account/listing locks protect edits, submission and moderation. Admin approval publishes a reviewed shared snapshot; editing approved or submitted content withdraws it. Rejection requires a reason and permits resubmission. Suspension requires a reason and cannot be lifted by owner edits. Encrypted append-only transition evidence rolls back atomically with failed state/publication changes. Vendor routes grant no consumer-private access. English and Spanish native forms remain usable without JavaScript. Account export includes business evidence; account deletion removes publication while preserving consumers' private saved snapshots.

## Why It Matters

Vendor identity must never become a path into consumer relationship data, and edited content must never inherit approval from an older revision.

## Verification

Run the focused command above and the full repository gate. Account erasure intentionally removes review content; rejection and suspension retain it for the account lifetime. Suspension restoration is not exposed in this delivery.

The vendor request spec also verifies integration with `relationship_profiles.privacy_vault`: ordinary account exports retain business evidence while omitting protected memories; sensitive exports require fresh MFA for enrolled owners, reject factor replay, and never include MFA secrets. The shared export boundary remains owned by `data_controls.data_portability_and_deletion`.
