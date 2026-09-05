---
id: shared_spaces.shared_items_retain_creator_control_and_personal_reminder_consent
type: fact
system: shared_spaces
status: current
confidence: high
severity: critical

title: Shared items retain creator control and personal reminder consent

claim: >
  Active participants coordinate shared plans, dates, tasks, reminders and explicitly authored shared notes. Creators retain ownership and choose creator-only or both-participant editing and completion; only creators change editor policy or delete items. Task responsibility is voluntary self-claim/release and cannot be reassigned by another participant. Plan grouping is resolved within the current space, item kinds remain stable after creation, and required optimistic revisions reject stale edits, task claims and completion actions. Space-locked writes serialize with consent withdrawal. Each participant explicitly subscribes to their own in-app reminder; the recurring dispatcher discovers only pending due occurrences, safely skips concurrently deleted sources and rechecks participation, due time, completion, subscription, channel preference and quiet hours, atomically records delivery for each due occurrence and emits content-free notification text in the recipient’s existing reminder inbox. There is no external delivery, read receipt or participant activity monitoring. English/Spanish no-JavaScript forms and responsive lists explain visibility, ownership and the consequences of ending sharing.

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
  - bundle exec rspec spec/requests/shared_relationship_spaces_spec.rb spec/models/shared_relationship_space_spec.rb spec/jobs/dispatch_shared_reminders_job_spec.rb spec/system/shared_relationship_spaces_spec.rb
last_verified_commit: null
---

# Shared items retain creator control and personal reminder consent

## Claim

Active participants coordinate shared plans, dates, tasks, reminders and explicitly authored shared notes. Creators retain ownership and choose creator-only or both-participant editing and completion; only creators change editor policy or delete items. Task responsibility is voluntary self-claim/release and cannot be reassigned by another participant. Plan grouping is resolved within the current space, item kinds remain stable after creation, and required optimistic revisions reject stale edits, task claims and completion actions. Space-locked writes serialize with consent withdrawal. Each participant explicitly subscribes to their own in-app reminder; the recurring dispatcher discovers only pending due occurrences, safely skips concurrently deleted sources and rechecks participation, due time, completion, subscription, channel preference and quiet hours, atomically records delivery for each due occurrence and emits content-free notification text in the recipient’s existing reminder inbox. There is no external delivery, read receipt or participant activity monitoring. English/Spanish no-JavaScript forms and responsive lists explain visibility, ownership and the consequences of ending sharing.

## Why It Matters

Shared participation must never broaden access to either person's individual relationship data or silently impose reminders on them.
