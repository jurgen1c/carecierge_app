---
id: shared_spaces.couple_spaces_require_explicit_consent_and_isolate_private_records
type: rule
system: shared_spaces
status: current
confidence: high
severity: critical

title: Couple spaces require explicit consent and isolate private records

claim: >
  A shared couple space has a creator and at most one distinct confirmed-email invitee who explicitly accepts an in-app invitation within seven days. No content can be added before acceptance, and invitation creation never sends external messages or reveals whether an account exists. Only these participants can read the active shared workspace. Shared records are structurally separate from private profiles, notes, vaults, calendars and AI context. Titles, details and invitation email are encrypted at rest and submitted inputs are filtered from logs. Either participant can explicitly delete the entire shared workspace; deleting either account does the same, removing items, subscriptions and reminder notification history. All space destruction takes the space lock and deletes child items before their parent plans to preserve optimistic revisions during dependent deletion. Account JSON/CSV exports include only active participating spaces and the requester's own reminder subscription preference.

source_files:
  - app/models/shared_relationship_space.rb
  - app/controllers/shared_relationship_spaces_controller.rb
  - app/policies/shared_relationship_space_policy.rb
  - app/models/user.rb
  - app/serializers/data_exports/snapshot.rb
  - config/initializers/filter_parameter_logging.rb
  - db/migrate/20260905170230_create_shared_relationship_spaces.rb
  - spec/requests/shared_relationship_spaces_spec.rb
  - spec/models/shared_relationship_space_spec.rb

related_files:
  - docs/features/14-01-shared-couple-space.md
  - config/routes.rb
routes:
  - /shared_relationship_spaces
tags:
  - shared_spaces
  - privacy
  - consent
verification:
  - bundle exec rspec spec/requests/shared_relationship_spaces_spec.rb spec/models/shared_relationship_space_spec.rb spec/jobs/dispatch_shared_reminders_job_spec.rb spec/system/shared_relationship_spaces_spec.rb
last_verified_commit: null
---

# Couple spaces require explicit consent and isolate private records

## Claim

A shared couple space has a creator and at most one distinct confirmed-email invitee who explicitly accepts an in-app invitation within seven days. No content can be added before acceptance, and invitation creation never sends external messages or reveals whether an account exists. Only these participants can read the active shared workspace. Shared records are structurally separate from private profiles, notes, vaults, calendars and AI context. Titles, details and invitation email are encrypted at rest and submitted inputs are filtered from logs. Either participant can explicitly delete the entire shared workspace; deleting either account does the same, removing items, subscriptions and reminder notification history. All space destruction takes the space lock and deletes child items before their parent plans to preserve optimistic revisions during dependent deletion. Account JSON/CSV exports include only active participating spaces and the requester's own reminder subscription preference.

## Why It Matters

Shared participation must never broaden access to either person's individual relationship data or silently impose reminders on them.
