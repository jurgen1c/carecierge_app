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
  social-account monitoring. Short-lived uploads are authenticated and
  owner-locked for both grant and storage writes, then stamped only in an indexed
  owner column. Expired unattached uploads receive scheduled cleanup.
  Authenticated no-store reads return bounded, lazy previews without narrowing
  other editors; notes reject cross-account blobs and detect image types from
  stored bytes for new or changed sources. Downstream use is off by default and
  revocable even when unchanged screenshot storage is unavailable.
  Permission-gated, non-stored analysis stays reviewable. Account-to-profile
  lock ordering and version fences prevent deadlocks and stale outputs. Selective
  AI deletion preserves owner text while clearing analysis without rereading
  unchanged uploads. Exports include uploads; locked deletion removes unshared
  blobs with content-free evidence.

source_files:
  - app/controllers/direct_uploads_controller.rb
  - app/controllers/social_context_screenshots_controller.rb
  - app/jobs/purge_abandoned_social_context_upload_job.rb
  - app/policies/social_context_screenshot_policy.rb
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
  - app/views/active_storage/blobs/_blob.html.erb
  - config/initializers/action_text_image_loading.rb
  - db/migrate/20260813120000_create_social_context_notes.rb
  - db/migrate/20260813120002_add_uploaded_by_user_to_active_storage_blobs.rb

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
  - config/routes.rb
  - config/initializers/filter_parameter_logging.rb
  - config/locales/social_context_notes.en.yml
  - config/locales/social_context_notes.es.yml
  - db/migrate/20260813120001_add_social_context_note_deletion_kind.rb
  - docs/features/09-02-social-media-context-helper.md
  - spec/models/social_context_note_spec.rb
  - spec/jobs/purge_abandoned_social_context_upload_job_spec.rb
  - spec/requests/direct_uploads_spec.rb
  - spec/requests/social_context_screenshots_spec.rb
  - spec/services/social_context_notes/analyze_spec.rb
  - spec/services/social_context_notes/open_ai_analyzer_spec.rb
  - spec/requests/social_context_notes_spec.rb

symbols:
  - SocialContextNote
  - SocialContextNotesController
  - SocialContextNotePolicy
  - SocialContextScreenshotsController
  - SocialContextScreenshotPolicy
  - PurgeAbandonedSocialContextUploadJob
  - SocialContextNotes::Analyze
  - SocialContextNotes::AnalysisInput
  - SocialContextNotes::OpenAiAnalyzer
  - SocialContextLedgerComponent

routes:
  - social_context_direct_uploads
  - social_context_direct_upload
  - social_context_screenshot
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
  - bundle exec rspec spec/models/social_context_note_spec.rb spec/jobs/purge_abandoned_social_context_upload_job_spec.rb spec/services/social_context_notes spec/policies/social_context_note_policy_spec.rb spec/components/social_context_ledger_component_spec.rb spec/requests/direct_uploads_spec.rb spec/requests/social_context_screenshots_spec.rb spec/requests/social_context_notes_spec.rb spec/models/draft_revision_spec.rb spec/services/message_drafts/context_builder_spec.rb spec/services/message_drafts/generate_spec.rb spec/services/suggestions/for_profile_spec.rb spec/requests/data_controls_spec.rb spec/config/filter_parameter_logging_spec.rb spec/config/ai_memory_deploy_spec.rb
  - bin/rubocop
  - bin/memory validate
  - bin/memory coverage --git-diff
  - bin/memory audit --git-diff
  - bin/ci

last_verified_commit: null
---

# Social context is user-provided, review-gated, and revocable

## Claim

Owners add bounded notes and images; Carecierge does not monitor social accounts.
Ten-minute upload grants and proxied writes require the same locked account and
stamp only an indexed owner column; no owner identifier is copied into blob
metadata. A retrying job removes uploads still unattached after one hour, while
account deletion captures attached and unattached blobs under its lock and
revokes grants. Saved embeds and previews use owner-authorized, no-store,
resized, lazy reads; other Lexxy editors retain their standard upload contract.
Notes accept only owner-matched supported image bytes.
Saved ownership, count, and size checks remain enforceable without rereading
unchanged storage, so consent revocation and selective AI deletion survive
storage failures. Downstream use starts off and stays revocable. Permission-gated
analysis snapshots saved content before non-stored provider I/O and stays draft
until review. Reanalysis clears prior output and advances fences first; completion
locks account, profile, then note. Only opted-in owner text and approved
interpretations enter drafting. Selective deletion preserves owner content while
clearing AI state and fencing delayed results.

## Why It Matters

Social content can be ambiguous, private, and easy to overinterpret. Keeping
capture manual, analysis explicit, AI output reviewable, provenance visible,
and downstream use revocable prevents covert monitoring and silent profiling.

## Evidence

- `app/models/social_context_note.rb`
- `app/controllers/direct_uploads_controller.rb`
- `app/services/social_context_notes/analyze.rb`
- `app/services/social_context_notes/open_ai_analyzer.rb`
- `app/views/components/social_context_ledger_component.html.erb`
- `spec/requests/social_context_notes_spec.rb`

## Verification

- `bundle exec rspec spec/models/social_context_note_spec.rb spec/jobs/purge_abandoned_social_context_upload_job_spec.rb spec/services/social_context_notes spec/policies/social_context_note_policy_spec.rb spec/components/social_context_ledger_component_spec.rb spec/requests/direct_uploads_spec.rb spec/requests/social_context_screenshots_spec.rb spec/requests/social_context_notes_spec.rb spec/models/draft_revision_spec.rb spec/services/message_drafts/context_builder_spec.rb spec/services/message_drafts/generate_spec.rb spec/services/suggestions/for_profile_spec.rb spec/requests/data_controls_spec.rb spec/config/filter_parameter_logging_spec.rb spec/config/ai_memory_deploy_spec.rb`
- `bin/rubocop`
- `bin/memory validate`
- `bin/memory coverage --git-diff`
- `bin/memory audit --git-diff`
- `bin/ci`
