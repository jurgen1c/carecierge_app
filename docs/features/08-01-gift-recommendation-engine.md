# 8.1 Gift Recommendation Engine

**Area:** 8. Gift and Commerce Features

The app recommends gifts using recipient profile, occasion, history, desires, budget, and preferences.

## Capabilities

- Generate up to three user-initiated gift ideas from the active relationship
  profile's type, structured preferences and constraints, desires, gift history,
  upcoming dates, and public notes.
- Explain every recommendation with source citations and confirmed or inferred
  provenance.
- Accept an optional maximum budget, needed-by date, and occasion. When a
  maximum is supplied, the server requires a valid price estimate and rejects
  provider output that exceeds the budget.
- Avoid prior gift and visible recommendation titles by default. Users can
  explicitly allow a prior gift to repeat when a staple is appropriate, but
  visible recommendations remain excluded.
- Save an idea into gift history, mark it purchased for planning, dismiss it, or
  replace it with a distinct alternative. Alternatives require a fresh choice
  before private-note or vault sources from the prior result are reused.
- Include private notes only when selected for a request. Privacy Vault context
  additionally requires both per-item suggestion approval and a current
  password-backed lease; while locked, generation and alternative options stay
  disabled and link to the explicit unlock flow.

## Data Objects

- `GiftRecommendation`
- `Gift`
- `AutomationPermission`
- `PrivacyVaultItem`

## Implementation Notes

`GiftRecommendations::ContextBuilder` creates a bounded source catalog.
Hard constraints and dislikes receive reserved priority before both the
preference cap and total character cap are applied, followed by explicitly
selected sensitive sources and then ordinary context. Sensitive source excerpts
use a smaller per-source cap so every bounded explicit selection remains in the
catalog even when all constraint slots are full. Every limited source query has
a stable ID tie-breaker so unchanged context produces the same fingerprint.
`GiftRecommendations::Generate` evaluates the `suggest_gifts` automation
permission, snapshots context under account-then-profile locks, calls the OpenAI
Responses API with `store: false` and strict structured output, validates cited
source IDs, rechecks permission, replacement state, the source fingerprint, and
the generation fence, and persists encrypted recommendations. Explicitly
selected sources take priority inside the fixed catalog bounds. Provider-side
duplicate hints contain only a capped, length-bounded slice of ordinary gift
history; generated recommendation titles remain local so sensitive derived text
cannot cross a later request's consent boundary. The server refreshes canonical
gift and visible recommendation titles after provider generation. Repeat mode
applies only to gift history; visible recommendations and each returned batch
remain unique. Submitted occasion text is filtered from request logs. Needed-by
dates stay within the supported persistence range, and calendar validation plus
upcoming-date selection use the owner's configured time zone. Gift and desire
mutations share the profile lock so stale provider output cannot win a
concurrent source update.

Generated output is review-only. Saving creates an existing `Gift` idea;
marking purchased creates an existing planned `Gift`; neither action contacts a
vendor or makes a purchase. Dismiss and alternative actions remain within the
recommendation workspace. Generated recommendation data participates in owner
exports and selective AI deletion.

Product catalogs, live prices, vendor integrations, delivery guarantees, and
automated purchasing remain out of scope.
