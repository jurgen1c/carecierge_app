---
id: reminders.reminder_delivery_system
type: fact
system: reminders
status: current
confidence: verified
severity: critical

title: Reminders provide owner-scoped scheduling and idempotent delivery

claim: >
  Reminder is the single owner-scoped scheduler for relationship profiles,
  important dates, commitments, event plans, plan tasks, and vendor quote
  deadlines. Quote context can prefill an owner-controlled reminder before the
  earliest decision or expiration date, but it never schedules automatically.
  It supports
  one-time and recurring schedules, snooze and completion, relationship filters,
  private calendar export, notification preferences, quiet hours, and IANA
  timezone behavior that preserves local recurrence intent. Dispatch creates a
  unique durable ReminderDelivery for each occurrence and channel; bounded lease
  recovery, advisory worker locks, attempt tokens, final-handoff lifecycle and
  preference checks, after-commit enqueueing, and retries keep in-app and email
  delivery idempotent. Owner and relationship associations are validated and
  policy-scoped. New planning attachments require active plans and current,
  incomplete tasks; superseded tasks cannot receive new reminders. Backup-plan
  options preserve an encrypted review snapshot of active reminders on proposed
  replacement tasks and fail promotion if that reminder impact changed.
  Terminal transitions retire active reminders, reopening never silently
  reactivates them, and task deletion detaches rather than deletes history. Push
  and SMS settings are stored but are not active delivery
  channels. Calendar exports emit privacy-minimized evidence only after
  successful serialization and exclude Turbo prefetches.

source_files:
  - app/models/reminder.rb
  - app/models/reminder_delivery.rb
  - app/models/notification_preference.rb
  - app/controllers/reminders_controller.rb
  - app/policies/reminder_policy.rb
  - app/jobs/dispatch_due_reminders_job.rb
  - app/jobs/deliver_reminder_job.rb
  - app/jobs/application_job.rb
  - app/notifiers/reminder_in_app_notifier.rb
  - app/notifiers/reminder_email_notifier.rb
  - app/serializers/reminder_calendar_serializer.rb
  - app/helpers/reminders_helper.rb
  - app/javascript/controllers/timezone_controller.js
  - config/environments/production.rb
  - app/models/event_plan.rb
  - app/models/plan_task.rb
  - app/models/vendor_quote.rb
  - app/controllers/vendor_quotes_controller.rb
  - db/migrate/20260903042850_create_vendor_quotes.rb
  - db/migrate/20260903044916_add_vendor_quote_reference_to_reminders.rb

related_files:
  - app/views/reminders/_workspace.html.erb
  - app/views/reminders/_overdue_commitments.html.erb
  - app/views/components/reminder_row_component.rb
  - app/views/components/reminder_row_component.html.erb
  - config/recurring.yml
  - config/initializers/noticed.rb
  - config/deploy.yml
  - db/migrate/20260714030154_create_reminders.rb
  - db/migrate/20260714030157_create_reminder_deliveries.rb
  - db/migrate/20260714070000_add_reminder_delivery_processing_fence.rb
  - db/migrate/20260821040000_create_event_plans.rb
  - db/migrate/20260821040001_add_event_plan_references_to_reminders.rb
  - app/models/backup_option.rb
  - app/services/backup_plans/generate.rb
  - app/services/backup_plans/promote.rb
  - db/migrate/20260822210000_add_reviewed_reminders_to_backup_options.rb
  - spec/services/backup_plans/generate_spec.rb
  - spec/services/backup_plans/promote_spec.rb
  - spec/requests/vendor_quotes_spec.rb
  - Dockerfile
  - .kamal/secrets
  - docs/features/03-01-reminder-system.md
  - spec/models/reminder_spec.rb
  - spec/jobs/dispatch_due_reminders_job_spec.rb
  - spec/jobs/deliver_reminder_job_spec.rb
  - spec/requests/reminders_spec.rb
  - spec/policies/reminder_policy_spec.rb
  - spec/helpers/reminders_helper_spec.rb
  - spec/serializers/reminder_calendar_serializer_spec.rb
symbols:
  - Reminder
  - ReminderDelivery
  - NotificationPreference
  - RemindersController
  - ReminderPolicy
  - DispatchDueRemindersJob
  - DeliverReminderJob
  - ReminderCalendarSerializer
routes:
  - reminders
  - reminder
  - snooze_reminder
  - complete_reminder
  - calendar_reminder
  - calendar_reminders
tags:
  - reminders
  - noticed
  - solid_queue
  - icalendar

verification:
  - bundle exec rspec
  - bin/rubocop
  - bin/ci
last_verified_commit: 4390cc8d2f5d6896696c013af41b2f7b6e60cd5f
---

# Reminders provide owner-scoped scheduling and idempotent delivery

## Claim

Carecierge has one user-owned reminder scheduler for relationship profiles,
important dates, commitments, event plans, and plan tasks. It owns recurrence,
snooze and completion, relationship-focused browsing, IANA timezone behavior,
notification preferences, private calendar export, and idempotent Noticed
delivery. Durable per-occurrence channel claims, bounded lease recovery,
advisory worker locks, attempt tokens, final-handoff checks, after-commit
enqueueing, and retries prevent duplicate or stale delivery. Push and SMS remain
inactive future channels. Commitment, plan, and task lifecycle boundaries retire
active reminders and never silently reactivate historical schedules.

## Why It Matters

Reminder scheduling is shared infrastructure for relationship care. Keeping
recurrence, delivery claims, preferences, authorization, and exports in one
system prevents duplicate notifications, cross-account access, and competing
schedulers as commitments and plans are introduced.

## Review Notes

CAR-37 reviewed this claim while extending the existing dispatcher with
notification timing and relationship-specific controls. CAR-68 reviewed the
reminder workspace and added its authenticated entry point to automation
permission settings without changing reminder scheduling or delivery behavior.
Delivery claims, recovery, Noticed handoff, recurrence, and lifecycle behavior
remain current; `reminders.notification_preferences` owns the notification
settings contract.

## Evidence

- `app/models/reminder.rb`
- `app/models/vendor_quote.rb`
- `app/models/reminder_delivery.rb`
- `app/models/notification_preference.rb`
- `app/controllers/reminders_controller.rb`
- `app/policies/reminder_policy.rb`
- `app/jobs/dispatch_due_reminders_job.rb`
- `app/jobs/deliver_reminder_job.rb`
- `app/notifiers/reminder_in_app_notifier.rb`
- `app/notifiers/reminder_email_notifier.rb`
- `app/serializers/reminder_calendar_serializer.rb`
- `app/views/reminders/_workspace.html.erb`
- `spec/models/reminder_spec.rb`
- `spec/jobs/dispatch_due_reminders_job_spec.rb`
- `spec/jobs/deliver_reminder_job_spec.rb`
- `spec/requests/reminders_spec.rb`
- `spec/requests/vendor_quotes_spec.rb`
- `spec/policies/reminder_policy_spec.rb`
- `spec/helpers/reminders_helper_spec.rb`

## Verification

- `bundle exec rspec`
- `bin/rubocop`
- `bin/ci`
