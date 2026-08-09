# CAR-49 Suggestion Engine

## Scope

Build a deterministic, owner-scoped suggestion engine on the relationship
profile surface. Suggestions explain why they appear, distinguish confirmed
from inferred evidence, accept feedback, can be dismissed, and let the user
prepare a reminder. CAR-49 does not send messages, purchase, book, or contact
anyone automatically.

The suggestion action contract must remain extensible so later work can route
eligible actions through `AutomationPermission` and the approval queue before
external execution.

## Acceptance criteria

- Generate gift, message, plan, check-in, event, spontaneous, repair-focused,
  and professional follow-up suggestion types from existing relationship data.
- Give every suggestion at least one source-backed reason with visible certainty.
- Exclude archived profiles and memory that is stale, awaiting review, or
  protected without explicit suggestion consent.
- Persist helpful/not-for-me feedback, dismissal, and completed reminder action
  state without persisting generated localized copy.
- Make `Act` open a prefilled reminder and mark the suggestion acted only after
  the reminder saves successfully.
- Enforce owner scope for every suggestion mutation and reminder handoff.
- Render the approved selectable-ledger/evidence-inspector design responsively,
  with accessible controls and complete English and Spanish copy.
- Keep high-impact evidence eligibility explicit and fail closed for low-confidence
  or unapproved AI-inferred memory.

## Architecture

- `Suggestion` is a localized, immutable domain value with a stable fingerprint,
  evidence reasons, high-impact classification, and an `action_kind` extension boundary.
- `Suggestions::ForProfile` composes deterministic suggestions from existing
  owner-scoped profile records without writing during GET requests.
- `SuggestionFeedback` stores only user decisions keyed by fingerprint.
- `SuggestionsController` handles feedback, dismissal, and the reminder handoff.
- Reusable list and inspector UI uses ViewComponent with `dry-initializer` and
  `StyleVariantsHelper`.

## Repository memory

Systems:

- `relationship_profiles`
- `automation_permissions` (future execution boundary only)
- `reminders`

Claims:

- `relationship_profiles.relationship_personas_remain_source_backed_and_uncertainty_aware`
- `relationship_profiles.profile_crud_owner_scope`
- `relationship_profiles.memory_records`
- `relationship_profiles.privacy_vault`
- `relationship_profiles.preference_metadata`
- `relationship_profiles.important_dates`
- `relationship_profiles.desires`
- `relationship_profiles.contact_cadence`
- `relationship_profiles.commitments`
- `automation_permissions.permission_decisions`
- `reminders.reminder_delivery_system`

## Verification

- `bundle exec rspec spec/models/suggestion_spec.rb spec/models/suggestion_feedback_spec.rb spec/services/suggestions/for_profile_spec.rb spec/policies/suggestion_feedback_policy_spec.rb spec/components/suggestion_list_item_component_spec.rb spec/components/suggestion_inspector_component_spec.rb spec/requests/suggestions_spec.rb spec/requests/reminders_spec.rb spec/requests/relationship_profiles_spec.rb`
- `bin/rubocop` for changed Ruby files
- `bin/memory validate`
- `bin/memory compile`
- `bin/memory doctor`
- `bin/memory coverage --git-diff`
- `bin/memory audit --git-diff`
- `bin/ci`
