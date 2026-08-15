---
id: data_controls.data_portability_and_deletion
type: fact
system: data_controls
status: current
confidence: high
severity: critical

title: Data exports and permanent deletion stay owner-scoped and privacy-minimized

claim: >
  Owner-scoped JSON, CSV, PDF, and private-calendar exports include recordings,
  social context and screenshots, relationships, localized labels, privacy-safe
  audit and reminder evidence, feed dismissal and snooze state, and effective
  message-draft response settings and revisions. Vault payloads require
  reauthentication; internal errors, leases,
  fences, recipient keys, and ownership keys stay excluded. Serialization
  neutralizes CSV formulas, preserves recurrences, uses the configured PDF
  origin, and audits only successful exports. Selective AI deletion preserves
  corrected memories and authored notes, clears note analysis without rereading
  unchanged screenshots, and fences delayed results. Profile and account
  deletion lock snapshots, revokes outstanding authenticated upload grants, and
  idempotently cleans attached or abandoned owner blobs. Feed visibility state
  is pruned when its source or relationship is permanently deleted and cascades
  with the account. Ownership stays in the nullifying foreign key rather than
  retained blob metadata. Completed account deletion retains only a one-way
  digest; OAuth users receive password setup.

source_files:
  - app/controllers/data_controls_controller.rb
  - app/controllers/data_exports_controller.rb
  - app/controllers/data_deletions_controller.rb
  - app/models/deletion_request.rb
  - app/models/concerns/feed_item_state_source.rb
  - app/models/feed_item_state.rb
  - app/serializers/data_exports/snapshot.rb
  - app/services/data_deletions/perform.rb
  - app/services/data_deletions/delete_account.rb
  - app/services/data_deletions/delete_ai_data.rb
  - app/services/data_deletions/delete_blobs.rb
  - app/controllers/direct_uploads_controller.rb
  - app/controllers/social_context_screenshots_controller.rb
  - app/jobs/purge_abandoned_social_context_upload_job.rb
  - db/migrate/20260808004436_create_deletion_requests.rb
  - db/migrate/20260813120002_add_uploaded_by_user_to_active_storage_blobs.rb
  - db/migrate/20260814160000_create_feed_item_states.rb

related_files:
  - app/serializers/data_exports/csv_serializer.rb
  - app/serializers/data_exports/calendar_serializer.rb
  - app/views/data_controls/show.html.erb
  - app/views/data_exports/summary.html.erb
  - docs/features/10-05-data-export-and-deletion.md
  - spec/requests/data_controls_spec.rb
  - spec/requests/social_context_notes_spec.rb
  - spec/jobs/purge_abandoned_social_context_upload_job_spec.rb
  - spec/services/data_deletions/delete_ai_data_spec.rb
  - spec/system/data_controls_spec.rb

symbols:
  - DirectUploadsController
  - SocialContextScreenshotsController
  - PurgeAbandonedSocialContextUploadJob
  - DataControlsController
  - DataExportsController
  - DataDeletionsController
  - DataExports::Snapshot
  - DataExports::CsvSerializer
  - DataExports::CalendarSerializer
  - DataDeletions::Perform
  - DataDeletions::DeleteAccount
  - DataDeletions::DeleteAiData
  - DeletionRequest

routes:
  - social_context_direct_upload
  - social_context_screenshot
  - data_control
  - data_exports
  - data_deletions

tags:
  - data_controls
  - data_portability
  - account_deletion

verification:
  - bundle exec rspec spec/jobs/purge_abandoned_social_context_upload_job_spec.rb spec/requests/direct_uploads_spec.rb spec/requests/data_controls_spec.rb spec/services/data_deletions/delete_ai_data_spec.rb spec/system/data_controls_spec.rb spec/requests/privacy_vaults_spec.rb spec/requests/relationship_profiles_spec.rb spec/requests/audit_event_integrations_spec.rb
  - bin/rubocop
  - bin/memory validate
  - bin/memory coverage --git-diff
  - bin/memory audit --git-diff
  - bin/ci

last_verified_commit: null
---

# Data exports and permanent deletion stay owner-scoped and privacy-minimized

## Claim

Every export format uses the same owner scope, and decrypted vault payloads
require password reauthentication. JSON and CSV include privacy-safe evidence,
  message revisions, social notes, consent state, screenshot bytes, and feed
  visibility state while excluding internal keys, errors, leases, and fences.
  Serialization neutralizes
formulas, preserves recurrences, and audits only success. Selective AI deletion
preserves authored content while clearing and fencing inferred state. Profile and
account deletion snapshot under owned locks; upload writes share the account lock,
and cleanup includes attached or abandoned owner-stamped blobs. Permanently
deleted feed sources and relationships also prune obsolete feed visibility rows.
Ownership lives only in a nullifying foreign key, and a retrying expiry job
cleans abandoned uploads without retaining owner UUIDs in metadata.

## Why It Matters

Exports aggregate the most sensitive records in the product, while deletion
must be irreversible without becoming unauditable. One owner-scoped snapshot,
password-gated vault inclusion, allowlisted deletion kinds, and metadata-only
evidence keep portability and erasure predictable without copying private
content into a second store.

## Evidence

- `app/controllers/data_exports_controller.rb`
- `app/serializers/data_exports/snapshot.rb`
- `app/services/data_deletions/perform.rb`
- `app/models/deletion_request.rb`
- `app/models/concerns/feed_item_state_source.rb`
- `spec/requests/data_controls_spec.rb`
- `spec/services/data_deletions/delete_ai_data_spec.rb`

## Verification

- `bundle exec rspec spec/jobs/purge_abandoned_social_context_upload_job_spec.rb spec/requests/direct_uploads_spec.rb spec/requests/data_controls_spec.rb spec/services/data_deletions/delete_ai_data_spec.rb spec/system/data_controls_spec.rb spec/requests/privacy_vaults_spec.rb spec/requests/relationship_profiles_spec.rb spec/requests/audit_event_integrations_spec.rb`
- `bin/rubocop`
- `bin/memory validate`
- `bin/memory coverage --git-diff`
- `bin/memory audit --git-diff`
- `bin/ci`
