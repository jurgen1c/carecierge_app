# 5.1 Daily Relationship Feed

**Area:** 5. Daily Experience

A central feed that tells users what deserves attention today.

## Capabilities

- Show upcoming important dates.
- Show overdue commitments.
- Show suggested check-ins.
- Show gift planning prompts.
- Show spontaneous gesture ideas.
- Show relationship goals.
- Show event planning reminders.
- Allow dismiss, snooze, complete, or act.

## Feed Item Types

- Reminder
- Suggestion
- Commitment
- Important date
- Event task
- Message draft
- Gift idea
- Plan continuation

## Data Model

- Feed items are derived from the authenticated user's existing reminders,
  suggestions, commitments, important dates, gifts, message drafts, desires,
  and plan continuations. They are not copied into a second content table.
- `FeedItemState` persists only queue presentation state: a stable source key,
  dismissal time, or snooze-until time.
- Permanently deleting a feed source removes its visibility state; deleting a
  relationship also removes its suggestion states.
- Completing or acting always delegates to the source feature so its existing
  authorization and lifecycle remain authoritative.

## Implementation Notes

Today groups a bounded set of dated work into Needs attention, Later today,
and Coming up. Optional suggestions, gift ideas, drafts, goals and undated promises
appear separately as ideas. Each section shows up to eight entries and labels its
displayed count. Items preserve the source context
and a direct path back to the originating relationship or workflow. Suggestion
evidence keeps its confirmed or inferred label. Recent interactions are bounded
per active relationship before they can ground a spontaneous gesture. The private dashboard opts out
of Turbo snapshots, and draft items load only the current revision.

Dismiss and snooze affect only the queue. Snooze returns an item at 9:00 AM the
next day in the user's notification time zone. Feed state is owner-scoped,
included in account exports, pruned with permanently deleted sources and
relationships, and deleted with the account.

Today also reads up to four upcoming active event plans in the owner's next 30 days, with an uncapped matching plan count; up to four due saved contact rhythms; and the count of persisted, currently eligible pending reviews. Opening Reviews performs its existing synchronization. The overview itself does not create review requests, change sources or call a provider. Navigation lives in the shared authenticated layout.
