---
id: relationship_profiles.suggestions_are_source_backed_and_user_initiated
type: decision
system: relationship_profiles
status: current
confidence: high
severity: critical

title: Suggestions are source-backed and user-initiated

claim: >
  The relationship-profile suggestion engine deterministically derives up to ten
  supported suggestion types from current owner-scoped source records, retains
  evidence and confirmed or inferred certainty, and fails closed for archived
  profiles and unapproved AI evidence in high-impact suggestions. Suggestion
  content is not persisted; only feedback, dismissal, save, and completed-action
  state are stored by stable fingerprint. Profile rendering supplies already-loaded
  source collections to avoid repeating relationship queries, and mutation
  responses reuse their generated suggestion set. Act currently prepares a private reminder
  and marks the suggestion acted only after the reminder saves. The stable
  action_kind is the extension boundary for future user-enabled automation,
  which must evaluate automation permissions and approval requirements before
  external side effects.
  Social context can add gift, message, conversation-topic, and reminder ideas
  only when the owner enabled downstream use, approved the AI interpretation,
  and left that specific proposed use selected during review; these reasons
  remain inferred and link back to the user-provided note.
  Profile rendering shares a bounded collection of the ten most recent opted-in
  social notes between message-context display and suggestion assembly.
  Spontaneous gestures expose one variant-aware low-, medium-, or high-effort
  option at a time, derive it from safe current relationship type, preference,
  interaction, important-date, desire, or cadence evidence, and let the owner
  save, complete, dismiss, or request the next deterministic alternative.
  Alternative rotation skips variants already dismissed, completed, or marked
  not for the owner and stops when no unseen alternative remains.
  Generic relationship-type fallbacks stay on the profile so the Concierge
  Queue remains limited to gestures backed by a concrete source record, with
  recent interactions bounded per active relationship. Persisted interaction
  state participates in owner-scoped data exports.

source_files:
  - app/services/suggestions/for_profile.rb
  - app/services/suggestions/next_gesture_variation.rb
  - app/models/suggestion.rb
  - app/models/suggestion_feedback.rb
  - app/models/social_context_note.rb
  - app/controllers/suggestions_controller.rb
  - app/services/suggestions/complete_reminder_action.rb
  - app/services/daily_feed/for_user.rb
  - app/models/feed_item_state.rb
  - app/serializers/data_exports/snapshot.rb
  - app/controllers/reminders_controller.rb
  - app/views/reminders/_form.html.erb
  - app/views/mood_notes/_section.html.erb

related_files:
  - app/controllers/relationship_profiles_controller.rb
  - app/models/interaction.rb
  - app/controllers/concerns/relationship_profile_show_workspace.rb
  - app/policies/suggestion_feedback_policy.rb
  - app/views/suggestions/_section.html.erb
  - app/views/components/suggestion_list_item_component.rb
  - app/views/components/suggestion_inspector_component.rb
  - config/routes.rb
  - config/locales/suggestions.en.yml
  - config/locales/suggestions.es.yml
  - docs/features/04-03-suggestion-engine.md
  - docs/features/05-03-spontaneous-gesture-suggestions.md
  - spec/services/suggestions/for_profile_spec.rb
  - spec/services/suggestions/next_gesture_variation_spec.rb
  - spec/models/feed_item_state_spec.rb
  - spec/requests/data_controls_spec.rb
  - spec/requests/social_context_notes_spec.rb
  - spec/requests/suggestions_spec.rb
  - spec/system/spontaneous_gestures_spec.rb

symbols:
  - Suggestion
  - Suggestion::Reason
  - SuggestionFeedback
  - Suggestions::ForProfile
  - Suggestions::NextGestureVariation
  - Suggestions::CompleteReminderAction
  - SuggestionsController

routes:
  - feedback_relationship_profile_suggestion
  - dismiss_relationship_profile_suggestion
  - save_relationship_profile_suggestion
  - complete_relationship_profile_suggestion
  - act_relationship_profile_suggestion
  - new_reminder

tags:
  - relationship_profiles
  - suggestions
  - source_evidence
  - uncertainty
  - automation_boundary
  - decision

verification:
  - bundle exec rspec spec/models/suggestion_spec.rb spec/models/suggestion_feedback_spec.rb spec/services/suggestions/for_profile_spec.rb spec/policies/suggestion_feedback_policy_spec.rb spec/components/suggestion_list_item_component_spec.rb spec/components/suggestion_inspector_component_spec.rb spec/requests/suggestions_spec.rb spec/requests/reminders_spec.rb spec/requests/relationship_profiles_spec.rb spec/services/daily_feed/for_user_spec.rb spec/requests/daily_feed_spec.rb
  - bundle exec rspec spec/system/spontaneous_gestures_spec.rb
  - bin/rubocop app/models/suggestion.rb app/models/suggestion_feedback.rb app/services/suggestions app/services/daily_feed/for_user.rb app/controllers/suggestions_controller.rb app/controllers/relationship_profiles_controller.rb app/controllers/reminders_controller.rb app/policies/suggestion_feedback_policy.rb app/views/components/suggestion_list_item_component.rb app/views/components/suggestion_inspector_component.rb spec/models/suggestion_spec.rb spec/models/suggestion_feedback_spec.rb spec/services/suggestions spec/policies/suggestion_feedback_policy_spec.rb spec/components/suggestion_list_item_component_spec.rb spec/components/suggestion_inspector_component_spec.rb spec/requests/suggestions_spec.rb
  - bin/memory validate
  - bin/memory coverage --git-diff
  - bin/ci

last_verified_commit: null
---

# Suggestions are source-backed and user-initiated

## Decision

Suggestions are computed from records the user already owns instead of creating
a parallel recommendation database. Each suggestion carries a stable
fingerprint, localized copy keys, typed source evidence, and explicit certainty.
Persisted state is limited to the user's feedback, dismissal, save, or completed
action. Spontaneous gesture alternatives are variant-aware, but only one is
derived at a time so asking for another does not grow the bounded result;
rotation skips hidden variants and ends when no unseen alternative remains.
Social-context reasons additionally require a reviewed interpretation, an
individually approved use category, and an enabled per-note downstream setting;
raw disabled notes and unapproved drafts or use categories cannot create
suggestions.

## Rationale

This keeps explanations auditable, avoids stale duplicated relationship facts,
preserves privacy-vault and persona uncertainty rules, avoids duplicate source
queries during profile rendering and mutation responses, and provides a narrow
contract for later automation. Generic relationship-type gestures stay out of
the daily feed to avoid manufacturing queue work without a concrete source.
The current reminder action remains reversible and local: opening Act only
prepares a reminder, and reminder completion is recorded only in the successful
reminder transaction. Gesture completion can also be recorded directly without
an external side effect.

## Alternatives Considered

- Persisting generated suggestion text was rejected because locale changes and
  source updates would make stored copy stale.
- Performing communication or other external effects from Act was rejected for
  CAR-49 because those effects require explicit user permission and, for higher
  impact work, an approval path.

## Verification

- `bundle exec rspec spec/models/suggestion_spec.rb spec/models/suggestion_feedback_spec.rb spec/services/suggestions/for_profile_spec.rb spec/policies/suggestion_feedback_policy_spec.rb spec/components/suggestion_list_item_component_spec.rb spec/components/suggestion_inspector_component_spec.rb spec/requests/suggestions_spec.rb spec/requests/reminders_spec.rb spec/requests/relationship_profiles_spec.rb spec/services/daily_feed/for_user_spec.rb spec/requests/daily_feed_spec.rb`
- `bundle exec rspec spec/system/spontaneous_gestures_spec.rb`
- `bin/rubocop app/models/suggestion.rb app/models/suggestion_feedback.rb app/services/suggestions app/services/daily_feed/for_user.rb app/controllers/suggestions_controller.rb app/controllers/relationship_profiles_controller.rb app/controllers/reminders_controller.rb app/policies/suggestion_feedback_policy.rb app/views/components/suggestion_list_item_component.rb app/views/components/suggestion_inspector_component.rb spec/models/suggestion_spec.rb spec/models/suggestion_feedback_spec.rb spec/services/suggestions spec/policies/suggestion_feedback_policy_spec.rb spec/components/suggestion_list_item_component_spec.rb spec/components/suggestion_inspector_component_spec.rb spec/requests/suggestions_spec.rb`
- `bin/memory validate`
- `bin/memory coverage --git-diff`
- `bin/ci`
