# 13.2 Notification Digest

**Area:** 13. Notifications

A daily or weekly summary of relationship actions.

## Example Digest

Today: Carlos interview check-in. This week: Ana birthday planning, mom weekly call, send David book recommendation.

## Possible Data Objects

- `Digest`
- `DigestItem`
- `DigestSchedule`

## Delivered Behavior

- Users choose daily or weekly delivery in their saved IANA time zone.
- Digest delivery uses a dedicated email or in-app channel choice and defaults to email.
- Quiet hours move a scheduled digest to the next valid quiet-hours end.
- Content combines open commitments, upcoming important dates, planning prompts, and due check-ins from active, owner-scoped relationship profiles.
- Muted and archived relationships are excluded, results are capped at eight actions, and empty digests are skipped.
- A durable delivery claim, activation-bounded recovery lookback, and persisted handoff marker recover delayed schedules without backfilling pre-activation occurrences or producing repeated side effects.
- Email delivery includes localized HTML and plain-text alternatives; in-app delivery links to the relationship action workspace.
