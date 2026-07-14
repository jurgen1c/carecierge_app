# 3.1 Reminder System

**Area:** 3. Reminders and Commitments

Users receive reminders for important dates, promises, check-ins, gifts, events, and planned actions.

## Capabilities

- Create and edit one-time or daily, weekly, monthly, and yearly reminders.
- Snooze reminders for a fixed future interval.
- Complete one-time reminders or advance recurring reminders to their next future occurrence.
- Assign low, normal, or high priority.
- Associate reminders with the signed-in user's active relationships and important dates.
- Browse a global inbox or focus the timeline-style feed on one relationship.
- Deliver due reminders in-app and by email through Noticed and Solid Queue.
- Configure in-app and email delivery preferences.
- Export one reminder or all active reminders as private iCalendar (`.ics`) events.

## Reminder Types

- Birthday reminder
- Gift planning reminder
- Check-in reminder
- Promise follow-up
- Event preparation
- Post-event follow-up
- Relationship goal reminder
- Custom reminder

## Possible Data Objects

- `Reminder`
- `ReminderDelivery`
- `NotificationPreference`

## Implementation Notes

The reusable system is implemented by `Reminder`, `ReminderDelivery`,
`NotificationPreference`, `DispatchDueRemindersJob`, and `DeliverReminderJob`.
`Reminder` owns recurrence and lifecycle behavior; delivery jobs claim each
channel and scheduled occurrence once in durable `ReminderDelivery` rows before
delegating to Noticed. The dispatcher rescans pending claims so a failed queue
handoff is recovered after a bounded enqueue lease without amplifying queued
work every minute, and stale claims are cancelled after a reminder is
rescheduled, snoozed, or completed. Reminder lifecycle updates and delivery
checks serialize on the reminder row. The retrying delivery job creates in-app
notifications and executes Noticed email delivery synchronously, then records
success only after the channel completes. Jobs enqueue only after database
commits. When every current channel is disabled, the due occurrence stays
pending for delivery after preferences are re-enabled. Relationship pages query
only their next five active reminders in effective delivery order. Snoozed reminders are grouped, ordered, and displayed by their effective
delivery time in the IANA timezone captured from the browser or selected from a
complete visible timezone list. Recurrence anchors preserve month-end and
leap-day intent, "tomorrow" snoozes preserve local wall-clock intent, and edits
retain the persisted timezone. Partial edits preserve
omitted associations, and associations are limited to active relationships.
Notifications for an archived relationship fall back to the unfiltered inbox.
Reminder notes are filtered from parameter logs, authorization is owner-scoped,
and both English and Spanish UI and email copy are maintained. Production email
links require `CARECIERGE_HOST` and use HTTPS. Production SMTP transport and the
sender must be configured under the `smtp` Rails credential (`from`, `address`,
`port`, `user_name`, `password`, and optional `authentication`) or the matching
`CARECIERGE_MAIL_FROM` and `CARECIERGE_SMTP_*` environment variables; boot fails
fast when required delivery settings are missing. The Kamal configuration passes
those secret environment variables through without storing their values in git.

The current association surface intentionally supports only models that exist:
`RelationshipProfile` and `ImportantDate`. Future commitment and planning models
must add their reminder associations to this system instead of implementing a
parallel scheduler. CAR-39 and CAR-56 contain that follow-up requirement.

Push and SMS preference columns are reserved but cannot be enabled or dispatched
yet. Their delivery adapters, consent behavior, and user-facing controls belong
in future tickets.

Calendar interoperability is portable one-way `.ics` export with UTC one-time
instants, IANA `TZID` anchors for recurring wall-clock schedules, recurring-event
transition coverage for the next century, and normalized, escaped multiline
text. OAuth-based Google Calendar
synchronization, updates, and deletion propagation are not part of this ticket.

## Verification

- `bundle exec rspec`
- `bin/rubocop`
- `bin/ci`
