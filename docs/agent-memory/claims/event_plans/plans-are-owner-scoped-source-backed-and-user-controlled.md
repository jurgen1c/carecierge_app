---
id: event_plans.plans_are_owner_scoped_source_backed_and_user_controlled
type: fact
system: event_plans
status: needs_verification
confidence: high
severity: critical

title: Event plans are owner-scoped, source-backed, and user-controlled

claim: >
  Active relationship owners create encrypted birthday, anniversary, and generic
  event plans from one deterministic localized template. An owned birthday
  ImportantDate can prefill the plan and is retained with a birthday-origin
  provenance role whose occasion cannot later be changed; birthday
  plans use localized birthday steps and expose the earliest due incomplete
  current task as one review-only next action. When an unsourced plan changes
  occasion, untouched localized template copy follows the new occasion and
  locale while user-edited wording is preserved; updates that do not change the
  occasion skip localized template matching. Plans and their phased tasks expose
  progress, decisions, and explicit lifecycle actions. Scheduling or
  rescheduling a plan rebases untouched template deadlines, including
  superseded work that selective AI deletion may later restore, while preserving
  user-customized dates. New task
  reminders require active plans and incomplete tasks, and deleting a task
  detaches rather than deletes its reminder history. Optional AI planning is
  requested manually through a swappable RubyLLM provider boundary, uses bounded
  structured output with provider-specific output-token limits and OpenAI
  storage explicitly disabled, and can only add
  reviewable tasks: it never sends, schedules, contacts, books, or purchases.
  OpenAI, Anthropic, and Gemini credentials can be supplied through encrypted
  Rails credentials or Kamal-forwarded provider environment secrets. Provider
  defaults select a compatible model as a pair, while an explicit shared model
  override takes precedence over the legacy OpenAI-only model credential and is
  passed directly to the selected provider even when it is newer than RubyLLM's
  bundled model registry; repository defaults retain registry validation.
  Current, non-stale public relationship evidence is eligible by default;
  private notes require an identifiable per-request selection, while protected sources also
  require current suggestion approval, an identifiable unlocked choice, and a
  revalidated vault lease. Source dates use the owner's local calendar. Later
  requests reuse sourced prior tasks only when every persisted source remains in
  the currently authorized catalog. Known source IDs and a complete context
  fingerprint preserve provenance; lifecycle changes advance the generation
  fence. Account-profile-plan locking plus
  profile-lock participation by eligible source writers, a generation fence,
  and active-profile revalidation under mutation locks reject stale work. Authored content is filtered
  from request logs and sensitive plan pages disable Turbo snapshots. Superseded
  tasks are excluded from later provider snapshots and interactive task flows,
  with their current state rechecked inside held mutation locks. Plans and
  tasks participate in owner exports. Selective AI deletion clears aggregate AI
  provenance while retaining non-AI birthday-origin provenance, deletes
  AI-origin tasks, advances the fence, and detaches rather than deletes explicit
  reminders while preserving plans and template/manual work.

source_files:
  - app/models/event_plan.rb
  - app/models/plan_task.rb
  - app/controllers/event_plans_controller.rb
  - app/controllers/plan_tasks_controller.rb
  - app/services/event_plans/create.rb
  - app/services/event_plans/template.rb
  - app/services/event_plans/update.rb
  - app/services/event_plans/context_builder.rb
  - app/services/event_plans/suggest.rb
  - app/agents/event_plans/llm_suggester.rb
  - app/agents/event_plans/llm_configuration.rb
  - config/initializers/ruby_llm.rb
  - db/migrate/20260821040000_create_event_plans.rb
  - db/migrate/20260821040001_add_event_plan_references_to_reminders.rb

related_files:
  - app/models/concerns/briefing_source_lock.rb
  - app/models/memory_record.rb
  - app/services/memory_extractions/review.rb
  - app/models/reminder.rb
  - app/controllers/reminders_controller.rb
  - app/serializers/data_exports/snapshot.rb
  - app/services/data_deletions/delete_ai_data.rb
  - app/views/components/event_plan_workspace_component.rb
  - app/views/components/event_plan_workspace_component.html.erb
  - app/views/event_plans/show.html.erb
  - app/views/important_dates/_important_date.html.erb
  - app/views/important_dates/_section.html.erb
  - app/views/important_dates/_upcoming.html.erb
  - app/views/relationship_profiles/show.html.erb
  - config/initializers/filter_parameter_logging.rb
  - .kamal/secrets
  - config/deploy.yml
  - config/locales/daily_feed.en.yml
  - config/locales/daily_feed.es.yml
  - docs/features/06-03-general-event-planning-assistant.md
  - spec/models/event_plan_spec.rb
  - spec/models/plan_task_spec.rb
  - spec/services/event_plans/update_spec.rb
  - spec/services/event_plans/suggest_spec.rb
  - spec/requests/event_plans_spec.rb
  - spec/config/ai_memory_deploy_spec.rb
  - spec/serializers/data_exports/snapshot_spec.rb
  - spec/system/event_plans_spec.rb
symbols:
  - EventPlan
  - PlanTask
  - EventPlansController
  - PlanTasksController
  - EventPlans::Create
  - EventPlans::Template
  - EventPlans::Update
  - EventPlans::ContextBuilder
  - EventPlans::Suggest
  - EventPlans::LlmSuggester
  - EventPlans::LlmConfiguration
  - EventPlanWorkspaceComponent
routes:
  - event_plans
  - event_plan
  - suggest_event_plan
  - event_plan_plan_tasks
  - complete_event_plan_plan_task
tags:
  - event_plans
  - relationship_profiles
  - privacy_vault
  - reminders
  - source_provenance

verification:
  - bundle exec rspec spec/models/event_plan_spec.rb spec/models/plan_task_spec.rb spec/models/reminder_spec.rb spec/services/event_plans spec/policies/event_plan_policy_spec.rb spec/policies/plan_task_policy_spec.rb spec/components/event_plan_workspace_component_spec.rb spec/requests/event_plans_spec.rb spec/requests/reminders_spec.rb spec/system/event_plans_spec.rb
  - bundle exec rspec spec/requests/data_controls_spec.rb spec/serializers/data_exports/snapshot_spec.rb spec/services/data_deletions/delete_ai_data_spec.rb
  - bin/rubocop
  - bin/memory validate
  - bin/memory coverage --git-diff
  - bin/memory audit --git-diff
  - bin/ci

last_verified_commit: null
---

# Event plans are owner-scoped, source-backed, and user-controlled

## Claim

Carecierge has one owner-scoped event-plan model for reusable relationship
occasions. A deterministic template makes the feature useful without AI, while
optional AI can add only reviewable, source-cited steps after the user requests
it and explicitly opts sensitive context into that request.

## Why It Matters

Event planning combines relationship context, protected data, reminders, and a
provider call. Keeping the consent boundary, lock order, provenance fence, and
no-external-action rule together prevents cross-account reads, stale output,
silent sensitive-context reuse, and accidental action on the user's behalf.

## Evidence

- `app/models/event_plan.rb`
- `app/services/event_plans/suggest.rb`
- `app/services/event_plans/context_builder.rb`
- `app/models/reminder.rb`
- `app/services/data_deletions/delete_ai_data.rb`
- `spec/services/event_plans/suggest_spec.rb`
- `spec/system/event_plans_spec.rb`

## Verification

- `bundle exec rspec spec/models/event_plan_spec.rb spec/models/plan_task_spec.rb spec/models/reminder_spec.rb spec/services/event_plans spec/policies/event_plan_policy_spec.rb spec/policies/plan_task_policy_spec.rb spec/components/event_plan_workspace_component_spec.rb spec/requests/event_plans_spec.rb spec/requests/reminders_spec.rb spec/system/event_plans_spec.rb`
- `bundle exec rspec spec/requests/data_controls_spec.rb spec/serializers/data_exports/snapshot_spec.rb spec/services/data_deletions/delete_ai_data_spec.rb`
- `bin/rubocop`
- `bin/memory validate`
- `bin/memory coverage --git-diff`
- `bin/memory audit --git-diff`
- `bin/ci`
