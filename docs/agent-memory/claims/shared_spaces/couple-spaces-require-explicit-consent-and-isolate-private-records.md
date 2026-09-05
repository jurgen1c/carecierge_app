---
id: shared_spaces.couple_spaces_require_explicit_consent_and_isolate_private_records
type: rule
system: shared_spaces
status: current
confidence: verified
severity: critical

title: Couple spaces require explicit consent and isolate private records

claim: >
  A couple space has a creator and one distinct confirmed-email invitee who explicitly accepts an in-app invitation within seven days. No shared content exists before acceptance; invitations send no external messages or reveal account existence. Active content is visible only to the two participants, separately from private profiles, notes, vaults, calendars and AI context. Free text and invitation email are encrypted; request inputs are filtered. Either person can confirm deleting the entire space; deleting either account does the same. Destruction locks the space and removes children before plans, subscriptions and reminder notifications. Account JSON/CSV exports include only active participating spaces in stable creation/ID order and the requester’s own reminder preference.

source_files:
  - app/models/shared_relationship_space.rb
  - app/controllers/shared_relationship_spaces_controller.rb
  - app/policies/shared_relationship_space_policy.rb
  - app/models/user.rb
  - app/serializers/data_exports/snapshot.rb
  - config/initializers/filter_parameter_logging.rb
  - db/migrate/20260905170230_create_shared_relationship_spaces.rb
  - db/schema.rb
  - spec/requests/shared_relationship_spaces_spec.rb
  - spec/models/shared_relationship_space_spec.rb

related_files:
  - app/views/dashboard/index.html.erb
  - docs/features/14-01-shared-couple-space.md
  - config/routes.rb
routes:
  - /shared_relationship_spaces
tags:
  - shared_spaces
  - privacy
  - consent
verification:
  - bundle exec rspec
  - bundle exec rspec spec/requests/shared_relationship_spaces_spec.rb spec/models/shared_relationship_space_spec.rb spec/jobs/dispatch_shared_reminders_job_spec.rb spec/system/shared_relationship_spaces_spec.rb
last_verified_commit: 146c481a6c6ee99ba303ad3f78d0eef64b5d2ee7
---

# Couple spaces require explicit consent and isolate private records

## Claim

A couple space has a creator and one distinct confirmed-email invitee who explicitly accepts an in-app invitation within seven days. No shared content exists before acceptance; invitations send no external messages or reveal account existence. Active content is visible only to the two participants, separately from private profiles, notes, vaults, calendars and AI context. Free text and invitation email are encrypted; request inputs are filtered. Either person can confirm deleting the entire space; deleting either account does the same. Destruction locks the space and removes children before plans, subscriptions and reminder notifications. Account JSON/CSV exports include only active participating spaces in stable creation/ID order and the requester’s own reminder preference.

## Why It Matters

Shared participation must never broaden access to either person's individual relationship data or silently impose reminders on them.
