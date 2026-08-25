# 6.2 Anniversary Concierge

**Area:** 6. Planning Workflows

A guided, owner-controlled workflow for anniversaries and recurring meaningful milestones.

## Capabilities

- Start an anniversary plan from an owned anniversary or milestone important date.
- Prefill the relationship, next occurrence, and immutable source provenance.
- Choose an understated, warm, celebratory, or romantic tone without inferring one.
- Choose low, medium, or high effort to shape the deterministic starting runway.
- Review activity, reservation, gift, flowers-or-alternative, message, reminder,
  personal-touch, practical-support, backup, and day-of steps.
- Optionally select a completed or archived prior anniversary plan from the same
  relationship as history to confirm before reuse. If that optional selection
  is stale or no longer applies at submission time, creation continues without
  prior history.
- Request bounded source-backed suggestions through the generic event-planning
  provider boundary.
- Act through existing reminder, gift, message-draft, backup-plan, and
  personal-touch workflows.

## Possible Data Objects

- `EventPlan`
- `PlanTask`
- `ImportantDate`
- Existing `Reminder`, gift, message-draft, backup-plan, and
  `PersonalTouchChecklist` workflows

## Implementation Notes

The implementation reuses the generic event-planning system. Anniversary and
milestone important dates map to `occasion_type: anniversary`; the source role
cannot be changed to another occasion later. Tone and effort are persisted plan
preferences; effort is included in non-stored suggestion requests only for
anniversary plans where the control is exposed. The effort control is limited
to anniversary plans because only their deterministic runway changes depth. The
manual new-plan form reveals effort and relationship-scoped
prior-history choices only after the user selects an anniversary and a
relationship when JavaScript is available, while keeping both controls usable
as a server-rendered progressive-enhancement baseline. Editable manual forms
load the bounded prior-plan choices for every available relationship, then
filter locally and restore the complete option set before Turbo caches the form.
Tone guidance stays relationship-neutral while that relationship selector is
editable, so changing the selection cannot leave stale relationship-specific
copy on screen.
Preference changes update untouched current or promoted-superseded template
fields and add only newly introduced positions, so selective AI deletion cannot
restore managed steps that the new effort level removed. Authored tasks may share those display positions without
suppressing a required template step, while a step the owner deleted is retained
as a content-scrubbed hidden template tombstone and is not silently restored, including after
effort-level round trips or selective AI deletion. Clearing an event date also
clears untouched deadlines derived from that date.
Anniversary plans created with the earlier generic template are recognized in
English or Spanish, including when every legacy step has customized copy or only
a position unique to the legacy runway remains, and
upgraded to the anniversary runway while preserving those owner customizations;
date-only rescheduling retains their original deadline offsets until that
upgrade occurs.

Prior anniversary context is never selected automatically. The user must choose
a finalized plan from the same relationship, and the bounded provider source is
marked inferred and needing confirmation. Prior task candidates are limited by
the database query before filtering and summarization. Historical AI task copy
is reused only when every persisted source still resolves in the current
authorized catalog; protected, deleted, stale, and unavailable sources are
excluded. Current relationship identity and hard constraints are ordered ahead
of historical context within the bounded catalog. If included historical copy
depends on a private note or vault item selected for the current request, the
aggregate history remains sensitive so ordinary exports cannot expose it.
The aggregate evidence ID is fingerprinted from the included historical content
and each current source-dependency snapshot. A later request with changed
dependency content or a different authorized
aggregate therefore cannot send a task derived from the earlier aggregate back
to the provider.
Earlier details are history, not a current preference or instruction.

All steps remain review-only. Carecierge never sends a message, schedules a
reminder, contacts a vendor, books a reservation, purchases an item, or shares
relationship context automatically.
