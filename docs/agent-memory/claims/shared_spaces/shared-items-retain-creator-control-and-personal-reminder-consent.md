---
id: shared_spaces.shared_items_retain_creator_control_and_personal_reminder_consent
type: fact
system: shared_spaces
status: current
confidence: high
severity: critical

title: Shared items retain creator control and personal reminder consent

claim: >
  Participants coordinate plans, dates, tasks, reminders and shared notes. Creators own deletion and choose creator-only or shared editing/completion. Responsibility is self-claimed or released. Plan grouping stays within the space; kinds are fixed and revisions guard edits, claims and completion. No-key account-then-space locks serialize writes with deletion while permitting foreign-key readers. Each person opts into their own in-app reminder. The dispatcher queries pending occurrences with batched source discovery, skips deleted sources, and rechecks participation, due time, completion, subscription, channel and quiet hours under the space lock. It atomically records one delivery per occurrence and adds a content-free alert to the recipient’s reminder inbox. English/Spanish forms explain privacy, ownership and deletion, without external delivery or activity monitoring.

source_files:
  - app/models/shared_item.rb
  - app/models/shared_reminder_subscription.rb
  - app/services/shared_spaces/change_item.rb
  - app/controllers/shared_items_controller.rb
  - app/controllers/reminders_controller.rb
  - app/policies/shared_item_policy.rb
  - app/jobs/dispatch_shared_reminders_job.rb
  - app/notifiers/shared_reminder_notifier.rb
  - config/recurring.yml
  - app/views/components/shared_item_component.rb
  - app/views/components/shared_item_component.html.erb
  - app/views/shared_items/_form.html.erb
  - spec/jobs/dispatch_shared_reminders_job_spec.rb
  - spec/services/shared_spaces/locking_spec.rb
  - spec/system/shared_relationship_spaces_spec.rb

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
  - bundle exec rspec
  - bundle exec rspec spec/services/shared_spaces/locking_spec.rb
  - bundle exec rspec spec/requests/shared_relationship_spaces_spec.rb spec/models/shared_relationship_space_spec.rb spec/jobs/dispatch_shared_reminders_job_spec.rb spec/system/shared_relationship_spaces_spec.rb
---

# Shared items retain creator control and personal reminder consent

## Claim

Participants coordinate plans, dates, tasks, reminders and shared notes. Creators own deletion and choose creator-only or shared editing/completion. Responsibility is self-claimed or released. Plan grouping stays within the space; kinds are fixed and revisions guard edits, claims and completion. No-key account-then-space locks serialize writes with deletion while permitting foreign-key readers. Each person opts into their own in-app reminder. The dispatcher queries pending occurrences with batched source discovery, skips deleted sources, and rechecks participation, due time, completion, subscription, channel and quiet hours under the space lock. It atomically records one delivery per occurrence and adds a content-free alert to the recipient’s reminder inbox. English/Spanish forms explain privacy, ownership and deletion, without external delivery or activity monitoring.

## Why It Matters

Shared participation must never broaden access to either person's individual relationship data or silently impose reminders on them.
