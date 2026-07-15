# 13.1 Notification Preferences

**Area:** 13. Notifications

Users control how and when they receive notifications.

## Channels

- In-app
- Push
- Email
- SMS later

## Controls

- Quiet hours
- Reminder frequency
- Reminder lead time
- Digest mode
- High-priority alerts
- Per-relationship notification settings

## Possible Data Objects

- `NotificationPreference`
- `NotificationChannel`
- `NotificationDelivery`

## Implemented Boundary

- `NotificationPreference` remains the account-level source of truth for in-app,
  email, future push, and future SMS choices.
- Quiet hours delay ordinary due reminders until the next local quiet-hours end.
  High-priority reminders bypass quiet hours only when the user enables that
  behavior.
- Relationship-specific overrides are sparse: relationships inherit account
  settings unless the owner explicitly mutes one.
- Reminder frequency and lead time are defaults for new reminders. Existing
  reminders are not rewritten, and explicit snoozes are preserved.
- Daily and weekly digest schedules are stored here. CAR-38 owns digest content,
  composition, and delivery.
- Push and SMS choices are configurable now but remain undispatched until those
  delivery channels exist.
