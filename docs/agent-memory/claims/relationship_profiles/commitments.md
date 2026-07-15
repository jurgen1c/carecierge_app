---
id: relationship_profiles.commitments
type: fact
system: relationship_profiles
status: current
confidence: high
severity: important

title: Commitments track owner-scoped promises through reminders and timeline history

claim: >
  Commitment records belong to a RelationshipProfile and are managed through
  authenticated, owner-scoped nested routes. Commitments require titles at both
  the model and database layers and normalize user-authored title text,
  optional private notes, optional due dates, open/completed/canceled status, and
  completion time; overdue is derived only for open commitments whose due date is
  past. Explicit complete, cancel, and reopen transitions serialize on the record;
  closing a commitment retires active linked reminders, while reopening leaves
  those historical reminder schedules completed.
  Each commitment owns a protected system promise TimelineEntry and may own many
  reusable Reminder records from the existing reminder delivery system. Profile
  associations apply the domain ordering before commitments reach the view. The
  relationship profile supports localized Turbo CRUD and lifecycle actions, while
  the existing reminder workspace shows owner-scoped overdue commitments and
  respects its relationship filter. Reminder form commitment options remain
  owner-scoped even when persisted reminder data is inconsistent, and association
  validation errors are localized in English and Spanish. Commitment notes are filtered from request
  logs, and future note extraction must remain review-gated rather than creating
  commitments automatically.

source_files:
  - app/models/commitment.rb
  - app/controllers/commitments_controller.rb
  - app/policies/commitment_policy.rb
  - app/services/commitments/save.rb
  - app/views/commitments/_section.html.erb
  - app/views/commitments/_commitment.html.erb
  - db/migrate/20260714141911_create_commitments.rb
  - db/migrate/20260714141912_add_commitment_to_reminders.rb

related_files:
  - spec/models/commitment_spec.rb
  - spec/policies/commitment_policy_spec.rb
  - spec/requests/commitments_spec.rb
  - spec/requests/commitment_reminders_spec.rb
symbols:
  - Commitment
  - CommitmentPolicy
  - Commitments::Save
  - CommitmentsController
  - RelationshipProfile#commitments
  - Reminder#commitment
routes:
  - relationship_profile_commitments
  - relationship_profile_commitment
  - new_relationship_profile_commitment
  - edit_relationship_profile_commitment
  - complete_relationship_profile_commitment
  - cancel_relationship_profile_commitment
  - reopen_relationship_profile_commitment
tags:
  - commitments
  - follow_through

verification:
  - bundle exec rspec spec/models/commitment_spec.rb spec/models/reminder_spec.rb spec/policies/commitment_policy_spec.rb spec/requests/commitments_spec.rb spec/requests/commitment_reminders_spec.rb spec/requests/reminders_spec.rb spec/requests/timeline_entries_spec.rb
  - bin/rubocop
  - bin/ci
last_verified_commit: null
---

# Commitments track owner-scoped promises through reminders and timeline history

## Claim

Carecierge tracks manual promises inside the existing relationship-profile
workspace. Commitments have explicit lifecycle transitions, derive overdue state
from due dates, create source-backed timeline history, and extend the shared
Reminder scheduler for one or more notifications. Closing a commitment retires
its active notifications; reopening requires an intentional new schedule. The global reminder workspace
is also the overdue-commitment view. Automated extraction remains deferred until
a later user-review workflow exists.

## Why It Matters

Forgotten promises can damage relationships, but commitments must not create a
parallel scheduler, history store, or privacy boundary. Reusing the reminder,
timeline, and relationship ownership systems keeps follow-through explainable,
localized, and tenant-safe.

## Evidence

- `app/models/commitment.rb`
- `app/services/commitments/save.rb`
- `app/controllers/commitments_controller.rb`
- `app/controllers/reminders_controller.rb`
- `spec/requests/commitments_spec.rb`
- `spec/requests/commitment_reminders_spec.rb`

## Verification

- `bundle exec rspec spec/models/commitment_spec.rb spec/models/reminder_spec.rb spec/policies/commitment_policy_spec.rb spec/requests/commitments_spec.rb spec/requests/commitment_reminders_spec.rb spec/requests/reminders_spec.rb spec/requests/timeline_entries_spec.rb`
- `bin/rubocop`
- `bin/ci`
