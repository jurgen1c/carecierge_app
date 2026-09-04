---
id: event_plans.bookings_are_owner_scoped_manual_and_plan_integrated
type: fact
system: event_plans
status: needs_verification
confidence: high
severity: critical

title: Bookings are owner-scoped, manual, and plan-integrated

claim: >
  Event plans own manual reservations and bookings for the authenticated user.
  Encrypted free-text logistics include provider, location, confirmation details,
  cancellation policy, and notes; scheduling uses a stored instant and IANA time
  zone. Records
  are mutable only while the plan and relationship are active, remain readable
  through an owner history and explicitly removable afterward, and use optimistic
  locking for edits. Destruction returns to the account-wide owner history only
  when that same-origin page initiated it, with the plan booking list as the safe
  fallback for edit, unknown, or external origins. Every save synchronizes one
  manual plan task and one
  privacy-minimized timeline entry; confirmed,
  completed, or cancelled statuses complete the task, while a later non-terminal
  status reopens it. Booking-owned tasks reject generic task mutations, and task
  completion retires active task reminders, while confirmed status retires the
  confirmation milestone and completed or cancelled statuses retire every active
  booking milestone reminder; reminders for milestones already made obsolete by
  the current status cannot be created. They are excluded from suggestion,
  prior-plan reuse, and backup-replacement task context. Backup promotion enforces
  that boundary with a plan-scoped anti-join while locking only matching plan-task
  rows. Owners may explicitly start confirmation, deposit, arrival,
  or change reminder forms with useful defaults, but reminders are never created
  automatically. Deletion detaches historical reminders and removes the owned
  task and timeline entry. Owner exports include decrypted booking logistics,
  while account and event-plan ownership cascades delete the records. The feature
  never contacts providers, books, sends, or pays externally.

source_files:
  - app/models/booking.rb
  - app/controllers/bookings_controller.rb
  - app/controllers/plan_tasks_controller.rb
  - app/services/bookings/save.rb
  - app/services/bookings/destroy.rb
  - app/services/event_plans/suggest.rb
  - app/services/event_plans/context_builder.rb
  - app/services/backup_plans/generate.rb
  - app/services/backup_plans/promote.rb
  - app/policies/booking_policy.rb
  - db/migrate/20260903120000_create_bookings.rb
  - db/migrate/20260903121000_add_booking_context_to_reminders.rb

related_files:
  - app/models/reminder.rb
  - app/models/plan_task.rb
  - app/controllers/reminders_controller.rb
  - app/serializers/data_exports/snapshot.rb
  - app/views/components/booking_list_component.rb
  - app/views/components/booking_list_component.html.erb
  - app/views/bookings/_form.html.erb
  - app/views/bookings/index.html.erb
  - app/views/components/event_plan_workspace_component.html.erb
  - config/initializers/filter_parameter_logging.rb
  - config/locales/bookings.en.yml
  - config/locales/bookings.es.yml
  - docs/features/07-03-reservation-and-booking-management.md
  - spec/models/booking_spec.rb
  - spec/services/bookings/save_spec.rb
  - spec/services/backup_plans/promote_spec.rb
  - spec/requests/bookings_spec.rb
  - spec/requests/booking_reminders_spec.rb
  - spec/serializers/data_exports/booking_snapshot_spec.rb
  - spec/system/bookings_spec.rb
symbols:
  - Booking
  - BookingPolicy
  - BookingsController
  - Bookings::Save
  - Bookings::Destroy
  - BookingListComponent
routes:
  - event_plan_bookings
  - new_event_plan_booking
  - edit_booking
  - booking
tags:
  - event_plans
  - bookings
  - reminders
  - privacy
  - review_only

verification:
  - bundle exec rspec spec/models/booking_spec.rb spec/services/bookings spec/policies/booking_policy_spec.rb spec/requests/bookings_spec.rb spec/requests/booking_reminders_spec.rb spec/components/booking_list_component_spec.rb spec/serializers/data_exports/booking_snapshot_spec.rb spec/system/bookings_spec.rb
  - bin/rubocop
  - bin/memory validate
  - bin/memory coverage --git-diff
  - bin/memory audit --git-diff
  - bin/ci

last_verified_commit:
---

# Bookings are owner-scoped, manual, and plan-integrated

## Claim

Carecierge stores booking logistics as private owner-scoped event-plan records.
The owner drives every lifecycle change and every reminder creation. Booking
status keeps plan-task progress and timeline context coherent without taking an
external action.

## Why It Matters

Booking logistics include sensitive confirmation and location details, and
touch event-plan, reminder, timeline, export, and deletion boundaries. Keeping
the owner, lifecycle, and manual-action contracts together prevents cross-user
access, stale overwrites, duplicate plan work, and accidental vendor contact.

## Evidence

- `app/models/booking.rb`
- `app/services/bookings/save.rb`
- `app/controllers/bookings_controller.rb`
- `spec/requests/bookings_spec.rb`
- `spec/requests/booking_reminders_spec.rb`

## Verification

- `bundle exec rspec spec/models/booking_spec.rb spec/services/bookings spec/policies/booking_policy_spec.rb spec/requests/bookings_spec.rb spec/requests/booking_reminders_spec.rb spec/components/booking_list_component_spec.rb spec/serializers/data_exports/booking_snapshot_spec.rb spec/system/bookings_spec.rb`
- `bin/rubocop`
- `bin/memory validate`
- `bin/memory coverage --git-diff`
- `bin/memory audit --git-diff`
- `bin/ci`
