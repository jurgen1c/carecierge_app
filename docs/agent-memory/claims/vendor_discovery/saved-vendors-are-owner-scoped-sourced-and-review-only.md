---
id: vendor_discovery.saved_vendors_are_owner_scoped_sourced_and_review_only
type: fact
system: vendor_discovery
status: current
confidence: high
severity: critical

title: Saved vendors are owner-scoped, sourced, and review-only

claim: >
  Authenticated owners maintain a private saved-vendor catalog whose records are
  scoped through VendorPolicy, bounded at validation and query boundaries, and
  attributed either to manual entry or to a named external source with an
  optional validated HTTP(S) URL. Vendor fit notes are encrypted, and private
  vendor form and search inputs are filtered from request logs. Owners can
  search their saved catalog by text, category, location, occasion, preference,
  budget, and timing; event-plan context supplies occasion and budget defaults
  that submitted blank filters can explicitly clear.
  A vendor can be attached only to an active event plan owned by the same user;
  attachment and detachment serialize under the plan mutation lock and reload
  activity before mutating the join. Attaching, detaching, saving, editing, or
  deleting never contacts, books, purchases from, or otherwise acts through a
  vendor. Account exports include
  decrypted vendor details, provenance, and event-plan attachments, while
  ownership foreign keys cascade through account deletion. The surface is
  available in English and Spanish. External provider discovery and vendor
  self-registration remain separate future integrations.

source_files:
  - app/models/vendor.rb
  - app/models/event_plan_vendor.rb
  - app/queries/vendors/search_query.rb
  - app/controllers/vendors_controller.rb
  - app/controllers/event_plan_vendors_controller.rb
  - app/services/event_plan_vendors/attach.rb
  - app/services/event_plan_vendors/detach.rb
  - app/policies/vendor_policy.rb
  - db/migrate/20260901120000_create_vendors_and_event_plan_vendors.rb

related_files:
  - app/controllers/event_plans_controller.rb
  - app/models/event_plan.rb
  - app/models/user.rb
  - app/serializers/data_exports/snapshot.rb
  - app/views/components/event_plan_workspace_component.rb
  - app/views/components/event_plan_workspace_component.html.erb
  - app/views/components/vendor_result_component.rb
  - app/views/components/vendor_result_component.html.erb
  - app/views/event_plans/show.html.erb
  - app/views/vendors/index.html.erb
  - config/initializers/filter_parameter_logging.rb
  - config/locales/event_plans.en.yml
  - config/locales/event_plans.es.yml
  - config/locales/vendors.en.yml
  - config/locales/vendors.es.yml
  - config/routes.rb
  - docs/features/07-01-vendor-discovery.md
  - spec/models/vendor_spec.rb
  - spec/components/event_plan_workspace_component_spec.rb
  - spec/queries/vendors/search_query_spec.rb
  - spec/policies/vendor_policy_spec.rb
  - spec/requests/vendors_spec.rb
  - spec/requests/data_controls_spec.rb
  - spec/services/event_plan_vendors/attach_spec.rb
  - spec/services/event_plan_vendors/detach_spec.rb
  - spec/config/filter_parameter_logging_spec.rb
symbols:
  - Vendor
  - EventPlanVendor
  - Vendors::SearchQuery
  - VendorsController
  - EventPlanVendorsController
  - VendorPolicy
  - VendorResultComponent
routes:
  - vendors
  - new_vendor
  - edit_vendor
  - event_plan_vendors
  - event_plan_vendor
tags:
  - vendor_discovery
  - event_plans
  - privacy
  - source_provenance
  - review_only
  - localization

verification:
  - bundle exec rspec spec/models/vendor_spec.rb spec/queries/vendors/search_query_spec.rb spec/policies/vendor_policy_spec.rb spec/components/vendor_result_component_spec.rb spec/components/event_plan_workspace_component_spec.rb spec/requests/vendors_spec.rb spec/requests/data_controls_spec.rb spec/services/event_plan_vendors/attach_spec.rb spec/services/event_plan_vendors/detach_spec.rb spec/config/filter_parameter_logging_spec.rb
  - bin/rubocop
  - bin/memory validate
  - bin/memory coverage --git-diff
  - bin/memory audit --git-diff
  - bin/ci

last_verified_commit: null
---

# Saved vendors are owner-scoped, sourced, and review-only

## Claim

Carecierge provides an owner-scoped shortlist of sourced vendor records that can
be searched independently or in the context of an active event plan. Saving and
attaching records remains a planning action only; it does not contact or transact
with a vendor.

## Why It Matters

Vendor data introduces untrusted external provenance and a future commerce
boundary. Keeping ownership, source attribution, and the no-external-action rule
explicit prevents cross-account exposure and avoids implying that a saved option
has been contacted, booked, or purchased.

## Evidence

- `app/models/vendor.rb`
- `app/models/event_plan_vendor.rb`
- `app/controllers/vendors_controller.rb`
- `app/controllers/event_plan_vendors_controller.rb`
- `app/queries/vendors/search_query.rb`
- `spec/requests/vendors_spec.rb`

## Verification

- `bundle exec rspec spec/models/vendor_spec.rb spec/queries/vendors/search_query_spec.rb spec/policies/vendor_policy_spec.rb spec/components/vendor_result_component_spec.rb spec/components/event_plan_workspace_component_spec.rb spec/requests/vendors_spec.rb spec/requests/data_controls_spec.rb spec/services/event_plan_vendors/attach_spec.rb spec/services/event_plan_vendors/detach_spec.rb spec/config/filter_parameter_logging_spec.rb`
- `bin/rubocop`
- `bin/memory validate`
- `bin/memory coverage --git-diff`
- `bin/memory audit --git-diff`
- `bin/ci`
