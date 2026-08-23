---
id: event_plans.backup_plans_are_source_backed_comparable_and_explicitly_promoted
type: fact
system: event_plans
status: needs_verification
confidence: high
severity: critical

title: Backup plans are source-backed, comparable, and explicitly promoted

claim: >
  Active event-plan owners manually choose one supported recovery scenario and
  generate up to three encrypted structured backup options without changing the
  active plan. The non-stored provider request uses the existing bounded
  event-plan source catalog and generation fence through a swappable RubyLLM
  provider boundary, with provider-compatible model defaults, a bounded
  provider-specific output-token limit, and OpenAI response storage explicitly
  disabled. Explicit model overrides are passed directly to their selected
  provider even when newer than RubyLLM's bundled registry, while repository
  defaults retain registry validation. Public relationship context is
  eligible by default, private notes require identifiable per-request selection,
  and vault items also require suggestion approval plus a revalidated active
  lease. Prior AI tasks are eligible only when all of their sources remain
  authorized for the current request. Every option and proposed task cites known sources and compares effort,
  timing, estimated cost, relationship fit, preserved constraints, and planned
  changes, including the exact tasks added, current tasks retired, and active
  reminders retired. Active reminder impact is encrypted with the option,
  revalidated under lock before mutation, and retained for the identified
  applied option after promotion. Promotion is explicit, owner-scoped, transactional, generation-fenced,
  and idempotent, with the active relationship, authorized context fingerprint,
  and any vault lease revalidated before mutation. Context fingerprints are
  rebuilt under the stored generation locale so interface-locale changes alone
  cannot reject an otherwise current option; sensitive revalidation reads
  record durable metadata-only access evidence even when changed context rejects
  promotion without plan mutation. It preserves completed work, supersedes only provider-named
  current incomplete tasks, retires and detaches their reminders without deleting
  reminder history, and appends source-backed AI-origin tasks. Generation and
  promotion never send, schedule, contact, book, or purchase. Backup records and
  options participate in owner exports; selective AI deletion removes them and
  promoted AI tasks while restoring superseded manual/template work with
  rescheduled template deadlines kept current and
  preserving the authored event plan. Ordinary exports keep sensitive-source
  provenance while redacting its plaintext content unless the sensitive export
  gate is reauthenticated. English and Spanish use calm recovery copy and the established product
  palette.

source_files:
  - app/models/backup_plan.rb
  - app/models/backup_option.rb
  - app/services/backup_plans/generate.rb
  - app/services/backup_plans/promote.rb
  - app/agents/backup_plans/llm_generator.rb
  - app/agents/event_plans/llm_configuration.rb
  - config/initializers/ruby_llm.rb
  - app/controllers/backup_plans_controller.rb
  - db/migrate/20260822191243_create_backup_plans.rb
  - db/migrate/20260822192636_add_backup_option_reference_to_plan_tasks.rb
  - db/migrate/20260822210000_add_reviewed_reminders_to_backup_options.rb

related_files:
  - app/models/user.rb
  - app/models/event_plan.rb
  - app/models/plan_task.rb
  - app/models/reminder.rb
  - app/models/audit_event.rb
  - app/services/event_plans/context_builder.rb
  - app/services/data_deletions/delete_ai_data.rb
  - app/serializers/data_exports/snapshot.rb
  - app/views/components/event_plan_workspace_component.rb
  - app/views/components/event_plan_workspace_component.html.erb
  - config/routes.rb
  - config/deploy.yml
  - config/locales/en.yml
  - config/locales/es.yml
  - config/locales/event_plans.en.yml
  - config/locales/event_plans.es.yml
  - docs/features/06-05-backup-plan-generator.md
  - spec/services/backup_plans/generate_spec.rb
  - spec/services/backup_plans/promote_spec.rb
  - spec/requests/backup_plans_spec.rb
  - spec/models/audit_event_spec.rb
  - spec/requests/data_controls_spec.rb
symbols:
  - BackupPlan
  - BackupOption
  - BackupPlansController
  - BackupPlans::Generate
  - BackupPlans::Promote
  - BackupPlans::LlmGenerator
  - EventPlans::LlmConfiguration
routes:
  - generate_event_plan_backup_plans
  - promote_event_plan_backup_plan
tags:
  - event_plans
  - backup_plans
  - privacy_vault
  - reminders
  - source_provenance
  - recovery

verification:
  - bundle exec rspec spec/migrations/create_backup_plans_spec.rb spec/models/backup_plan_spec.rb spec/models/backup_option_spec.rb spec/services/backup_plans spec/requests/backup_plans_spec.rb spec/components/event_plan_workspace_component_spec.rb
  - bundle exec rspec spec/models/event_plan_spec.rb spec/models/plan_task_spec.rb spec/models/reminder_spec.rb spec/services/event_plans spec/requests/event_plans_spec.rb spec/requests/reminders_spec.rb
  - bundle exec rspec spec/requests/data_controls_spec.rb spec/serializers/data_exports/snapshot_spec.rb spec/services/data_deletions/delete_ai_data_spec.rb spec/requests/localization_spec.rb
  - bin/rubocop
  - bin/memory validate
  - bin/memory coverage --git-diff
  - bin/memory audit --git-diff
  - bin/ci

last_verified_commit: null
---

# Backup plans are source-backed, comparable, and explicitly promoted

## Claim

Carecierge prepares structured contingency options from an existing event plan
without silently changing it. The owner can compare the practical and
relationship impact, then explicitly promote one current option into the plan.

## Why It Matters

Recovery combines sensitive relationship context, provider output, task
replacement, and reminder history. Keeping consent, provenance, generation
fencing, and explicit promotion together prevents stale or cross-account output
from changing a plan and prevents obsolete reminders from firing after recovery.

## Evidence

- `app/services/backup_plans/generate.rb`
- `app/services/backup_plans/promote.rb`
- `app/agents/backup_plans/llm_generator.rb`
- `app/models/backup_plan.rb`
- `app/models/backup_option.rb`
- `spec/services/backup_plans/generate_spec.rb`
- `spec/services/backup_plans/promote_spec.rb`

## Verification

- `bundle exec rspec spec/migrations/create_backup_plans_spec.rb spec/models/backup_plan_spec.rb spec/models/backup_option_spec.rb spec/services/backup_plans spec/requests/backup_plans_spec.rb spec/components/event_plan_workspace_component_spec.rb`
- `bundle exec rspec spec/requests/data_controls_spec.rb spec/serializers/data_exports/snapshot_spec.rb spec/services/data_deletions/delete_ai_data_spec.rb spec/requests/localization_spec.rb`
- `bin/rubocop`
- `bin/memory validate`
- `bin/memory coverage --git-diff`
- `bin/memory audit --git-diff`
- `bin/ci`
