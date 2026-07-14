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
  RelationshipProfile and ImportantDate. The global reminder inbox can be
  filtered by relationship and uses a timeline-style feed; relationship profile
  pages also show their active reminders. One-time reminders complete, recurring
  reminders advance to the next future occurrence, and active reminders can be
  snoozed. DispatchDueRemindersJob claims each enabled channel and scheduled
  occurrence through a unique, durable ReminderDelivery before
  DeliverReminderJob hands delivery to separate Noticed in-app and email
  notifiers. Pending claims are rescanned through a bounded, indexed enqueue lease
  to recover failed queue handoffs without minute-by-minute queue amplification,
  while claims made stale by rescheduling, snoozing, or completion are cancelled
  before notification. Delivery checks and lifecycle updates serialize on the
  reminder row. The retrying delivery job records success only after the channel
  completes, including synchronous execution of the actual Noticed email
  delivery. Jobs defer enqueueing until database transactions commit, transient
  delivery failures retry automatically, and deleting a reminder removes its
  Noticed events. Snoozed reminders use their effective delivery time for inbox
  grouping and ordering in the IANA timezone captured from the browser or chosen
  from the complete visible timezone list. Recurrence anchors preserve month-end
  and leap-day intent, while local-time snoozes preserve wall-clock intent. Partial updates preserve
  omitted links, and relationship links fall back to the global inbox after a
  profile is archived. NotificationPreference
  enables in-app and email delivery by default; push and SMS fields are reserved
  and are not dispatched. Owner-scoped endpoints export one reminder or all active
  reminders as private iCalendar events with normalized multiline text.
  Production reminder email links require CARECIERGE_HOST and use HTTPS; SMTP
  transport and sender settings must come from Rails credentials or matching
  CARECIERGE environment variables exposed through Kamal secrets. Recurring
  iCalendar events use their IANA TZID and recurring-event-based transition
  coverage to preserve local wall-clock time. Future
  commitment and planning models must
  integrate with Reminder rather than create a parallel scheduler.

source_files:
  - app/models/reminder.rb
  - app/models/reminder_delivery.rb
  - app/models/notification_preference.rb
  - app/controllers/reminders_controller.rb
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
  - app/views/components/reminder_row_component.rb
  - app/views/components/reminder_row_component.html.erb
  - config/recurring.yml
  - config/initializers/noticed.rb
  - config/deploy.yml
  - db/migrate/20260714060000_add_recurrence_anchor_to_reminders.rb
  - Dockerfile
  - .kamal/secrets
  - docs/features/03-01-reminder-system.md
  - spec/models/reminder_spec.rb
  - spec/jobs/dispatch_due_reminders_job_spec.rb
  - spec/jobs/deliver_reminder_job_spec.rb
  - spec/requests/reminders_spec.rb
  - spec/serializers/reminder_calendar_serializer_spec.rb
symbols:
  - Reminder
  - ReminderDelivery
  - NotificationPreference
  - RemindersController
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
relationship profiles and important dates. It supports one-time and recurring
lifecycle behavior, snoozing, completion, relationship-focused browsing,
idempotent Noticed delivery for in-app and email channels, durable pending-claim
recovery, stale-claim cancellation, notification preferences, after-commit job
enqueueing, actual-channel retries, browser-captured or visibly selected IANA timezone handling,
month-end and leap-day recurrence anchors,
effective snooze timing, active-profile association boundaries, archived-profile
link fallback, configured SMTP and HTTPS email links, and private iCalendar
export. Push and SMS are reserved future
channels, not active delivery methods. Future commitment and planning models
must extend this system.

## Why It Matters

Reminder scheduling is shared infrastructure for relationship care. Keeping
recurrence, delivery claims, preferences, authorization, and exports in one
system prevents duplicate notifications, cross-account access, and competing
schedulers as commitments and plans are introduced.

## Evidence

- `app/models/reminder.rb`
- `app/models/reminder_delivery.rb`
- `app/models/notification_preference.rb`
- `app/controllers/reminders_controller.rb`
- `app/jobs/dispatch_due_reminders_job.rb`
- `app/jobs/deliver_reminder_job.rb`
- `app/notifiers/reminder_in_app_notifier.rb`
- `app/notifiers/reminder_email_notifier.rb`
- `app/serializers/reminder_calendar_serializer.rb`
- `spec/models/reminder_spec.rb`
- `spec/jobs/dispatch_due_reminders_job_spec.rb`
- `spec/jobs/deliver_reminder_job_spec.rb`
- `spec/requests/reminders_spec.rb`

## Verification

- `bundle exec rspec`
- `bin/rubocop`
- `bin/ci`
