# 4.3 Suggestion Engine

**Area:** 4. AI Assistance and Intelligence

The relationship profile recommends timely, private next steps based on current
dates, preferences, memories, contact cadence, observations, desires, and
commitments. Suggestions are deterministic views over those sources rather than
a second memory store.

## Capabilities

- Suggest gifts.
- Suggest messages.
- Suggest plans.
- Suggest check-ins.
- Suggest plans and event preparation.
- Suggest conflict repair actions.
- Suggest professional follow-ups.
- Explain why suggestions were made.
- Allow helpful/not-for-me feedback, dismissal, save, completion, and action
  where supported by the suggestion type.
- Keep every suggestion linked to its source and certainty.

## Suggestion Types

- Reminder-based
- Occasion-based
- Preference-based
- Goal-based
- Commitment-based
- Spontaneous
- Repair-focused
- Professional follow-up

## Data Objects

- `Suggestion` is an immutable, non-persisted value object with a stable
  fingerprint, localized copy keys, evidence reasons, and an `action_kind`.
- `Suggestion::Reason` preserves its source record, evidence text, and confirmed
  or inferred certainty.
- `SuggestionFeedback` persists only user interaction state by fingerprint,
  including saved and completed gesture state.

## Implementation Notes

`Suggestions::ForProfile` supports gift, message, plan, check-in, event,
spontaneous, repair-focused, and professional-follow-up suggestions. Archived
profiles fail closed. High-impact suggestions use confirmed/approved evidence;
an unapproved AI inference cannot qualify them.

Spontaneous gestures carry low-, medium-, or high-effort metadata. The profile
shows one deterministic variant at a time and rotates alternatives without
persisting generated copy or expanding the bounded suggestion result.

The current `create_reminder` action only prefills the existing reminder form.
The suggestion is marked acted after the reminder saves, not when the form is
opened. It never sends a message, contacts another person, purchases, or books.
The stable action contract is the extension point for later user-enabled
automation, which must consult automation permissions and approval requirements
before any external side effect.

Every suggestion includes reasoning.

Example: suggested because her birthday is in 12 days and she recently mentioned wanting to try pottery.
