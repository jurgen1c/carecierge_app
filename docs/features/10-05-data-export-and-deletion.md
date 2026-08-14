# 10.5 Data Export and Deletion

**Area:** 10. Privacy, Safety, and Control

Authenticated users can export or permanently delete their owner-scoped data
from the Data controls page. The surface uses explicit confirmations and keeps
protected vault payloads out of exports unless the account password is
re-entered.

## Capabilities

- Export one owned relationship profile or the full account.
- Include relationship details, timeline records, important dates, memories,
  AI-origin metadata, preferences, reminders, uploaded conversation recordings,
  reminder-delivery lifecycle evidence, tag/group assignments, relationship
  notification overrides, privacy-safe vault-access history, in-app notification
  state, and related account records.
- Exclude decrypted privacy-vault payloads by default; password reauthentication
  can include owned protected payloads in the same export.
- Export reminders and important dates as a private calendar file.
- Delete profiles from their existing owner-scoped profile surface.
- Permanently delete a protected note, memory, or relationship detail only from
  an unlocked privacy vault.
- Delete only AI-inferred memories and AI-extraction timeline records without
  removing user-confirmed or manually-created records.
- Delete the full account only after exact email confirmation and current
  password verification.

## Export Formats

- JSON
- CSV
- PDF summary
- Calendar file

## Data Objects

- `DeletionRequest`

`DeletionRequest` is a privacy-minimized lifecycle ledger. It stores a one-way
account digest, request kind, optional resource type and UUID, and completion
state. Account deletion nullifies its user reference so the request remains
auditable without retaining the account email or relationship contents.

## Implementation

- `DataExports::Snapshot` creates an explicit portable representation instead
  of exposing authentication secrets or arbitrary database columns.
- `DataExports::CsvSerializer` flattens the same snapshot; the JSON and CSV
  outputs therefore cover the same records. Uploaded recordings use base64
  content with filename and media metadata, and formula-leading cells are
  neutralized for spreadsheet safety.
- PDF is a human-readable summary rendered through `FerrumPdf`.
- PDF rendering uses the configured application origin rather than request host
  headers, follows the configured environment protocol, and uses HTTP for the
  default localhost development server. Relationship-type labels follow the
  active locale.
- `DataExports::CalendarSerializer` combines reminder events with all-day
  important-date events while explicitly enumerating recurrences whose
  end-of-month clamping cannot be represented by a bare recurrence rule.
- A successful serialization records `data_export.requested` with only the
  scope/format and completion result.
- `DataDeletions::Perform` writes `data_deletion.requested` and the durable
  deletion request around each successful destructive operation.
- Selective AI deletion preserves user-authored social notes and uploads while
  clearing their interpretations, proposed uses, review state, and analysis
  timestamps. It advances note versions and the shared message-generation fence
  so delayed provider output cannot recreate deleted AI state.
- Account deletion synchronously purges uploaded recordings before the request
  can be marked completed. Storage files are deleted before their blob rows so a
  failure leaves retryable metadata and failed evidence; blobs still attached to
  another account are preserved. A blob row lock spans the final attachment
  check and purge so concurrent attachment creation cannot race storage deletion.
  If Active Storage already removed a blob row, the captured storage key receives
  one final idempotent delete and the account request completes.
- Note deletion captures its screenshot blobs while holding the relationship
  lock. Profile and account deletion lock the owned relationship rows before
  snapshotting screenshots, closing the gap between snapshot and cascade.
- User-targeted feature-flag assignments are removed with the account, and
  Google-authenticated users receive a direct password-setup path before the
  password-gated action.
- Email confirmations and passwords are filtered from request logs.
- Export responses and the Data controls page disable caching and Turbo
  snapshots because they expose private account context.
- Export forms bypass Turbo and use native browser navigation so attachment
  responses reach the browser download manager.
- Calendar-only exports bypass full account snapshot construction.

## Verification

- `bundle exec rspec spec/requests/data_controls_spec.rb spec/system/data_controls_spec.rb`
- `bundle exec rspec spec/requests/privacy_vaults_spec.rb spec/requests/relationship_profiles_spec.rb spec/requests/audit_event_integrations_spec.rb`
- `bin/memory validate`
- `bin/memory coverage --git-diff`
- `bin/memory audit --git-diff`
- `bin/ci`
