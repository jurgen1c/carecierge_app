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
  audit and reminder evidence, and effective message-draft response settings and
  revisions. Vault payloads require reauthentication; internal errors, leases,
  fences, recipient keys, and ownership keys stay excluded. Serialization
  neutralizes CSV formulas, preserves recurrences, uses the configured PDF
  origin, and audits only successful exports. Selective AI deletion preserves
  corrected memories and authored notes, clears note analysis without rereading
  unchanged screenshots, and fences delayed results. Profile and account
  deletion lock snapshots and idempotently clean shared blobs. Completed account
  deletion retains only a one-way digest; OAuth users receive password setup.

source_files:
  - app/controllers/data_controls_controller.rb
  - app/controllers/data_exports_controller.rb
  - app/controllers/data_deletions_controller.rb
  - app/models/deletion_request.rb
  - app/serializers/data_exports/snapshot.rb
  - app/services/data_deletions/perform.rb
  - app/services/data_deletions/delete_account.rb
  - app/services/data_deletions/delete_ai_data.rb
  - app/services/data_deletions/delete_blobs.rb
  - db/migrate/20260808004436_create_deletion_requests.rb

related_files:
  - app/serializers/data_exports/csv_serializer.rb
  - app/serializers/data_exports/calendar_serializer.rb
  - app/views/data_controls/show.html.erb
  - app/views/data_exports/summary.html.erb
  - docs/features/10-05-data-export-and-deletion.md
  - spec/requests/data_controls_spec.rb
  - spec/requests/social_context_notes_spec.rb
  - spec/services/data_deletions/delete_ai_data_spec.rb
  - spec/system/data_controls_spec.rb

symbols:
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
  - data_control
  - data_exports
  - data_deletions

tags:
  - data_controls
  - data_portability
  - account_deletion

verification:
  - bundle exec rspec spec/requests/data_controls_spec.rb spec/services/data_deletions/delete_ai_data_spec.rb spec/system/data_controls_spec.rb spec/requests/privacy_vaults_spec.rb spec/requests/relationship_profiles_spec.rb spec/requests/audit_event_integrations_spec.rb
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
require password reauthentication. Full-account JSON and CSV include
privacy-safe access and reminder evidence, effective message-draft response
settings and revisions, and social-note text, review state, consent state, and
screenshot bytes. They exclude ownership keys, lock versions, internal errors,
leases, fences, and recipient keys. Legacy casual or formal tones export as a
coherent warm tone and matching formality. Native navigation handles downloads,
and only successful serialization emits content-free audit evidence. Selective
AI deletion uses a non-key-changing profile lock, preserves corrected memories
and authored notes, clears note analysis without rereading unchanged screenshot
storage, and fences delayed extraction and message-draft results. Note, profile,
and account deletion snapshot under owned profile locks; blob cleanup serializes
shared recording and screenshot removal.

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
- `spec/requests/data_controls_spec.rb`
- `spec/services/data_deletions/delete_ai_data_spec.rb`

## Verification

- `bundle exec rspec spec/requests/data_controls_spec.rb spec/services/data_deletions/delete_ai_data_spec.rb spec/system/data_controls_spec.rb spec/requests/privacy_vaults_spec.rb spec/requests/relationship_profiles_spec.rb spec/requests/audit_event_integrations_spec.rb`
- `bin/rubocop`
- `bin/memory validate`
- `bin/memory coverage --git-diff`
- `bin/memory audit --git-diff`
- `bin/ci`
