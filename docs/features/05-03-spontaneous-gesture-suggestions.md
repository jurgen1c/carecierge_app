# 5.3 Spontaneous Gesture Suggestions

**Area:** 5. Daily Experience

The relationship profile suggests one small, thoughtful action at a time
outside of major occasions. Gestures are deterministic views over current
owner-scoped relationship records; generated copy is not persisted.

## Capabilities

- Rotate through unseen low-, medium-, and high-effort options without
  resurfacing dismissed or completed variants.
- Ground suggestions in relationship type, safe preferences, recent
  interactions, important dates, desires/goals, or contact cadence.
- Show the source reason and confirmed or inferred certainty before action.
- Let the owner dismiss, save, complete, or ask for another gesture.
- Carry any selected alternative through the private reminder handoff.
- Keep generic relationship-type fallbacks on the profile; the Concierge Queue
  only receives gestures backed by a more concrete source record.

## Examples

- Send a voice note.
- Order favorite dessert.
- Send an article.
- Schedule lunch.
- Bring coffee.
- Send encouragement.
- Plan a walk.
- Mail a handwritten note.

## Data Objects

- `Suggestion` is the immutable gesture value and includes stable variant-aware
  fingerprints plus `effort` and `variation` metadata.
- `Suggestion::Reason` retains the typed source, localized explanation,
  evidence, and certainty.
- `SuggestionFeedback` stores feedback, dismissal, save, and completion state
  by fingerprint without storing generated gesture content.

## Implementation Notes

`Suggestions::ForProfile` generates exactly one spontaneous gesture per call so
the bounded suggestion ledger does not grow when the user asks for alternatives.
`Suggestions::NextGestureVariation` derives the remaining variant fingerprints
from the same source snapshot, skips variants with hidden owner feedback, and
removes the alternative control when none remain.
Low effort prefers a recent interaction or contact cadence, medium effort
prefers a safe positive or neutral preference or upcoming date, and higher
effort prefers an active desire or upcoming date. The relationship type is the
profile-only fallback.

Boundary, allergy, and cultural-constraint preferences are not treated as
positive gesture inspiration. Archived profiles fail closed. Gesture actions
remain private and user-initiated: they do not send, purchase, book, schedule,
or contact anyone automatically.
