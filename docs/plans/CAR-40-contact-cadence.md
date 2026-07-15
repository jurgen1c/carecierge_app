# CAR-40: Contact cadence and stale relationships

## Ticket

- Jira: CAR-40 — Track contact cadence and stale relationships
- Source: `docs/features/03-03-contact-cadence-tracking.md`

## Confirmed acceptance criteria

- A relationship profile offers a cadence suggested from its relationship type; the suggestion is not active until the user accepts or changes it.
- A user can set and adjust the desired cadence for each relationship they own.
- A user can log meaningful interactions manually.
- Conversation recaps and mood notes produce traceable derived interactions. The provenance boundary remains polymorphic so later WhatsApp and social-media adapters can supply interactions without changing cadence calculations.
- The latest meaningful interaction drives the next check-in window.
- An overdue cadence uses supportive uncertainty-aware language and offers actions to log an interaction or plan a reminder. It never asserts that contact did not happen and never creates a reminder automatically.
- Derived interactions cannot be edited or deleted through the manual interaction endpoints.
- All endpoints remain authenticated and owner-scoped; source records must belong to the same relationship profile.
- User-facing copy is localized in English and Spanish.

## Design direction

- Keep the feature in the existing relationship-profile workspace.
- Make interaction history dominant, with a compact cadence summary beside it on larger screens and below it on mobile.
- Use Carecierge's existing stone/emerald system with a small terracotta cue for overdue uncertainty.
- Carry Monzo-like status/action clarity without introducing a dashboard, relationship score, streak, or surveillance language.
- Use semantic Rails ERB and familiar controls; all mock ingredients are implemented with HTML/CSS rather than raster assets.

## Implementation boundaries

- `ContactCadence` owns the accepted interval and relationship-type suggestion rules.
- `Interaction` owns meaningful-interaction ordering, manual/derived invariants, provenance, and cadence anchor behavior.
- Existing recap and mood-note transactions synchronize their derived interaction alongside their timeline entry.
- The existing Reminder system remains the only scheduler; CAR-40 links into it but does not dispatch or create reminders automatically.
- Future external integrations are out of scope; this ticket only establishes the source interface they can use.

## Repository memory context

- Systems: `relationship_profiles`, `reminders`
- Claims: `relationship_profiles.profile_crud_owner_scope`, `reminders.reminder_delivery_system`
- Required verification: `bin/memory context --git-diff`, `bin/memory validate`, `bin/memory coverage --git-diff`, `bin/memory audit --git-diff`, focused RSpec, `bin/ci`

## Risks

- Tenant leakage through nested routes or polymorphic sources.
- Treating missing interaction data as proof that contact did not happen.
- Duplicate derived interactions during source updates.
- N+1 queries when rendering polymorphic interaction sources.
- Coupling future integrations to controller or presentation-layer APIs.

## Review record

- Independent review identified interaction-note log filtering, future source timestamps, and archived-profile cadence controls; each finding was fixed with regression coverage.
- The user chose to skip an additional external post-fix Codex review after the full local RSpec, RuboCop, and agent-memory gates passed.
