---
id: relationship_profiles.memory_records
type: fact
system: relationship_profiles
status: current
confidence: high
severity: important

title: Memory records track source, confidence, review, and automation approval

claim: >
  MemoryRecord records are owner-scoped relationship-profile facts with trust,
  review, correction, and high-impact automation approval metadata. Semantic
  title or body corrections set user-corrected provenance and corrected status;
  body corrections and submitted correction notes also create MemoryRevision
  rows transactionally, including notes attached to title-only corrections. Archived
  records are not reviewable, failed review transitions report errors, trust resets use
  normalized comparisons, user forms cannot set system-managed statuses, risky
  records require explicit automation approval, edit re-renders preserve
  correction notes, and section counts use one load. Approving a blocked fact
  from its relationship profile finalizes an open ApprovalRequest or creates a
  new envelope after a terminal decision, without executing automation.

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
  - app/services/approval_decisions/apply.rb
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

Memory records are owner-scoped relationship-profile facts rendered through
Turbo streams with source, confidence, lifecycle, review, correction, and
high-impact automation metadata. Semantic title or body corrections set
user-corrected provenance and corrected status, while body corrections and
submitted correction notes create MemoryRevision rows in the same transaction
as the record update, including notes attached to title-only corrections. Archived records are not reviewable,
failed review transitions report errors, trust resets use normalized
comparisons, and user-facing forms can only manage active, needs-review, and
archived statuses. Stale and corrected statuses remain system-managed, risky
records require explicit automation approval, edit re-renders preserve
correction notes, and section counts use one ordered collection load. The
relationship-profile control finalizes an open approval request or creates a
new history envelope when reversing a terminal decision; this timestamp still
authorizes only the fact's future consideration and performs no action.

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
