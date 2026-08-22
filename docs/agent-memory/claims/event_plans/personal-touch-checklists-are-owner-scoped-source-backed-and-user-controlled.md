---
id: event_plans.personal_touch_checklists_are_owner_scoped_source_backed_and_user_controlled
type: fact
system: event_plans
status: current
confidence: high
severity: important

title: Personal touch checklists are owner-scoped source-backed and user-controlled

claim: >
  Active relationship owners attach one encrypted personal-touch checklist to an
  event plan or important date, including birthdays, anniversaries, and custom
  moments. Deterministic localized prompts and a bounded set of structured
  relationship preferences seed practical source-backed items without reading
  private notes or Privacy Vault content. Persisted source fields are bounded,
  and preference confidence is normalized into visible confirmed or inferred
  provenance. Items support explicit
  categories, completion, reopening, accessible up/down ordering, and
  dismissal. Account-first, profile, attached-moment, and checklist row locks
  plus active-profile and archived-plan revalidation under those locks serialize
  creation and mutation; database constraints require exactly one UUID-backed
  moment and one checklist per moment. Pundit scopes every read and mutation to
  the active profile owner. UI progress and rendering preload only ordered,
  non-dismissed items, while owner exports retain the complete lifecycle. Content
  and provenance are encrypted at rest, lifecycle evidence is content-free, and
  exports include the checklist, items, and attached moment identifier. The UI
  remains review-only and never sends, books, contacts, purchases, or scores the
  user's care.

source_files:
  - app/models/personal_touch_checklist.rb
  - app/models/personal_touch_item.rb
  - app/services/personal_touch_checklists/create.rb
  - app/controllers/personal_touch_checklists_controller.rb
  - app/controllers/personal_touch_items_controller.rb
  - app/controllers/event_plans_controller.rb
  - app/controllers/important_dates_controller.rb
  - app/controllers/relationship_profiles_controller.rb
  - app/models/audit_event.rb
  - app/models/event_plan.rb
  - app/models/important_date.rb
  - app/models/relationship_profile.rb
  - app/policies/personal_touch_checklist_policy.rb
  - app/policies/personal_touch_item_policy.rb
  - app/serializers/data_exports/snapshot.rb
  - app/views/components/event_plan_workspace_component.rb
  - app/views/components/event_plan_workspace_component.html.erb
  - app/views/components/personal_touch_checklist_component.rb
  - app/views/components/personal_touch_checklist_component.html.erb
  - app/views/event_plans/show.html.erb
  - app/views/important_dates/_important_date.html.erb
  - config/locales/en.yml
  - config/locales/es.yml
  - config/locales/personal_touch_checklists.en.yml
  - config/locales/personal_touch_checklists.es.yml
  - config/initializers/filter_parameter_logging.rb
  - config/routes.rb
  - db/migrate/20260822164819_create_personal_touch_checklists_and_items.rb
  - docs/features/06-04-personal-touch-checklist.md
  - spec/models/audit_event_spec.rb
  - spec/serializers/data_exports/snapshot_spec.rb

related_files:
  - spec/models/personal_touch_checklist_spec.rb
  - spec/models/personal_touch_item_spec.rb
  - spec/services/personal_touch_checklists/create_spec.rb
  - spec/requests/personal_touch_checklists_spec.rb
  - spec/config/filter_parameter_logging_spec.rb
symbols:
  - PersonalTouchChecklist
  - PersonalTouchItem
  - PersonalTouchChecklists::Create
  - PersonalTouchChecklistsController
  - PersonalTouchItemsController
  - PersonalTouchChecklistPolicy
  - PersonalTouchItemPolicy
  - PersonalTouchChecklistComponent
routes:
  - event_plan_personal_touch_checklist
  - relationship_profile_important_date_personal_touch_checklist
  - personal_touch_checklist_personal_touch_items
  - complete_personal_touch_checklist_personal_touch_item
  - reopen_personal_touch_checklist_personal_touch_item
  - dismiss_personal_touch_checklist_personal_touch_item
  - move_up_personal_touch_checklist_personal_touch_item
  - move_down_personal_touch_checklist_personal_touch_item
tags:
  - event_plans
  - relationship_profiles
  - important_dates
  - owner_scope
  - encryption
  - source_provenance
  - uncertainty
  - audit_events
  - data_controls

verification:
  - bundle exec rspec spec/models/personal_touch_checklist_spec.rb spec/models/personal_touch_item_spec.rb spec/models/audit_event_spec.rb spec/services/personal_touch_checklists/create_spec.rb spec/policies/personal_touch_checklist_policy_spec.rb spec/policies/personal_touch_item_policy_spec.rb spec/components/personal_touch_checklist_component_spec.rb spec/requests/personal_touch_checklists_spec.rb spec/serializers/data_exports/snapshot_spec.rb
  - bundle exec rspec spec/requests/event_plans_spec.rb spec/requests/important_dates_spec.rb spec/requests/audit_event_integrations_spec.rb spec/requests/localization_spec.rb spec/requests/data_controls_spec.rb
  - bin/rubocop
  - bin/memory validate
  - bin/memory coverage --git-diff
  - bin/memory audit --git-diff
  - bin/ci

last_verified_commit: null
---

# Personal touch checklists are owner-scoped source-backed and user-controlled

## Claim

Carecierge has one owner-scoped checklist per supported relationship moment.
Practical prompts and structured preference evidence help the owner remember
specific details, while every action remains manual and reversible.

## Why It Matters

Personal touches can contain sensitive relationship details and appear beside
two different parent systems. The explicit UUID target constraint, shared owner
scope, lock order, encryption, provenance, and no-external-action boundary
prevent cross-account access, ambiguous attachment, stale mutation, and
performative automation.

## Evidence

- `app/models/personal_touch_checklist.rb`
- `app/models/personal_touch_item.rb`
- `app/services/personal_touch_checklists/create.rb`
- `app/policies/personal_touch_checklist_policy.rb`
- `db/migrate/20260822164819_create_personal_touch_checklists_and_items.rb`
- `spec/requests/personal_touch_checklists_spec.rb`

## Verification

- `bundle exec rspec spec/models/personal_touch_checklist_spec.rb spec/models/personal_touch_item_spec.rb spec/models/audit_event_spec.rb spec/services/personal_touch_checklists/create_spec.rb spec/policies/personal_touch_checklist_policy_spec.rb spec/policies/personal_touch_item_policy_spec.rb spec/components/personal_touch_checklist_component_spec.rb spec/requests/personal_touch_checklists_spec.rb spec/serializers/data_exports/snapshot_spec.rb`
- `bundle exec rspec spec/requests/event_plans_spec.rb spec/requests/important_dates_spec.rb spec/requests/audit_event_integrations_spec.rb spec/requests/localization_spec.rb spec/requests/data_controls_spec.rb`
- `bin/rubocop`
- `bin/memory validate`
- `bin/memory coverage --git-diff`
- `bin/memory audit --git-diff`
- `bin/ci`
