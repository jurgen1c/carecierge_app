---
id: vendor_discovery.vendor_comparisons_are_owner_scoped_bounded_and_explicitly_decided
type: fact
system: vendor_discovery
status: current
confidence: verified
severity: critical

title: Vendor comparisons are owner-scoped, bounded, and explicitly decided

claim: >
  Authenticated owners create encrypted vendor shortlists for one active
  relationship or optional active event plan; plan context is authoritative for
  the relationship. Each shortlist contains at most five same-owner saved
  vendors and compares price, availability, location, fit, encrypted owner notes,
  encrypted constraints, encrypted next action, and preserved vendor source
  attribution. Favorites remain independent from explicit considering, rejected,
  and selected states. Selecting an option transactionally returns any prior
  selection to consideration, while a partial unique index enforces at most one
  selected option. Creation and mutation revalidate owner and active-context
  boundaries under ordered owner, relationship, optional plan, shortlist, and
  option locks, and vendor IDs are re-resolved from the owner's catalog inside
  the owner lock before options are persisted. Owner-authored comparison detail
  forms carry a required optimistic revision and reject stale submissions
  instead of overwriting newer private notes. Completed- or archived-plan
  shortlists and archived-relationship shortlists remain owner-readable;
  comparison details and decisions become read-only while explicit option
  removal remains available. The owner index is paginated twenty shortlists at
  a time. Private shortlist pages are excluded from Turbo's snapshot cache. The
  responsive comparison region is keyboard-focusable, and the no-JavaScript
  English and Spanish workflow is review-only and never contacts, books,
  purchases from, pays, or otherwise acts through a vendor. A saved vendor
  cannot be deleted while it belongs to a comparison, preserving private notes
  and decisions until the owner explicitly removes the option. Owner-authorized
  exports include decrypted comparison data, decisions, and embedded vendor
  provenance; ownership foreign keys cascade on account or context deletion.

source_files:
  - app/models/vendor_shortlist.rb
  - app/models/vendor_option.rb
  - app/services/vendor_shortlists/create.rb
  - app/services/vendors/destroy.rb
  - app/controllers/vendor_shortlists_controller.rb
  - app/controllers/vendor_options_controller.rb
  - app/policies/vendor_shortlist_policy.rb
  - app/policies/vendor_option_policy.rb
  - db/migrate/20260902145635_create_vendor_shortlists_and_options.rb

related_files:
  - app/models/user.rb
  - app/models/relationship_profile.rb
  - app/models/event_plan.rb
  - app/models/vendor.rb
  - app/serializers/data_exports/snapshot.rb
  - app/views/components/vendor_shortlist_comparison_component.rb
  - app/views/components/vendor_shortlist_comparison_component.html.erb
  - app/views/components/event_plan_workspace_component.html.erb
  - app/views/vendor_shortlists/index.html.erb
  - app/views/vendor_shortlists/new.html.erb
  - app/views/vendor_shortlists/_form.html.erb
  - app/views/vendor_shortlists/show.html.erb
  - config/initializers/filter_parameter_logging.rb
  - config/locales/vendor_shortlists.en.yml
  - config/locales/vendor_shortlists.es.yml
  - config/locales/event_plans.en.yml
  - config/locales/event_plans.es.yml
  - config/routes.rb
  - docs/features/07-02-vendor-shortlisting-and-comparison.md
  - spec/models/vendor_shortlist_spec.rb
  - spec/models/vendor_option_spec.rb
  - spec/services/vendor_shortlists/create_spec.rb
  - spec/policies/vendor_shortlist_policy_spec.rb
  - spec/components/vendor_shortlist_comparison_component_spec.rb
  - spec/requests/vendor_shortlists_spec.rb
  - spec/requests/vendors_spec.rb
  - spec/services/vendors/destroy_spec.rb
  - spec/requests/data_controls_spec.rb
  - spec/config/filter_parameter_logging_spec.rb
  - spec/system/vendor_shortlists_spec.rb
symbols:
  - VendorShortlist
  - VendorOption
  - VendorShortlists::Create
  - VendorShortlistsController
  - VendorOptionsController
  - VendorShortlistPolicy
  - VendorOptionPolicy
  - VendorShortlistComparisonComponent
routes:
  - vendor_shortlists
  - new_vendor_shortlist
  - vendor_shortlist
  - vendor_shortlist_vendor_options
  - vendor_shortlist_vendor_option
  - favorite_vendor_shortlist_vendor_option
  - reject_vendor_shortlist_vendor_option
  - select_vendor_shortlist_vendor_option
  - restore_vendor_shortlist_vendor_option
tags:
  - vendor_discovery
  - event_plans
  - privacy
  - source_provenance
  - review_only
  - localization

verification:
  - bundle exec rspec spec/models/vendor_shortlist_spec.rb spec/models/vendor_option_spec.rb spec/services/vendor_shortlists/create_spec.rb spec/policies/vendor_shortlist_policy_spec.rb spec/components/vendor_shortlist_comparison_component_spec.rb spec/requests/vendor_shortlists_spec.rb spec/system/vendor_shortlists_spec.rb
  - bundle exec rspec spec/requests/data_controls_spec.rb spec/config/filter_parameter_logging_spec.rb spec/components/event_plan_workspace_component_spec.rb spec/requests/vendors_spec.rb
  - bun run build:css
  - bin/rubocop
  - bin/memory validate
  - bin/memory coverage --git-diff
  - bin/memory audit --git-diff
  - bin/ci

last_verified_commit: 6649e99218e57519a24dde95af0d989ce2ff048d
---

# Vendor comparisons are owner-scoped, bounded, and explicitly decided

## Claim

Owners can compare a small, source-backed set of saved vendors for one
relationship or active event plan, preserve private decision context, and make
one explicit selection without triggering external action.

## Why It Matters

Vendor decisions combine sensitive relationship context with future commerce
boundaries. Bounded owner-scoped comparisons prevent cross-account disclosure,
retain the evidence behind a choice, and avoid implying that Carecierge has
contacted or transacted with a vendor.

## Evidence

- `app/models/vendor_shortlist.rb`
- `app/models/vendor_option.rb`
- `app/controllers/vendor_shortlists_controller.rb`
- `app/controllers/vendor_options_controller.rb`
- `app/views/components/vendor_shortlist_comparison_component.html.erb`
- `spec/requests/vendor_shortlists_spec.rb`
- `spec/system/vendor_shortlists_spec.rb`

## Verification

- `bundle exec rspec spec/models/vendor_shortlist_spec.rb spec/models/vendor_option_spec.rb spec/services/vendor_shortlists/create_spec.rb spec/policies/vendor_shortlist_policy_spec.rb spec/components/vendor_shortlist_comparison_component_spec.rb spec/requests/vendor_shortlists_spec.rb spec/system/vendor_shortlists_spec.rb`
- `bundle exec rspec spec/requests/data_controls_spec.rb spec/config/filter_parameter_logging_spec.rb spec/components/event_plan_workspace_component_spec.rb spec/requests/vendors_spec.rb`
- `bin/ci`
