---
id: data_controls.data_portability_and_deletion
type: fact
system: data_controls
status: needs_verification
confidence: high
severity: critical

title: Data exports and permanent deletion stay owner-scoped and privacy-minimized

claim: >
  Contacts exports include staged review data and safe provider metadata while excluding OAuth credentials and opaque provider identifiers. Account deletion revokes contacts access and fences restored credentials after a local rollback; revocation failure preserves the account for retry.
  Owner-scoped JSON, CSV, PDF, and private-calendar exports include recordings,
  social context and screenshots, relationships, localized labels,
  audit and reminder evidence, feed dismissal and snooze state, suggestion
  feedback/save/completion state, approval requests and append-only decisions,
  message-draft response settings and revisions. Relationship briefings and
  gift recommendations, event plans, plan tasks, decrypted manual bookings,
  and decrypted manual vendor quotes with embedded vendor provenance are
  included with source-backed output and consent metadata, while generation
  fences stay excluded. Ordinary exports keep sensitive backup-source
  provenance but redact the plaintext source content. Vault payloads and
  unredacted sensitive backup sources require reauthentication; internal
  secrets, leases, fences, and ownership keys stay excluded. Serialization
  neutralizes CSV formulas, preserves recurrences, uses the configured PDF
  origin, and audits only successful exports. Selective AI deletion preserves
  corrected memories, authored notes, and gifts accepted from recommendations;
  deletes relationship briefings, gift recommendations, and AI-origin plan
  tasks while retaining non-AI birthday, anniversary, and selected prior-plan
  provenance; restores template/manual work superseded by actually promoted AI
  backup options only after template preferences have reconciled that superseded
  work, without reviving removed managed steps or user-deleted template tombstones
  or retaining their authored content, with untouched template deadlines aligned after rescheduling,
  and preserves event plans and explicit plan reminders even for terminal plans; clears note analysis
  without rereading unchanged screenshots; and fences delayed results. Profile and account
  deletion lock snapshots, revoke upload grants and connected calendar access,
  and idempotently clean owner blobs. Feed state is pruned
  when its source or relationship is deleted and cascades
  with the account. Ownership stays in the nullifying foreign key rather than
  retained blob metadata. Account deletion retains only a one-way digest,
  offers OAuth users password setup, prevents Devise deletion from bypassing the
  guarded flow, and aborts with credentials intact if calendar revocation
  fails. Failure to revoke a pending callback credential does not mark an
  as-yet untouched live connection as failed. A local rollback after successful provider revocation instead retains
  the account with a fenced reconnect-required calendar state before releasing
  the uninterrupted owner lock. Selective deletion uses FOR NO KEY UPDATE on
  the owner row so foreign-key checks remain compatible with the boundary;
  whole-account deletion retains an exclusive owner lock so concurrent child
  creation cannot race after irreversible provider revocation.

source_files:
  - app/controllers/data_controls_controller.rb
  - app/controllers/data_exports_controller.rb
  - app/controllers/data_deletions_controller.rb
  - app/controllers/users/registrations_controller.rb
  - app/models/deletion_request.rb
  - app/models/concerns/feed_item_state_source.rb
  - app/models/feed_item_state.rb
  - app/models/suggestion_feedback.rb
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
  - db/migrate/20260820034510_add_saved_at_to_suggestion_feedbacks.rb
  - db/migrate/20260821040000_create_event_plans.rb
  - db/migrate/20260821040001_add_event_plan_references_to_reminders.rb
  - db/migrate/20260903042850_create_vendor_quotes.rb
  - db/migrate/20260903044916_add_vendor_quote_reference_to_reminders.rb
  - app/models/booking.rb
  - db/migrate/20260903120000_create_bookings.rb
  - app/models/calendar_connection.rb
  - app/models/calendar_event_sync.rb
  - app/services/calendar_connections/disconnect.rb

related_files:
  - app/models/approval_request.rb
  - app/models/approval_decision.rb
  - app/models/relationship_briefing.rb
  - app/models/gift_recommendation.rb
  - app/models/event_plan.rb
  - app/models/plan_task.rb
  - app/models/vendor_quote.rb
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
  - spec/serializers/data_exports/snapshot_spec.rb
  - spec/requests/vendor_quotes_spec.rb
  - spec/serializers/data_exports/booking_snapshot_spec.rb
  - spec/services/calendar_connections/disconnect_spec.rb

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
  - VendorQuote
  - Booking
  - CalendarConnection
  - CalendarEventSync

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

Exports are owner-scoped, and decrypted vault payloads require reauthentication.
They include user-facing records, source provenance, consent state, screenshots,
and privacy-safe evidence while excluding internal keys, errors, leases, and
fences. Serialization neutralizes formulas, preserves recurrences, and audits
only success. Selective AI deletion removes generated work and fences delayed
results while preserving authored work, accepted gifts, plans, non-AI provenance,
and explicit reminders. Profile and account deletion snapshot under owned locks,
revoke calendar access and upload grants, and clean owner-stamped blobs. Failed
calendar revocation preserves the account and credentials for recovery. Deleted
sources prune feed state; abandoned-upload cleanup retains no owner UUID metadata.

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
