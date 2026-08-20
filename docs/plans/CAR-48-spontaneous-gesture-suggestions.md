# CAR-48 Spontaneous Gesture Suggestions

## Scope

Extend the existing deterministic suggestion ledger with one source-backed
spontaneous gesture at a time. The gesture can rotate through low-, medium-,
and high-effort alternatives without introducing a second suggestion store or
an AI generation path.

The existing suggestion privacy boundary remains authoritative: gesture
content is derived from current owner-scoped records, archived profiles fail
closed, saved/completed state is keyed by a stable fingerprint, and no action
sends, purchases, books, or contacts anyone automatically.

## Acceptance criteria

- Derive gesture options from current relationship type, safe preferences,
  recent interactions, important dates, goals/desires, and contact cadence.
- Offer deterministic low-, medium-, and high-effort variants while keeping the
  bounded suggestion result to one gesture at a time.
- Let owners dismiss, save, complete, or ask for another gesture.
- Keep every gesture linked to a visible source-backed reason and certainty.
- Enforce active owner scope for every mutation and preserve the existing
  trust-safety boundary for sensitive or inferred evidence.
- Render familiar, mobile-first controls inside the existing suggestion
  inspector with complete English and Spanish copy.

## Architecture and design

- `Suggestion` remains the immutable domain value and gains gesture effort and
  variant metadata plus variant-aware fingerprints.
- `Suggestions::ForProfile` chooses a safe source for the requested effort and
  generates exactly one spontaneous suggestion per call.
- `Suggestions::NextGestureVariation` cycles over unseen variants and stops
  once the owner has hidden every alternative.
- `SuggestionFeedback` continues to store interaction state only; `saved_at`
  records save-for-later without hiding the gesture, while `acted_at` records
  completion and hides it.
- `SuggestionsController` owns save and complete operations. Alternative
  requests remain non-mutating profile GETs.
- The existing ViewComponents retain the approved ledger/inspector composition,
  Carecierge semantic palette, 44px controls, source links, and responsive flow.
- Reminder handoff carries gesture variant context so alternative fingerprints
  remain valid through successful reminder creation.

## Repository memory

Systems:

- `relationship_profiles`
- `reminders`
- `daily_feed`

Claims:

- `relationship_profiles.suggestions_are_source_backed_and_user_initiated`
- `relationship_profiles.privacy_vault`
- `daily_feed.concierge_queue_is_derived_and_owner_scoped`
- `reminders.reminder_delivery_system`

## Verification

- `bundle exec rspec spec/models/suggestion_spec.rb spec/models/suggestion_feedback_spec.rb spec/services/suggestions/for_profile_spec.rb spec/policies/suggestion_feedback_policy_spec.rb spec/components/suggestion_list_item_component_spec.rb spec/components/suggestion_inspector_component_spec.rb spec/requests/suggestions_spec.rb spec/requests/reminders_spec.rb`
- `bundle exec rspec spec/system/spontaneous_gestures_spec.rb`
- `bin/rubocop` for changed Ruby files
- `bun run build:css`
- `bin/memory validate`
- `bin/memory compile`
- `bin/memory doctor`
- `bin/memory coverage --git-diff`
- `bin/memory audit --git-diff`
- `bin/ci`
