---
id: data_controls.data_portability_and_deletion
type: fact
system: data_controls
status: current
confidence: high
severity: critical

title: Data exports and permanent deletion stay owner-scoped and privacy-minimized

claim: >
  Authenticated users can export one owner-scoped profile or their account as
  JSON, CSV, PDF, or a private calendar. Portable snapshots include recordings,
  relationship assignments, localized labels, privacy-safe audit history,
  reminder delivery evidence, and message-draft settings with immutable
  revisions; internal errors, leases, recipient keys, and ownership foreign
  keys remain excluded. Vault payloads require password reauthentication.
  CSV cells neutralize formulas, calendar recurrences preserve clamping, PDFs
  use the configured application origin, and attachment exports use native
  navigation. Successful exports emit content-free audit evidence only after
  serialization. Owner-scoped deletion records privacy-minimized evidence;
  selective AI deletion preserves user-corrected memories, while profile and
  account deletion cascade through their owned content. Recording cleanup locks
  blobs against concurrent attachments and remains retryable and idempotent.
  Completed account deletion retains only a one-way account digest and
  nullified user reference; OAuth users receive a password-setup path first.

source_files:
  - app/controllers/data_controls_controller.rb
  - app/controllers/data_exports_controller.rb
  - app/controllers/data_deletions_controller.rb
  - app/models/deletion_request.rb
  - app/serializers/data_exports/snapshot.rb
  - app/services/data_deletions/perform.rb
  - app/services/data_deletions/delete_account.rb
  - db/migrate/20260808004436_create_deletion_requests.rb

related_files:
  - app/serializers/data_exports/csv_serializer.rb
  - app/serializers/data_exports/calendar_serializer.rb
  - app/services/data_deletions/delete_ai_data.rb
  - app/views/data_controls/show.html.erb
  - app/views/data_exports/summary.html.erb
  - docs/features/10-05-data-export-and-deletion.md
  - spec/requests/data_controls_spec.rb
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
require password reauthentication. Native form navigation lets browsers handle
downloads. Full-account JSON and CSV include privacy-safe vault-access,
notification, reminder-delivery evidence, and each profile's message-draft
settings and immutable revision history without ownership foreign keys. Internal
errors, leases, concurrency fences, and notification recipient keys stay excluded. Permanent
deletion records content-free evidence, preserves user-corrected memories during
selective AI cleanup, prevents in-flight extraction from recreating deleted
state, and safely serializes recording removal against shared attachments.

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
