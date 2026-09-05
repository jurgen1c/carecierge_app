# 14.2 Family Mode

**Area:** 14. Collaboration Modes

Families can coordinate dates, gifts, elder care, child events, and holidays.

## Capabilities

- Shared family calendar.
- Shared birthdays.
- Gift coordination.
- RSVP planning.
- Care tasks.
- Holiday planning.

## Implemented workflow (CAR-79)

Create a family space from Shared spaces and invite up to 20 relatives using confirmed account emails. Invitations appear in the recipient's in-app inbox for seven days without external delivery or account-existence disclosure. Acceptance rechecks that the person is not already a member, including after an email change. Acceptance shares account email and the relationship label (parent, child, sibling, grandparent, extended/chosen family or other); these labels do not grant guardianship or authority. Only the organizer manages invitations and ends the group. Existing couple spaces retain two-person consent and either-person termination.

Family coordination reuses shared plans, dates, self-claimed tasks, personal in-app reminder subscriptions and deliberately shared notes. Family categories cover birthdays, gifts, RSVP, care and holidays. The calendar is a chronological dated list with category and personal-responsibility filters; upcoming dates start at the current instant while All coordination retains history; birthday and holiday occurrences are entered explicitly. RSVP plans collect each member's own attending/maybe/not-attending response. A category with responses cannot be changed. Users can organize tasks, dates, reminders and notes under plans; creators retain deletion and editing-rule control.

Personal profile notes, vaults and AI context never flow into family spaces. Category starters only open an editable form and never infer private information or create actions. Reminder consent remains personal, quiet hours apply, and delivery rechecks participation under account-then-space locks. There is no external calendar publication, messaging, payment, activity monitoring or automatic task assignment.

Members can leave; organizers can remove members or cancel invitations. Explicit confirmation removes that person's contributed items, RSVPs and reminders and releases their responsibilities. Other people's content stays, including children of a removed plan as standalone items. Rejoining requires a fresh invitation. Deleting a member account follows the same cleanup; deleting the organizer account deletes the group. Account exports include accepted memberships and shared RSVP responses, with only the requester's reminder preference; pending invitation addresses are excluded.

Persistence uses additive UUID membership/response tables, unique space/email and space/user indexes, and existing actor-account then space locks. The migration takes brief table locks for added columns and constraints. Rollback is supported before family data is populated; once family spaces contain null couple invitation fields, the former NOT NULL constraints cannot be restored without explicitly deciding how to retain that family data. Prefer a forward fix after usage.

Verification: `bundle exec rspec spec/requests/family_spaces_spec.rb spec/models/family_membership_spec.rb spec/system/family_spaces_spec.rb spec/requests/shared_relationship_spaces_spec.rb spec/jobs/dispatch_shared_reminders_job_spec.rb`, full `bin/ci`, and agent-memory validation/audit.
