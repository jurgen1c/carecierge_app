---
id: relationship_profiles.suggestions_are_source_backed_and_user_initiated
type: decision
system: relationship_profiles
status: current
confidence: high
severity: critical

title: Suggestions are source-backed and user-initiated

claim: >
  The relationship-profile suggestion engine deterministically derives eight
  supported suggestion types from current owner-scoped source records, retains
  evidence and confirmed or inferred certainty, and fails closed for archived
  profiles and unapproved AI evidence in high-impact suggestions. Suggestion
  content is not persisted; only feedback, dismissal, and completed-action state
  are stored by stable fingerprint. Profile rendering supplies already-loaded
  source collections to avoid repeating relationship queries, and mutation
  responses reuse their generated suggestion set. Act currently prepares a private reminder
  and marks the suggestion acted only after the reminder saves. The stable
  action_kind is the extension boundary for future user-enabled automation,
  which must evaluate automation permissions and approval requirements before
  external side effects.

source_files:
  - app/services/suggestions/for_profile.rb
  - app/models/suggestion.rb
  - app/models/suggestion_feedback.rb
  - app/controllers/suggestions_controller.rb
  - app/services/suggestions/complete_reminder_action.rb
  - app/controllers/reminders_controller.rb
  - app/views/reminders/_form.html.erb
  - app/views/mood_notes/_section.html.erb

related_files:
  - app/controllers/relationship_profiles_controller.rb
  - app/policies/suggestion_feedback_policy.rb
  - app/views/suggestions/_section.html.erb
  - app/views/components/suggestion_list_item_component.rb
  - app/views/components/suggestion_inspector_component.rb
  - config/routes.rb
  - config/locales/suggestions.en.yml
  - config/locales/suggestions.es.yml
  - spec/services/suggestions/for_profile_spec.rb
  - spec/requests/suggestions_spec.rb

symbols:
  - Suggestion
  - Suggestion::Reason
  - SuggestionFeedback
  - Suggestions::ForProfile
  - Suggestions::CompleteReminderAction
  - SuggestionsController

routes:
  - feedback_relationship_profile_suggestion
  - dismiss_relationship_profile_suggestion
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
  - bundle exec rspec spec/models/suggestion_spec.rb spec/models/suggestion_feedback_spec.rb spec/services/suggestions/for_profile_spec.rb spec/policies/suggestion_feedback_policy_spec.rb spec/components/suggestion_list_item_component_spec.rb spec/components/suggestion_inspector_component_spec.rb spec/requests/suggestions_spec.rb
  - bin/rubocop app/models/suggestion.rb app/models/suggestion_feedback.rb app/services/suggestions app/controllers/suggestions_controller.rb app/controllers/relationship_profiles_controller.rb app/controllers/reminders_controller.rb app/policies/suggestion_feedback_policy.rb app/views/components/suggestion_list_item_component.rb app/views/components/suggestion_inspector_component.rb spec/models/suggestion_spec.rb spec/models/suggestion_feedback_spec.rb spec/services/suggestions spec/policies/suggestion_feedback_policy_spec.rb spec/components/suggestion_list_item_component_spec.rb spec/components/suggestion_inspector_component_spec.rb spec/requests/suggestions_spec.rb
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
Persisted state is limited to the user's feedback, dismissal, or completed
action.

## Rationale

This keeps explanations auditable, avoids stale duplicated relationship facts,
preserves privacy-vault and persona uncertainty rules, avoids duplicate source
queries during profile rendering and mutation responses, and provides a narrow
contract for later automation. The current action remains reversible and local:
opening Act only prepares a reminder, and completion is recorded only in the
successful reminder transaction.

## Alternatives Considered

- Persisting generated suggestion text was rejected because locale changes and
  source updates would make stored copy stale.
- Performing communication or other external effects from Act was rejected for
  CAR-49 because those effects require explicit user permission and, for higher
  impact work, an approval path.

## Verification

- `bundle exec rspec spec/models/suggestion_spec.rb spec/models/suggestion_feedback_spec.rb spec/services/suggestions/for_profile_spec.rb spec/policies/suggestion_feedback_policy_spec.rb spec/components/suggestion_list_item_component_spec.rb spec/components/suggestion_inspector_component_spec.rb spec/requests/suggestions_spec.rb`
- `bin/rubocop app/models/suggestion.rb app/models/suggestion_feedback.rb app/services/suggestions app/controllers/suggestions_controller.rb app/controllers/relationship_profiles_controller.rb app/controllers/reminders_controller.rb app/policies/suggestion_feedback_policy.rb app/views/components/suggestion_list_item_component.rb app/views/components/suggestion_inspector_component.rb spec/models/suggestion_spec.rb spec/models/suggestion_feedback_spec.rb spec/services/suggestions spec/policies/suggestion_feedback_policy_spec.rb spec/components/suggestion_list_item_component_spec.rb spec/components/suggestion_inspector_component_spec.rb spec/requests/suggestions_spec.rb`
- `bin/memory validate`
- `bin/memory coverage --git-diff`
- `bin/ci`
