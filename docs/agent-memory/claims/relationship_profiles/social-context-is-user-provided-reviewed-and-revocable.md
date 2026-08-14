---
id: relationship_profiles.social_context_is_user_provided_reviewed_and_revocable
type: constraint
system: relationship_profiles
status: current
confidence: high
severity: critical

title: Social context is user-provided, review-gated, and revocable

claim: >
  Active owners can retain bounded Lexxy notes and managed screenshots without
  social-account monitoring. Downstream use is off by default and revocable.
  Permission-gated, non-stored analysis stays reviewable. Profile locks and
  version fences prevent stale outputs. Selective AI deletion preserves owner
  text while clearing analysis. Exports include uploads; locked deletion removes
  unshared blobs with content-free evidence.

source_files:
  - app/models/social_context_note.rb
  - app/models/relationship_profile.rb
  - app/models/draft_revision.rb
  - app/controllers/social_context_notes_controller.rb
  - app/controllers/concerns/relationship_profile_show_workspace.rb
  - app/policies/social_context_note_policy.rb
  - app/services/social_context_notes/analyze.rb
  - app/services/social_context_notes/analysis_input.rb
  - app/services/social_context_notes/open_ai_analyzer.rb
  - app/views/components/social_context_ledger_component.rb
  - app/views/components/social_context_ledger_component.html.erb
  - db/migrate/20260813120000_create_social_context_notes.rb

related_files:
  - app/models/automation_capability.rb
  - app/services/message_drafts/context_builder.rb
  - app/services/message_drafts/generate.rb
  - app/services/suggestions/for_profile.rb
  - app/serializers/data_exports/snapshot.rb
  - app/services/data_deletions/delete_blobs.rb
  - app/services/data_deletions/delete_account.rb
  - app/services/data_deletions/delete_ai_data.rb
  - config/deploy.yml
  - config/initializers/filter_parameter_logging.rb
  - config/locales/social_context_notes.en.yml
  - config/locales/social_context_notes.es.yml
  - db/migrate/20260813120001_add_social_context_note_deletion_kind.rb
  - docs/features/09-02-social-media-context-helper.md
  - spec/models/social_context_note_spec.rb
  - spec/services/social_context_notes/analyze_spec.rb
  - spec/services/social_context_notes/open_ai_analyzer_spec.rb
  - spec/requests/social_context_notes_spec.rb

symbols:
  - SocialContextNote
  - SocialContextNotesController
  - SocialContextNotePolicy
  - SocialContextNotes::Analyze
  - SocialContextNotes::AnalysisInput
  - SocialContextNotes::OpenAiAnalyzer
  - SocialContextLedgerComponent

routes:
  - relationship_profile_social_context_notes
  - relationship_profile_social_context_note
  - analyze_relationship_profile_social_context_note

tags:
  - relationship_profiles
  - social_context
  - user_consent
  - ai_review
  - lexxy
  - action_text
  - privacy

verification:
  - bundle exec rspec spec/models/social_context_note_spec.rb spec/services/social_context_notes spec/policies/social_context_note_policy_spec.rb spec/components/social_context_ledger_component_spec.rb spec/requests/social_context_notes_spec.rb spec/models/draft_revision_spec.rb spec/services/message_drafts/context_builder_spec.rb spec/services/message_drafts/generate_spec.rb spec/services/suggestions/for_profile_spec.rb spec/requests/data_controls_spec.rb spec/config/filter_parameter_logging_spec.rb spec/config/ai_memory_deploy_spec.rb
  - bin/rubocop
  - bin/memory validate
  - bin/memory coverage --git-diff
  - bin/memory audit --git-diff
  - bin/ci

last_verified_commit: null
---

# Social context is user-provided, review-gated, and revocable

## Claim

Social context starts only with relationship-scoped notes and supported images
the owner adds; Carecierge does not monitor social accounts. Downstream use is
disabled by default and remains revocable. Rich-text HTML is byte-bounded, and
images must resolve to allowlisted Active Storage blobs rather than raw remote or
data-URL elements.

Explicit, permission-gated analysis snapshots saved text and image identities
under the note lock before a non-stored provider request. AI output remains a
draft until the owner approves its text and uses. Opted-in owner text stays
separately user-provided, and only an approved message use adds inferred text to
drafting. Profile locks and generation fences prevent revoked context from
surviving in-flight generation.
Selective AI deletion clears interpretations, review state, proposed uses, and
analysis timestamps while preserving owner-authored notes and uploads; advancing
each note version prevents a delayed analysis from restoring deleted AI state.

## Why It Matters

Social content can be ambiguous, private, and easy to overinterpret. Keeping
capture manual, analysis explicit, AI output reviewable, provenance visible,
and downstream use revocable prevents covert monitoring and silent profiling.

## Evidence

- `app/models/social_context_note.rb`
- `app/services/social_context_notes/analyze.rb`
- `app/services/social_context_notes/open_ai_analyzer.rb`
- `app/views/components/social_context_ledger_component.html.erb`
- `spec/requests/social_context_notes_spec.rb`

## Verification

- `bundle exec rspec spec/models/social_context_note_spec.rb spec/services/social_context_notes spec/policies/social_context_note_policy_spec.rb spec/components/social_context_ledger_component_spec.rb spec/requests/social_context_notes_spec.rb spec/models/draft_revision_spec.rb spec/services/message_drafts/context_builder_spec.rb spec/services/message_drafts/generate_spec.rb spec/services/suggestions/for_profile_spec.rb spec/requests/data_controls_spec.rb spec/config/filter_parameter_logging_spec.rb spec/config/ai_memory_deploy_spec.rb`
- `bin/rubocop`
- `bin/memory validate`
- `bin/memory coverage --git-diff`
- `bin/memory audit --git-diff`
- `bin/ci`
