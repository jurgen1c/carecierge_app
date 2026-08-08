---
id: data_controls.data_portability_and_deletion
type: fact
system: data_controls
status: current
confidence: high
severity: critical

title: Data exports and permanent deletion stay owner-scoped and privacy-minimized

claim: >
  The authenticated Data controls surface exports either one owner-scoped
  relationship profile or the full account as JSON, CSV, a PDF summary, or a
  private calendar containing reminders and important dates. Protected vault
  payloads are excluded unless the current password is re-entered. Portable
  JSON and CSV snapshots include uploaded conversation recordings as base64,
  relationship assignment joins, and localized type labels. CSV cells
  neutralize formula-leading input, clamped date recurrences are preserved in
  calendar exports, calendar-only requests skip snapshot construction, and PDF
  rendering uses the configured application origin. Export forms use native
  browser navigation so attachment responses reach the download manager.
  Successful exports emit content-free AuditEvent evidence only after serialization.
  Profile deletion, unlocked protected-item deletion, selective removal of
  AI-inferred memories and AI-extraction timeline records, and password-gated
  account deletion create privacy-minimized DeletionRequest evidence. Account
  deletion removes user-targeted feature assignments and synchronously deletes
  uploaded recordings while retaining retryable blob rows on storage failure.
  Each recording purge locks its blob across the final attachment check and
  storage deletion so a concurrent cross-account attachment cannot lose data.
  Completion leaves only a one-way account digest and nullified user reference;
  emails, credentials, and relationship contents are not retained. OAuth users
  receive an explicit password-setup path before password-gated deletion.

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
  - bundle exec rspec spec/requests/data_controls_spec.rb spec/system/data_controls_spec.rb spec/requests/privacy_vaults_spec.rb spec/requests/relationship_profiles_spec.rb spec/requests/audit_event_integrations_spec.rb
  - bin/rubocop
  - bin/memory validate
  - bin/memory coverage --git-diff
  - bin/memory audit --git-diff
  - bin/ci

last_verified_commit: null
---

# Data exports and permanent deletion stay owner-scoped and privacy-minimized

## Claim

Carecierge provides portable account and relationship-profile exports without
turning the export endpoint into a tenant or vault bypass. The same owner scope
feeds every format. Password reauthentication is required before decrypted
vault payloads enter an export. Export forms bypass Turbo so attachment
responses are handled by the browser's download manager.

Permanent deletion uses explicit confirmation at the presentation boundary and
records content-free lifecycle evidence. Selective AI deletion targets only
`MemoryRecord.source = ai_inferred` and `TimelineEntry.entry_type =
ai_extraction` records whose origin is `system`. Account deletion destroys the
account graph while a detached deletion request retains only a keyed digest and
lifecycle timestamps. Recording blobs are purged only when no attachment from
another account remains, with the blob row locked across that check and purge
to serialize concurrent attachment creation.

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

## Verification

- `bundle exec rspec spec/requests/data_controls_spec.rb spec/system/data_controls_spec.rb spec/requests/privacy_vaults_spec.rb spec/requests/relationship_profiles_spec.rb spec/requests/audit_event_integrations_spec.rb`
- `bin/rubocop`
- `bin/memory validate`
- `bin/memory coverage --git-diff`
- `bin/memory audit --git-diff`
- `bin/ci`
