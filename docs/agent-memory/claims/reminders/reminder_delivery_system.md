---
id: reminders.reminder_delivery_system
type: fact
system: reminders
status: current
confidence: high
severity: critical

title: Reminders provide owner-scoped scheduling and idempotent delivery

claim: >
  Reminder records belong to a User and may reference that user's
  RelationshipProfile, ImportantDate, and open Commitment; the policy layer only permits creation
  when the new record is assigned to the current user. The global reminder inbox
  can be filtered by relationship and orders its timeline-style feed by effective
  delivery time in SQL; relationship profile
  pages also show their active reminders. One-time reminders complete, recurring
  reminders advance to the next future occurrence, and active reminders can be
  snoozed. DispatchDueRemindersJob claims each enabled channel and scheduled
  occurrence through a unique, durable ReminderDelivery before
  DeliverReminderJob hands delivery to separate Noticed in-app and email
  notifiers. Pending and dispatching claims are rescanned through a bounded,
  indexed processing lease to recover failed queue handoffs or interrupted
  delivery attempts without minute-by-minute queue amplification,
  while claims made stale by rescheduling, snoozing, or completion are cancelled
  before notification. Delivery claims and lifecycle checks briefly serialize
  on the reminder and delivery rows. A PostgreSQL advisory lock serializes each
  delivery worker and prevents lease recovery from replacing an actively sending
  worker, while Noticed and email execute outside row locks. The durable claim is
  marked dispatching and a per-attempt token fences completion or failure from a
  recovered replacement. Email lifecycle validity is rechecked at the final
  channel handoff; a later reminder change does not recall a handoff already in
  progress. Recovery rechecks staleness after locking and reuses the delivery's
  committed Noticed event. The retrying delivery job
  records success only after the channel completes, including synchronous
  execution of the actual Noticed email delivery. Jobs defer enqueueing until database transactions commit, transient
  delivery failures retry automatically, and deleting a reminder removes its
  Noticed events. Snoozed reminders use their effective delivery time for inbox
  grouping and ordering in the IANA timezone captured from the browser or chosen
  from the complete visible timezone list, whose computed labels and current
  UTC offsets share one cache entry until the next UTC minute boundary so
  intraday and half-hour DST transitions refresh without accumulating keys.
  Recurrence anchors preserve month-end
  and leap-day intent, while local-time snoozes preserve wall-clock intent. Partial updates preserve
  omitted links, and relationship links fall back to the global inbox after a
  profile is archived. HTML create, update, destroy, snooze, and complete actions
  preserve an active relationship filter and fall back globally for archived profiles. NotificationPreference
  activates in-app and email while saving push and SMS without dispatch;
  reminders.notification_preferences owns other settings. Pending claims recheck
  current channel and relationship-mute choices at the final Noticed handoff, and
  reapply quiet hours before the handoff. Preference cancellations restore the
  occurrence when they remove its last viable claim, while quiet-hour cancellations
  restore it at the next valid local quiet-hours end across DST gaps and repeats.
  Cancelled, uniquely indexed claims are revived if those choices later allow the
  same occurrence. Due occurrences remain pending when no active channel is
  available. Relationship profile pages query only their next five
  active reminders in effective delivery order. Owner-scoped endpoints export one reminder or all active
  reminders as private iCalendar events with normalized multiline text.
  Production reminder email links require CARECIERGE_HOST and use HTTPS; SMTP
  transport and sender settings must come from Rails credentials or matching
  CARECIERGE environment variables exposed through Kamal secrets. Recurring
  iCalendar events use their IANA TZID and recurring-event-based transition
  coverage to preserve local wall-clock time. Commitments may own multiple
  reminders and derive their relationship context through the same owner-scoped
  association boundary. Deleting a commitment cascades its owned reminders at
  both the Rails association and database foreign-key layers. Reminder form commitment options stay policy-scoped even
  for inconsistent persisted foreign keys. Completing or canceling a commitment retires its active
  reminders, and reopening it does not reactivate their historical schedules;
  future planning models must integrate with Reminder
  rather than create a parallel scheduler.

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
last_verified_commit: null
---

# Reminders provide owner-scoped scheduling and idempotent delivery

## Claim

Carecierge has one reusable, user-owned reminder scheduler for current
relationship profiles, important dates, and commitments. It supports one-time and recurring
lifecycle behavior, snoozing, completion, relationship-focused browsing,
idempotent Noticed delivery for in-app and email channels, durable fenced
processing-lease recovery, per-delivery worker serialization, final-handoff
lifecycle checks, short claim locks, stale-claim cancellation,
notification preferences, after-commit job
enqueueing, actual-channel retries, browser-captured or visibly selected IANA timezone handling,
month-end and leap-day recurrence anchors,
effective snooze timing and SQL ordering, policy-enforced ownership,
active-profile association boundaries, relationship-preserving HTML redirects,
archived-profile action and link fallback,
minute-boundary-cached timezone options, configured SMTP and HTTPS email links, and private iCalendar
export. Push and SMS are reserved future
channels, not active delivery methods. Commitments extend this system with
owner- and relationship-matched reminder links; future planning models must do
the same.

## Why It Matters

Reminder scheduling is shared infrastructure for relationship care. Keeping
recurrence, delivery claims, preferences, authorization, and exports in one
system prevents duplicate notifications, cross-account access, and competing
schedulers as commitments and plans are introduced.

## Review Notes

CAR-37 reviewed this claim while extending the existing dispatcher with
notification timing and relationship-specific controls. Delivery claims,
recovery, Noticed handoff, recurrence, and lifecycle behavior remain current;
`reminders.notification_preferences` owns the new settings contract.

## Evidence

- `app/models/reminder.rb`
- `app/models/reminder_delivery.rb`
- `app/models/notification_preference.rb`
- `app/controllers/reminders_controller.rb`
- `app/policies/reminder_policy.rb`
- `app/jobs/dispatch_due_reminders_job.rb`
- `app/jobs/deliver_reminder_job.rb`
- `app/notifiers/reminder_in_app_notifier.rb`
- `app/notifiers/reminder_email_notifier.rb`
- `app/serializers/reminder_calendar_serializer.rb`
- `spec/models/reminder_spec.rb`
- `spec/jobs/dispatch_due_reminders_job_spec.rb`
- `spec/jobs/deliver_reminder_job_spec.rb`
- `spec/requests/reminders_spec.rb`
- `spec/policies/reminder_policy_spec.rb`
- `spec/helpers/reminders_helper_spec.rb`

## Verification

- `bundle exec rspec`
- `bin/rubocop`
- `bin/ci`
