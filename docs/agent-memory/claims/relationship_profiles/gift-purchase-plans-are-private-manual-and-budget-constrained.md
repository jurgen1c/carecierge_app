---
id: relationship_profiles.gift_purchase_plans_are_private_manual_and_budget_constrained
type: fact
system: relationship_profiles
status: needs_verification
confidence: high
severity: critical

title: Gift purchase plans are private manual and budget constrained

claim: >
  Each saved Gift has at most one owner-scoped GiftPurchasePlan with an exact
  decimal budget, explicit currency, deadlines, independent manual purchase and
  delivery statuses, and encrypted shipping, constraint, follow-up and option
  details. Up to three named options retain safe HTTP(S) links and decimal costs;
  suggestions select the lowest known total within the explicit budget only
  among options whose constraints the owner checked. Saved gift vendor estimates
  enter an unsaved draft without confirming constraints. Neither saved costs nor
  availability are verified. Account-to-profile locks and a mandatory revision
  prevent stale purchase-plan writes. An explicit action adds one same-profile
  active event-plan task under locks; duplicate submissions reuse its attachment.
  That task is an independent checklist copy and later logistics edits do not
  reschedule it. Purchase, delivery and follow-up links prefill existing private
  reminder forms by owner-scoped ID without creating reminders or copying
  shipping details. All buying and vendor contact remain outside the app;
  statuses are user records, not purchase execution or approval. The English and
  Spanish workspace disables snapshots and HTTP caching. Logistics are filtered
  from logs, exported under their gift and deleted with it. Gift-given outcomes
  remain in the existing gift-history flow.

source_files:
  - app/models/gift_purchase_plan.rb
  - app/models/gift.rb
  - app/controllers/gift_purchase_plans_controller.rb
  - app/controllers/reminders_controller.rb
  - app/services/gift_purchase_plans/save.rb
  - app/services/gift_purchase_plans/add_task.rb
  - app/views/components/gift_purchase_workspace_component.rb
  - app/views/components/gift_purchase_workspace_component.html.erb
  - app/views/gift_purchase_plans/show.html.erb
  - app/views/gifts/_gift.html.erb
  - app/serializers/data_exports/snapshot.rb
  - config/routes.rb
  - config/initializers/filter_parameter_logging.rb
  - config/locales/gift_purchase_plans.en.yml
  - config/locales/gift_purchase_plans.es.yml
  - db/migrate/20260905092245_create_gift_purchase_plans.rb
  - db/schema.rb
related_files:
  - spec/models/gift_purchase_plan_spec.rb
  - spec/requests/gift_purchase_plans_spec.rb
  - spec/components/gift_purchase_workspace_component_spec.rb
  - spec/system/gift_purchase_plans_spec.rb
  - spec/serializers/data_exports/gift_purchase_snapshot_spec.rb
symbols:
  - GiftPurchasePlan
  - GiftPurchasePlans::Save
  - GiftPurchasePlans::AddTask
  - GiftPurchasePlansController
  - GiftPurchaseWorkspaceComponent
routes:
  - relationship_profile_gift_purchase_plan
  - task_relationship_profile_gift_purchase_plan
tags:
  - gifts
  - purchase_planning
  - review_only
  - budget
  - privacy
verification:
  - bundle exec rspec spec/models/gift_purchase_plan_spec.rb spec/requests/gift_purchase_plans_spec.rb spec/components/gift_purchase_workspace_component_spec.rb spec/serializers/data_exports/gift_purchase_snapshot_spec.rb spec/system/gift_purchase_plans_spec.rb
  - bin/ci
last_verified_commit: null
---

# Gift purchase plans are private manual and budget constrained

## Why It Matters

Gift planning must not silently become commerce automation or disclose shipping
notes to providers. Existing consent-gated gift recommendations supply ideas;
manual purchase planning does not grant permission to purchase or contact anyone.

## Verification

The focused model, request, component, export and system specs exercise bounded
money and links, owner isolation, stale writes, explicit handoffs, encryption,
localization and responsive forms. Full bin/ci remains the coverage authority.
