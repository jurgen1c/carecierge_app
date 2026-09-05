# 14.1 Shared Couple Space

**Area:** 14. Collaboration Modes

Two partners can optionally share a private planning space.

## Capabilities

- Shared date ideas.
- Shared goals.
- Shared anniversary planning.
- Shared event planning.
- Gratitude notes.
- Household or family commitments.
- Shared memory timeline.

## Implementation Notes

This should come later because shared spaces increase privacy and permissions complexity.

## Implemented consent and collaboration boundary (CAR-78)

The authenticated Shared couple spaces entry point creates an in-app invitation addressed to one confirmed account email. The recipient explicitly accepts or declines; no email or external message is sent. Invitations expire after seven days, and creators may cancel them. Each space has exactly two participants after acceptance. Acceptance discloses the two account emails to each other.

Shared plans, dates, tasks, reminders, and explicitly authored shared notes live in a separate aggregate from individual relationship profiles. No private note, vault content, AI context, existing private plan, calendar connection, or personal reminder is imported or exposed. Participants can group items under a shared plan, add a date/time and time zone, voluntarily claim or release task responsibility, and complete/reopen items. A creator chooses creator-only or both-person editing; only the creator changes that rule or deletes an item. Item kinds stay fixed after creation, and revisions reject stale edits.

Each person explicitly subscribes to reminder items for their own in-app alert. Alerts respect in-app preferences and quiet hours, deliver once per scheduled occurrence in the recipient’s existing reminder inbox, and carry no content in the notification text. Sharing ends immediately when either person confirms deletion of the whole shared workspace; deleting either account also deletes that space, its items, subscriptions, and in-app reminder history. The UI explains this consequence before confirmation. Account JSON/CSV exports include currently participating active shared spaces and only the requesting person's reminder subscription preference.

The English-default and Spanish flows use ordinary forms without JavaScript, responsive item lists, visible author/editor rules, and no activity monitoring or read receipts. Verification: `bundle exec rspec spec/requests/shared_relationship_spaces_spec.rb spec/models/shared_relationship_space_spec.rb spec/jobs/dispatch_shared_reminders_job_spec.rb spec/system/shared_relationship_spaces_spec.rb`.
