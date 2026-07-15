---
id: reminders.notification_preferences
type: fact
system: reminders
status: current
confidence: high
severity: important

title: Notification preferences control reminder timing and relationship delivery

claim: >
  The authenticated notification settings surface stores account-owned in-app,
  email, future push, future SMS, quiet-hour, high-priority, reminder-default,
  digest-schedule, and relationship-specific choices. In-app and email are active
  delivery channels; push and SMS choices are saved but undispatched. Quiet hours
  defer ordinary due reminders to the next local quiet-hours end before delivery
  claims are created, while an enabled high-priority bypass allows high-priority
  reminders through. Repeated and nonexistent DST wall times resolve to the next
  valid local quiet-hours boundary. Changing quiet-hour rules releases deferred, non-snoozed due
  reminders for immediate reevaluation. Sparse, owner-matched relationship
  overrides mute delivery and keep due occurrences pending, queued claims recheck
  current channel and mute choices before handoff, and archived relationships no
  longer apply hidden mute overrides. A separate configured marker distinguishes
  an explicitly saved time zone from the UTC migration default so existing users
  keep browser time-zone capture; important-date scheduling round-trips that
  capture before deriving a local occurrence. Reminder recurrence and lead-time
  choices seed new reminders without rewriting existing reminders.
  Important-date cards expose that entry point, and calendar-sized lead offsets
  preserve the intended local reminder time across daylight-saving transitions.
  Daily and weekly digest choices are stored for CAR-38, which owns digest
  composition and delivery.

source_files:
  - app/models/relationship_notification_preference.rb
  - app/services/notification_preferences/save.rb
  - app/controllers/notification_preferences_controller.rb

related_files:
  - app/views/notification_preferences/edit.html.erb
  - app/views/components/notification_switch_row_component.rb
  - app/views/components/notification_switch_row_component.html.erb
  - db/migrate/20260715160000_expand_notification_preferences.rb
  - db/migrate/20260715160001_create_relationship_notification_preferences.rb
  - db/migrate/20260715160002_add_time_zone_configured_to_notification_preferences.rb
  - docs/features/13-01-notification-preferences.md
  - spec/models/relationship_notification_preference_spec.rb
  - spec/services/notification_preferences/save_spec.rb
  - spec/requests/notification_preferences_spec.rb
  - spec/components/notification_switch_row_component_spec.rb

symbols:
  - RelationshipNotificationPreference
  - NotificationPreferences::Save
  - NotificationPreferencesController

routes:
  - edit_notification_preference
  - notification_preference

tags:
  - notification_preferences
  - quiet_hours
  - timezones

verification:
  - bundle exec rspec spec/models/notification_preference_spec.rb spec/models/relationship_notification_preference_spec.rb spec/services/notification_preferences/save_spec.rb spec/requests/notification_preferences_spec.rb spec/requests/reminders_spec.rb spec/jobs/dispatch_due_reminders_job_spec.rb
  - bundle exec rspec
  - bin/rubocop
  - bin/ci

last_verified_commit: null
---

# Notification preferences control reminder timing and relationship delivery

## Claim

Carecierge keeps notification control in the existing reminder system. Account
settings determine active and future channels, quiet-hour timing, high-priority
bypass, new-reminder defaults, and the digest schedule consumed by CAR-38.
Relationship overrides stay sparse and owner-matched so users can mute one
relationship without creating a parallel delivery configuration. Important-date
cards provide the entry point for applying lead-time defaults, and day, week, and
month leads use calendar offsets in the saved time zone so the intended local
reminder time survives daylight-saving transitions.

## Why It Matters

Notification timing is privacy-sensitive and affects durable reminder claims.
Keeping preference evaluation ahead of claim creation prevents unwanted delivery,
cross-account overrides, duplicate schedulers, and irreversible quiet-hour delays.

## Evidence

- `app/models/notification_preference.rb`
- `app/models/relationship_notification_preference.rb`
- `app/services/notification_preferences/save.rb`
- `app/controllers/notification_preferences_controller.rb`
- `app/jobs/dispatch_due_reminders_job.rb`
- `app/jobs/deliver_reminder_job.rb`
- `app/views/important_dates/_important_date.html.erb`
- `spec/jobs/dispatch_due_reminders_job_spec.rb`
- `spec/requests/notification_preferences_spec.rb`

## Verification

- `bundle exec rspec spec/models/notification_preference_spec.rb spec/models/relationship_notification_preference_spec.rb spec/services/notification_preferences/save_spec.rb spec/requests/notification_preferences_spec.rb spec/requests/reminders_spec.rb spec/jobs/dispatch_due_reminders_job_spec.rb spec/jobs/deliver_reminder_job_spec.rb`
- `bundle exec rspec`
- `bin/rubocop`
- `bin/ci`
