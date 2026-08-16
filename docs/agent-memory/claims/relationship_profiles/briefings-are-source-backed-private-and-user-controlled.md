---
id: relationship_profiles.briefings_are_source_backed_private_and_user_controlled
type: constraint
system: relationship_profiles
status: current
confidence: high
severity: critical

title: Relationship briefings are source-backed, private, and user-controlled

claim: >
  Active profile owners manually request encrypted relationship briefings for a
  bounded interaction context. The provider receives only a bounded source catalog
  of current timeline entries, open commitments, upcoming dates, preferences, and
  eligible notes in JSON-serialized untrusted input; private notes require explicit
  per-request selection, while vault items additionally require an active lease
  revalidated under the account and profile locks before both source reads. The
  non-stored structured response must cite known source IDs for every item, and
  server-side enrichment preserves provenance while downgrading certainty whenever
  any cited source is inferred. A profile generation fence and complete source
  fingerprint reject output when another request or source mutation wins during
  provider execution; every persisted source mutation acquires the same profile
  lock before writing. Timeline-producing recap and extraction flows acquire the
  profile before the recap, while owner timezone changes acquire the account lock
  that guards both briefing context reads. Sensitive-access evidence is recorded
  inside the account-then-profile lock scope. Briefing transitions lock account,
  profile, and briefing in that order so they serialize with selective deletion. The inline
  English and Spanish workspace supports save, dismiss, and links into existing
  reminder and message-draft flows, but never sends, schedules, or contacts anyone.
  Briefings emit content-free audit evidence, participate in owner exports and
  selective AI deletion, and filter submitted interaction context from logs.

source_files:
  - app/models/relationship_briefing.rb
  - app/models/concerns/briefing_source_lock.rb
  - app/models/relationship_profile.rb
  - app/services/relationship_briefings/context_builder.rb
  - app/services/relationship_briefings/generate.rb
  - app/services/relationship_briefings/open_ai_generator.rb
  - app/services/notification_preferences/save.rb
  - app/controllers/relationship_briefings_controller.rb
  - app/controllers/concerns/relationship_profile_show_workspace.rb
  - app/views/components/relationship_briefing_workspace_component.rb
  - app/views/components/relationship_briefing_workspace_component.html.erb
  - app/serializers/data_exports/snapshot.rb
  - app/services/data_deletions/delete_ai_data.rb
  - app/controllers/conversation_recaps_controller.rb
  - app/services/memory_extractions/extract.rb
  - config/initializers/filter_parameter_logging.rb
  - config/deploy.yml

related_files:
  - app/models/audit_event.rb
  - app/policies/relationship_briefing_policy.rb
  - config/routes.rb
  - config/locales/relationship_briefings.en.yml
  - config/locales/relationship_briefings.es.yml
  - db/migrate/20260815230443_create_relationship_briefings.rb
  - docs/features/05-02-relationship-briefing.md
  - spec/models/relationship_briefing_spec.rb
  - spec/services/relationship_briefings/context_builder_spec.rb
  - spec/services/relationship_briefings/generate_spec.rb
  - spec/services/relationship_briefings/open_ai_generator_spec.rb
  - spec/services/notification_preferences/save_spec.rb
  - spec/components/relationship_briefing_workspace_component_spec.rb
  - spec/requests/relationship_briefings_spec.rb
  - spec/requests/data_controls_spec.rb
  - spec/requests/conversation_recaps_spec.rb
  - spec/services/memory_extractions/extract_spec.rb

symbols:
  - RelationshipBriefing
  - RelationshipBriefings::ContextBuilder
  - RelationshipBriefings::Generate
  - RelationshipBriefings::OpenAiGenerator
  - RelationshipBriefingsController
  - RelationshipBriefingWorkspaceComponent

routes:
  - generate_relationship_profile_relationship_briefings
  - save_relationship_profile_relationship_briefing
  - dismiss_relationship_profile_relationship_briefing

tags:
  - relationship_profiles
  - relationship_briefings
  - privacy
  - provenance
  - ai
  - consent
  - constraint

verification:
  - bundle exec rspec spec/models/relationship_briefing_spec.rb spec/services/relationship_briefings spec/services/memory_extractions/extract_spec.rb spec/policies/relationship_briefing_policy_spec.rb spec/components/relationship_briefing_workspace_component_spec.rb spec/requests/relationship_briefings_spec.rb spec/requests/conversation_recaps_spec.rb spec/requests/data_controls_spec.rb spec/services/data_deletions/delete_ai_data_spec.rb spec/config/filter_parameter_logging_spec.rb spec/config/ai_memory_deploy_spec.rb
  - bin/rubocop
  - bun run build:css
  - bin/memory validate
  - bin/memory coverage --git-diff
  - bin/memory audit --git-diff
  - bin/ci

last_verified_commit: null
---

# Relationship briefings are source-backed, private, and user-controlled

## Claim

Relationship briefings are encrypted, owner-scoped snapshots created only after
the user describes a specific upcoming context. Every generated statement keeps
visible saved-record provenance and is labeled confirmed or inferred.

## Constraint

Default context is limited to current structured profile records and public
notes. Private notes are opt-in for one request, and vault context also requires
an active password-backed lease at both sensitive-read boundaries. Provider
storage is disabled, user and source text remain JSON data rather than
instructions, and a strict response may cite only the server-issued catalog.
Source changes and overlapping requests fence stale output. Source mutations
share the profile lock; recap and extraction flows acquire that profile before
their recap row, and sensitive-access evidence remains inside the account-profile
scope. Owner-timezone updates share the account lock used around briefing context
reads so date boundaries cannot change between the final fingerprint and
persistence. The user must separately choose whether to save,
dismiss, create a reminder, or open message drafting; save and dismiss acquire
account, profile, then briefing locks to match deletion and generation. No briefing
operation performs an external action.

## Why It Matters

An AI summary can otherwise turn tentative or sensitive relationship data into
an unattributed assertion. This boundary keeps private context consented,
inferences legible, races fail-closed, and any next action under the user's
control.

## Verification

- `bundle exec rspec spec/models/relationship_briefing_spec.rb spec/services/relationship_briefings spec/services/memory_extractions/extract_spec.rb spec/policies/relationship_briefing_policy_spec.rb spec/components/relationship_briefing_workspace_component_spec.rb spec/requests/relationship_briefings_spec.rb spec/requests/conversation_recaps_spec.rb spec/requests/data_controls_spec.rb spec/services/data_deletions/delete_ai_data_spec.rb spec/config/filter_parameter_logging_spec.rb spec/config/ai_memory_deploy_spec.rb`
- `bin/rubocop`
- `bun run build:css`
- `bin/memory validate`
- `bin/memory coverage --git-diff`
- `bin/memory audit --git-diff`
- `bin/ci`
