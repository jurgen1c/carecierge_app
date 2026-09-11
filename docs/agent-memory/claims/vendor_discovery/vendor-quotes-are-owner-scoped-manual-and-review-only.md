---
id: vendor_discovery.vendor_quotes_are_owner_scoped_manual_and_review_only
type: fact
system: vendor_discovery
status: current
confidence: high
severity: critical

title: Vendor quotes are owner-scoped, manual, and review-only

claim: >
  Concierge quote tools use integer cents with an explicit currency, owner-scoped vendors and plans, existing context locks, and optimistic versions. Professional chat requires selected work vendors and plans, including quote-linked reminders. Confirmed deletion retains domain restrictions and does not contact or accept terms with a vendor.
  Authenticated owners manually record encrypted vendor quote scope, next
  action, and notes together with amount, three-letter currency, expiration,
  decision deadline, and explicit status for one saved vendor and active event
  plan. The plan is authoritative for relationship context. Creation and update
  revalidate owner and active-context boundaries under ordered locks; updates
  carry a required optimistic revision and reject stale submissions. Multiple
  same-plan quotes are compared in a responsive English and Spanish surface;
  cents use exact decimal arithmetic for localized display, and elapsed open
  quotes are presented as expired without a background mutation. Storage-level
  amount validation errors use the user-facing localized quote-amount label.
  Completed- or archived-plan quotes remain owner-readable through bounded quote
  history and explicitly removable but cannot be changed. A quote deadline can prefill the existing
  owner-controlled reminder form, but no reminder, vendor contact, request,
  booking, purchase, or payment happens automatically. Quote deletion nullifies
  its optional reminder reference without deleting reminder history, while a
  vendor cannot be deleted until every referencing quote is removed. Owner
  exports include decrypted quote details and embedded vendor provenance;
  ownership foreign keys cascade on account or plan deletion.

source_files:
  - app/services/concierge/operations/manual_plan_records.rb
  - app/services/concierge/operations/quotes.rb
  - app/services/concierge/vendor_sources.rb
  - app/models/vendor_quote.rb
  - app/controllers/vendor_quotes_controller.rb
  - app/policies/vendor_quote_policy.rb
  - app/controllers/reminders_controller.rb
  - db/migrate/20260903042850_create_vendor_quotes.rb
  - db/migrate/20260903044916_add_vendor_quote_reference_to_reminders.rb

related_files:
  - spec/services/concierge/vendors_spec.rb
  - app/models/reminder.rb
  - app/models/vendor.rb
  - app/models/event_plan.rb
  - app/services/vendors/destroy.rb
  - app/serializers/data_exports/snapshot.rb
  - app/views/components/vendor_quote_comparison_component.rb
  - app/views/components/vendor_quote_comparison_component.html.erb
  - app/views/vendor_quotes/index.html.erb
  - app/views/vendor_quotes/_form.html.erb
  - app/views/vendors/index.html.erb
  - config/initializers/filter_parameter_logging.rb
  - config/locales/vendor_quotes.en.yml
  - config/locales/vendor_quotes.es.yml
  - config/locales/vendors.en.yml
  - config/locales/vendors.es.yml
  - config/routes.rb
  - docs/features/07-04-quote-collection.md
  - spec/models/vendor_quote_spec.rb
  - spec/components/vendor_quote_comparison_component_spec.rb
  - spec/requests/vendor_quotes_spec.rb
  - spec/migrations/create_vendor_quotes_spec.rb
  - spec/models/reminder_spec.rb
  - spec/requests/reminders_spec.rb
  - spec/serializers/data_exports/snapshot_spec.rb
symbols:
  - VendorQuote
  - VendorQuotesController
  - VendorQuotePolicy
  - VendorQuoteComparisonComponent
routes:
  - vendor_quotes
  - event_plan_vendor_quotes
  - new_event_plan_vendor_quote
  - edit_vendor_quote
  - vendor_quote
tags:
  - vendor_discovery
  - event_plans
  - reminders
  - privacy
  - review_only
  - localization

verification:
  - bundle exec rspec spec/services/concierge/vendors_spec.rb spec/requests/concierge_spec.rb
  - bundle exec rspec spec/models/vendor_quote_spec.rb spec/components/vendor_quote_comparison_component_spec.rb spec/requests/vendor_quotes_spec.rb spec/models/reminder_spec.rb spec/requests/reminders_spec.rb spec/services/vendors/destroy_spec.rb spec/serializers/data_exports/snapshot_spec.rb
  - bundle exec rspec spec/requests/data_controls_spec.rb spec/config/filter_parameter_logging_spec.rb spec/components/event_plan_workspace_component_spec.rb
  - bun run build:css
  - bin/rubocop
  - bin/memory validate
  - bin/memory coverage --git-diff
  - bin/memory audit --git-diff
  - bin/ci

last_verified_commit: cc0ce9edfa8a02156d651f817eea75d9f8ec4a7f
---

# Vendor quotes are owner-scoped, manual, and review-only

## Claim

Owners can record and compare private vendor quotes for one event plan, set an
explicit next action, and hand a deadline to the existing reminder form without
triggering external communication or commerce.

## Why It Matters

Quotes combine private planning context, money, deadlines, and vendor evidence.
Keeping the workflow manual, owner-scoped, and review-only prevents cross-account
disclosure and avoids implying that Carecierge contacted or transacted with a
vendor.

## Evidence

- `app/models/vendor_quote.rb`
- `app/controllers/vendor_quotes_controller.rb`
- `app/controllers/reminders_controller.rb`
- `app/views/components/vendor_quote_comparison_component.html.erb`
- `spec/requests/vendor_quotes_spec.rb`
- `spec/requests/reminders_spec.rb`

## Verification

- `bundle exec rspec spec/models/vendor_quote_spec.rb spec/components/vendor_quote_comparison_component_spec.rb spec/requests/vendor_quotes_spec.rb spec/models/reminder_spec.rb spec/requests/reminders_spec.rb spec/services/vendors/destroy_spec.rb spec/serializers/data_exports/snapshot_spec.rb`
- `bin/ci`
