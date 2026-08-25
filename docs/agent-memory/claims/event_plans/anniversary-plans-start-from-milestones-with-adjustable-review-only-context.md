---
id: event_plans.anniversary_plans_start_from_milestones_with_adjustable_review_only_context
type: fact
system: event_plans
status: current
confidence: verified
severity: critical

title: Anniversary plans start from milestones with adjustable review-only context

claim: >
  Active relationship owners can start an anniversary plan from an owned
  anniversary or milestone ImportantDate. Creation revalidates the source under
  the account-to-profile lock, retains explicit anniversary-origin provenance,
  and keeps the occasion immutable. English and Spanish anniversary templates
  provide effort-adjusted review steps for activities, reservations, gifts,
  flowers or another welcome gesture, messages, reminders, personal touches,
  practical support, backup planning, and day-of review. Practical-support
  confirmation remains an ordinary plan task so its action opens the plan step;
  it does not impersonate the separate reminder workflow. The user selects a
  tone and, for anniversary plans, a low, medium, or high effort level; both
  remain editable plan context, while effort is supplied to optional non-stored
  suggestions only for anniversary plans where the control is exposed.
  Preference changes update untouched current or promoted-superseded template
  fields and add only positions introduced by the new runway, preserving customized fields and
  steps the owner explicitly deleted across effort-level round trips by retaining
  content-scrubbed hidden template tombstones. Fully managed steps removed by a
  preference change cannot later reappear through selective AI deletion. Authored tasks may share a display position with
  an introduced template step and do not suppress the required runway. Clearing
  a plan date clears untouched deadlines
  derived from that date. Legacy anniversary plans created before
  planning preferences existed are recognized by their localized template
  lineage even when every legacy step has customized copy or only a legacy-only
  position remains, retain their legacy deadline offsets when only rescheduled, and move onto the anniversary runway
  without losing customizations. The manual form
  renders effort and prior-plan controls as a usable no-JavaScript baseline;
  every editable relationship's bounded history is loaded before Stimulus
  narrows it to the selected anniversary relationship, and the controller
  restores the canonical prior-plan option set before Turbo caching.
  A completed or archived
  anniversary plan from the same relationship enters the source catalog only
  after explicit selection, is marked inferred and needing confirmation, and is
  never treated as a current preference or instruction. A stale, unavailable,
  or no-longer-applicable optional selection is ignored instead of blocking
  creation; a plan retaining that context must remain an anniversary plan.
  Prior task candidates are bounded in the database, and AI-derived task copy
  enters that historical summary only when every persisted source still resolves
  in the current request's authorized catalog; protected, deleted, stale, or
  otherwise unavailable sources fail closed. The bounded catalog places the
  current relationship and hard constraints ahead of prior-plan history. When
  included historical task copy depends on a currently selected private note or
  vault item, the aggregate history source remains sensitive and its evidence ID
  is fingerprinted from the authorized aggregate and each current dependency
  snapshot. A later request whose selected
  context produces a different aggregate cannot reuse tasks derived from the old
  evidence ID, and persisted backup context cannot bypass sensitive-export
  reauthentication. Tone guidance remains relationship-neutral while the manual
  relationship selector is editable. The workspace exposes one current next
  action but never sends, books, purchases, contacts, or shares anything
  automatically.

source_files:
  - app/controllers/event_plans_controller.rb
  - app/javascript/controllers/event_plan_form_controller.js
  - app/models/event_plan.rb
  - app/models/plan_task.rb
  - app/queries/event_plans/prior_anniversary_plans.rb
  - app/services/event_plans/create.rb
  - app/services/event_plans/template.rb
  - app/services/event_plans/update.rb
  - app/controllers/plan_tasks_controller.rb
  - app/services/event_plans/context_builder.rb
  - app/services/event_plans/suggest.rb
  - app/agents/event_plans/llm_suggester.rb
  - app/views/components/event_plan_workspace_component.rb
  - app/views/components/event_plan_workspace_component.html.erb
  - app/views/event_plans/_form.html.erb
  - config/locales/event_plans.en.yml
  - config/locales/event_plans.es.yml
  - db/migrate/20260823144136_add_planning_preferences_to_event_plans.rb

related_files:
  - app/models/important_date.rb
  - app/services/data_deletions/delete_ai_data.rb
  - app/views/important_dates/_important_date.html.erb
  - app/views/important_dates/_section.html.erb
  - app/views/important_dates/_upcoming.html.erb
  - docs/features/06-02-anniversary-concierge.md
  - spec/agents/event_plans/llm_suggester_spec.rb
  - spec/components/event_plan_workspace_component_spec.rb
  - spec/models/event_plan_spec.rb
  - spec/requests/event_plans_spec.rb
  - spec/requests/important_dates_spec.rb
  - spec/services/data_deletions/delete_ai_data_spec.rb
  - spec/services/event_plans/context_builder_spec.rb
  - spec/services/event_plans/suggest_spec.rb
  - spec/services/event_plans/create_spec.rb
  - spec/services/event_plans/template_spec.rb
  - spec/services/event_plans/update_spec.rb
  - spec/system/event_plans_spec.rb
symbols:
  - "EventPlan#anniversary_origin?"
  - "EventPlan#prior_anniversary_context"
  - EventPlansController
  - EventPlans::PriorAnniversaryPlans
  - EventPlans::Create
  - EventPlans::Template
  - EventPlans::Update
  - EventPlans::ContextBuilder
  - EventPlans::Suggest
  - EventPlans::LlmSuggester
  - EventPlanWorkspaceComponent
routes:
  - new_event_plan
  - event_plans
tags:
  - event_plans
  - anniversaries
  - important_dates
  - localization
  - source_provenance
  - user_control

verification:
  - bundle exec rspec spec/requests/event_plans_spec.rb spec/requests/important_dates_spec.rb spec/models/event_plan_spec.rb spec/services/event_plans/create_spec.rb spec/services/event_plans/template_spec.rb spec/services/event_plans/update_spec.rb spec/services/event_plans/context_builder_spec.rb spec/services/event_plans/suggest_spec.rb spec/agents/event_plans/llm_suggester_spec.rb spec/components/event_plan_workspace_component_spec.rb spec/services/data_deletions/delete_ai_data_spec.rb spec/system/event_plans_spec.rb
  - bin/rubocop
  - bin/memory validate
  - bin/memory coverage --git-diff
  - bin/memory audit --git-diff
  - bin/ci

last_verified_commit: 2c2f30f403674a08d03966791e3c7b1d963e06e2
---

# Anniversary plans start from milestones with adjustable review-only context

## Claim

Carecierge uses the existing owner-scoped event-planning system for anniversary
and milestone dates, with explicit source provenance, adjustable planning
preferences, and opt-in historical context that remains review-only.

## Why It Matters

Anniversary history and relationship context can become stale or feel
surveillance-oriented when silently reused. Keeping important-date authority,
historical opt-in, uncertainty, and the no-external-action boundary together
prevents cross-owner reads and unwanted assumptions while preserving useful
continuity.

## Evidence

- `app/services/event_plans/create.rb`
- `app/queries/event_plans/prior_anniversary_plans.rb`
- `app/services/event_plans/context_builder.rb`
- `app/services/event_plans/template.rb`
- `app/services/event_plans/update.rb`
- `app/views/components/event_plan_workspace_component.html.erb`
- `spec/requests/event_plans_spec.rb`
- `spec/services/event_plans/context_builder_spec.rb`
- `spec/services/event_plans/suggest_spec.rb`
- `spec/services/event_plans/update_spec.rb`

## Verification

- `bundle exec rspec spec/requests/event_plans_spec.rb spec/requests/important_dates_spec.rb spec/models/event_plan_spec.rb spec/services/event_plans/create_spec.rb spec/services/event_plans/template_spec.rb spec/services/event_plans/update_spec.rb spec/services/event_plans/context_builder_spec.rb spec/services/event_plans/suggest_spec.rb spec/agents/event_plans/llm_suggester_spec.rb spec/components/event_plan_workspace_component_spec.rb spec/services/data_deletions/delete_ai_data_spec.rb spec/system/event_plans_spec.rb`
- `bin/rubocop`
- `bin/memory validate`
- `bin/memory coverage --git-diff`
- `bin/memory audit --git-diff`
- `bin/ci`
