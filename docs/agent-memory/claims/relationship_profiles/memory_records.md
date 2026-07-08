---
id: relationship_profiles.memory_records
type: fact
system: relationship_profiles
status: current
confidence: high
severity: important

title: Memory records track source, confidence, review, and automation approval

claim: >
  MemoryRecord records belong to a RelationshipProfile and are managed through
  authenticated, owner-scoped nested routes. Memory records store title, body,
  source, confidence, status, stale review date, review timestamps, and
  high-impact automation approval state. Users can add, edit, review, delete,
  correct, and approve records inline from the relationship profile through
  Turbo streams; corrections create MemoryRevision rows with previous body,
  revised body, note, and correcting user in the same database transaction as
  the body update. Archived records are not reviewable, and review actions
  report an error instead of success when the review transition is rejected or
  fails validation. Low-confidence, inferred-confidence, or AI-inferred records
  are blocked from high-impact automation until explicitly approved.

source_files:
  - app/models/memory_record.rb
  - app/models/memory_revision.rb
  - app/controllers/memory_records_controller.rb
  - app/policies/memory_record_policy.rb
  - app/views/memory_records/_section.html.erb
  - app/views/memory_records/_memory_record.html.erb
  - app/views/memory_records/_form.html.erb
  - db/migrate/20260708120000_create_memory_records.rb
  - db/migrate/20260708120100_create_memory_revisions.rb

related_files:
  - spec/models/memory_record_spec.rb
  - spec/policies/memory_record_policy_spec.rb
  - spec/requests/memory_records_spec.rb
symbols:
  - MemoryRecord
  - MemoryRevision
  - MemoryRecordsController
  - MemoryRecordPolicy
  - MemoryRecord#review_required?
  - MemoryRecord#high_impact_automation_allowed?
  - MemoryRecord#queue_review_if_stale!
routes:
  - relationship_profile_memory_records
  - relationship_profile_memory_record
  - new_relationship_profile_memory_record
  - edit_relationship_profile_memory_record
  - review_relationship_profile_memory_record
  - approve_high_impact_automation_relationship_profile_memory_record
tags:
  - memory_records
  - memory_confidence
  - automation_guardrails

verification:
  - bundle exec rspec spec/models/memory_record_spec.rb spec/policies/memory_record_policy_spec.rb spec/requests/memory_records_spec.rb
  - bundle exec rspec spec/requests/relationship_profiles_spec.rb spec/models/memory_record_spec.rb spec/policies/memory_record_policy_spec.rb spec/requests/memory_records_spec.rb
  - bundle exec rspec
last_verified_commit: null
---

# Memory records track source, confidence, review, and automation approval

## Claim

Memory records are relationship-profile-owned records used to store remembered
facts with explicit source, confidence, lifecycle status, and review metadata.
They are managed through authenticated nested routes under the signed-in user's
relationship profiles and update the relationship profile memory section inline
through Turbo streams. Editing a memory body marks the record corrected and
creates a MemoryRevision with the previous body, revised body, correction note,
and correcting user in the same database transaction as the body update, so a
failed revision rolls the correction back. Records that are stale or queued for
review surface review actions, but archived records remain non-reviewable and
cannot be reactivated by review actions. Review actions report failure rather
than success when the transition is rejected or validation fails. Low-confidence,
inferred-confidence, or AI-inferred records are blocked from high-impact
automation until the user explicitly approves that use; trusted imported or
user-corrected records can be used without separate approval.

## Why It Matters

Memory records can hold sensitive personal context and may feed future AI,
suggestion, purchase, booking, or outreach flows. Source, confidence, stale
review, and approval metadata keep automation explainable, reversible, and
bounded by the existing relationship-profile privacy boundary.

## Evidence

- `app/models/memory_record.rb`
- `app/models/memory_revision.rb`
- `app/controllers/memory_records_controller.rb`
- `app/policies/memory_record_policy.rb`
- `app/views/memory_records/_section.html.erb`
- `db/migrate/20260708120000_create_memory_records.rb`
- `db/migrate/20260708120100_create_memory_revisions.rb`
- `spec/models/memory_record_spec.rb`
- `spec/policies/memory_record_policy_spec.rb`
- `spec/requests/memory_records_spec.rb`

## Verification

- `bundle exec rspec spec/models/memory_record_spec.rb spec/policies/memory_record_policy_spec.rb spec/requests/memory_records_spec.rb`
- `bundle exec rspec spec/requests/relationship_profiles_spec.rb spec/models/memory_record_spec.rb spec/policies/memory_record_policy_spec.rb spec/requests/memory_records_spec.rb`
- `bundle exec rspec`
