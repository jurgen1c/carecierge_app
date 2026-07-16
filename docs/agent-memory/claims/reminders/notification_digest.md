---
id: reminders.notification_digest
type: fact
system: reminders
status: current
confidence: high
severity: important

title: Notification digests deliver concise owner-scoped relationship actions

claim: >
  Daily and weekly relationship digests use the account's saved IANA time zone,
  quiet hours, dedicated email-or-in-app digest channel, and relationship mute
  overrides. Email is the default digest channel. The composer reads only active
  profiles owned by the recipient and combines due open commitments, upcoming
  important dates, planning prompts, and due contact-cadence check-ins into at
  most eight ordered actions; archived and muted relationships are excluded and
  empty digests are skipped. DispatchDueDigestsJob runs every minute and creates
  one durable DigestDelivery per user and scheduled occurrence, recovering the
  latest missed occurrence from an eight-day lookback bounded by the activation
  time of the current schedule. Composition preserves the saved zone's calendar
  date even when the scheduled instant crosses a UTC date boundary, and quiet-hour
  deferrals compose against their effective delivery date while retaining the original
  occurrence for deduplication. A bounded lease, row locks,
  a PostgreSQL advisory processing lock, and a persisted external-handoff marker
  prevent queue amplification, concurrent delivery, and repeated side effects.
  Email handoff recovery uses a pre-queue marker plus a delivery-completion marker so duplicate queued
  handoffs become harmless, and the immutable content snapshot prevents later action changes from
  invalidating delivery. In-app notifications surface the composed action titles from the same snapshot.
  DeliverDigestJob rechecks the current mode, channel, and schedule activation before sending
  localized HTML/text email or an in-app notification visible in the reminders feed.

source_files:
  - app/services/digests/compose.rb
  - app/services/digests/snapshot.rb
  - app/models/digest_delivery.rb
  - app/jobs/dispatch_due_digests_job.rb
  - app/jobs/deliver_digest_job.rb

related_files:
  - app/mailers/digest_mailer.rb
  - app/jobs/deliver_digest_email_job.rb
  - app/notifiers/digest_email_notifier.rb
  - app/notifiers/digest_in_app_notifier.rb
  - app/views/digest_mailer/summary.html.erb
  - app/views/digest_mailer/summary.text.erb
  - db/migrate/20260716034426_add_digest_channel_to_notification_preferences.rb
  - db/migrate/20260716034427_create_digest_deliveries.rb
  - db/migrate/20260716040529_add_handed_off_at_to_digest_deliveries.rb
  - db/migrate/20260716041358_add_digest_schedule_changed_at_to_notification_preferences.rb
  - db/migrate/20260716045005_add_email_delivered_at_to_digest_deliveries.rb
  - db/data/20260716042058_backfill_digest_schedule_activation.rb
  - bin/docker-entrypoint
  - docs/features/13-02-notification-digest.md
  - spec/services/digests/compose_spec.rb
  - spec/jobs/dispatch_due_digests_job_spec.rb
  - spec/jobs/deliver_digest_job_spec.rb
  - spec/jobs/deliver_digest_email_job_spec.rb
  - spec/mailers/digest_mailer_spec.rb
  - spec/data_migrations/backfill_digest_schedule_activation_spec.rb

symbols:
  - Digests::Compose
  - DigestDelivery
  - DispatchDueDigestsJob
  - DeliverDigestJob
  - DeliverDigestEmailJob
  - DigestMailer
  - DigestEmailNotifier
  - DigestInAppNotifier

routes: []

tags:
  - notification_digest

verification:
  - bundle exec rspec spec/models/notification_preference_spec.rb spec/models/digest_delivery_spec.rb spec/services/digests/compose_spec.rb spec/jobs/dispatch_due_digests_job_spec.rb spec/jobs/deliver_digest_job_spec.rb spec/mailers/digest_mailer_spec.rb spec/requests/notification_preferences_spec.rb spec/data_migrations/backfill_digest_schedule_activation_spec.rb
  - bundle exec rspec
  - bin/rubocop
  - bin/ci

last_verified_commit: null
---

# Notification digests deliver concise owner-scoped relationship actions

## Claim

Carecierge turns existing relationship actions into one quiet daily or weekly
briefing without creating parallel commitment, date, or cadence records. The
digest uses an explicit, user-selected delivery channel and durable occurrence
claim while keeping relationship ownership, mute choices, quiet hours, and
localization intact.

## Why It Matters

Digest content contains private relationship context. Owner-scoped composition,
current preference checks, bounded content, and idempotent scheduling prevent
cross-account exposure, unwanted delivery, duplicate noise, and stale channel
choices.

## Evidence

- `app/services/digests/compose.rb`
- `app/models/digest_delivery.rb`
- `app/jobs/dispatch_due_digests_job.rb`
- `app/jobs/deliver_digest_job.rb`
- `app/mailers/digest_mailer.rb`
- `app/notifiers/digest_in_app_notifier.rb`
- `db/data/20260716042058_backfill_digest_schedule_activation.rb`

## Verification

- `bundle exec rspec spec/models/notification_preference_spec.rb spec/models/digest_delivery_spec.rb spec/services/digests/compose_spec.rb spec/jobs/dispatch_due_digests_job_spec.rb spec/jobs/deliver_digest_job_spec.rb spec/mailers/digest_mailer_spec.rb spec/requests/notification_preferences_spec.rb spec/data_migrations/backfill_digest_schedule_activation_spec.rb`
- `bundle exec rspec`
- `bin/rubocop`
- `bin/ci`
