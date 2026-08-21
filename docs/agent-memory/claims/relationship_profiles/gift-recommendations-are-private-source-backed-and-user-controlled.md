---
id: relationship_profiles.gift_recommendations_are_private_source_backed_and_user_controlled
type: decision
system: relationship_profiles
status: current
confidence: high
severity: critical

title: Gift recommendations are private, source-backed, and user-controlled

claim: >
  Active profile owners generate up to three encrypted gift recommendations
  only through the suggest_gifts permission. The bounded, non-stored provider
  request uses relationship type, preferences and constraints, desires, prior
  gifts, upcoming dates, and public notes; private notes require per-request
  selection, while vault sources additionally require per-item suggestion
  approval and a revalidated password lease. Hard constraints and dislikes keep
  priority within both the fixed catalog and total character bounds; selected
  sensitive sources use smaller bounded excerpts so every explicit selection
  remains ahead of ordinary context even when all constraint slots are full,
  and every limited source query uses a stable ID tie-breaker so unchanged
  context yields a deterministic fingerprint. Alternatives require a fresh private-
  source choice. Locked vault context cannot be selected and instead links to
  the explicit unlock flow in both generation and alternative forms. Submitted
  free-form occasion text is filtered from request logs. Generated
  recommendation titles stay local rather
  than crossing a later request's consent boundary; ordinary gift-title hints
  are count- and length-bounded, then refreshed locally after generation. Date
  validation and upcoming-date selection use the owner's configured time zone
  and a bounded persistence range.
  Every result cites known sources, supplies a valid estimate when a maximum
  budget was requested, respects the enforced budget and repeat-gift
  guard, and is rejected when its source fingerprint or profile generation fence
  becomes stale. Repeat mode removes canonical gift-history titles from both the
  provider exclusion list and local gift-history filtering; outstanding
  recommendations and same-response titles remain unique. Owners can save an
  idea into Gift, mark it purchased into Gift
  planning, dismiss it, or request a distinct alternative, but the feature never
  contacts a vendor or purchases anything. Recommendations participate in owner
  exports and selective AI deletion.

source_files:
  - app/models/gift_recommendation.rb
  - app/controllers/gift_recommendations_controller.rb
  - app/services/gift_recommendations/context_builder.rb
  - app/services/gift_recommendations/generate.rb
  - app/services/gift_recommendations/open_ai_generator.rb
  - app/services/gift_recommendations/apply_action.rb
  - app/services/owner_local_calendar.rb
  - app/policies/gift_recommendation_policy.rb
  - app/views/components/gift_recommendation_workspace_component.rb
  - app/views/components/gift_recommendation_workspace_component.html.erb
  - config/initializers/filter_parameter_logging.rb
  - db/migrate/20260820040000_create_gift_recommendations.rb

related_files:
  - app/models/gift.rb
  - app/models/relationship_profile.rb
  - app/serializers/data_exports/snapshot.rb
  - app/services/data_deletions/delete_ai_data.rb
  - config/locales/gift_recommendations.en.yml
  - config/locales/gift_recommendations.es.yml
  - docs/features/08-01-gift-recommendation-engine.md
  - spec/models/gift_recommendation_spec.rb
  - spec/services/gift_recommendations/context_builder_spec.rb
  - spec/services/gift_recommendations/apply_action_spec.rb
  - spec/services/gift_recommendations/generate_spec.rb
  - spec/services/gift_recommendations/open_ai_generator_spec.rb
  - spec/requests/gift_recommendations_spec.rb
  - spec/components/gift_recommendation_workspace_component_spec.rb
  - spec/config/filter_parameter_logging_spec.rb
  - spec/system/gift_recommendations_spec.rb

symbols:
  - GiftRecommendation
  - GiftRecommendations::ContextBuilder
  - GiftRecommendations::Generate
  - GiftRecommendations::OpenAiGenerator
  - GiftRecommendations::ApplyAction
  - OwnerLocalCalendar
  - GiftRecommendationsController
  - GiftRecommendationPolicy
  - GiftRecommendationWorkspaceComponent

routes:
  - generate_relationship_profile_gift_recommendations
  - alternative_relationship_profile_gift_recommendation
  - save_relationship_profile_gift_recommendation
  - dismiss_relationship_profile_gift_recommendation
  - purchase_relationship_profile_gift_recommendation

tags:
  - relationship_profiles
  - decision
  - gift_recommendations
  - source_evidence
  - privacy
  - automation_boundary

verification:
  - bundle exec rspec spec/models/gift_recommendation_spec.rb spec/services/gift_recommendations spec/policies/gift_recommendation_policy_spec.rb spec/components/gift_recommendation_workspace_component_spec.rb spec/requests/gift_recommendations_spec.rb spec/services/data_deletions/delete_ai_data_spec.rb spec/system/gift_recommendations_spec.rb
  - bin/rubocop app/models/gift_recommendation.rb app/controllers/gift_recommendations_controller.rb app/services/gift_recommendations app/policies/gift_recommendation_policy.rb app/views/components/gift_recommendation_workspace_component.rb
  - bun run build:css
  - bin/memory validate
  - bin/memory coverage --git-diff
  - bin/memory audit --git-diff
  - bin/ci

last_verified_commit: null
---

# Gift recommendations are private, source-backed, and user-controlled

## Decision

Gift recommendations are an inline, review-only relationship-profile workspace.
Generated content is encrypted and source-backed. The provider receives bounded
JSON as untrusted input and does not store the request. Constraints and dislikes
are hard exclusions with reserved catalog and character-budget priority. A
maximum budget requires a valid estimated price. Prior titles are rechecked after the
provider call, and repeat mode omits canonical gift-history titles from provider
exclusions and local filtering while live recommendations and same-batch titles
stay unique. Free-form occasion text is
filtered from request logs. Private context remains an explicit
request choice behind existing vault controls, including each vault item's
suggestion-usage setting. Bounded selected sensitive excerpts remain present
even when every constraint slot is occupied, and limited source queries use
stable ID tie-breakers. Alternatives ask again before reusing a prior result's
sensitive sources and disable vault reuse with an unlock path when the lease is
locked. Derived recommendation titles remain local during later
generations, and owner-local dates plus a bounded persistence range drive request
validation and upcoming date context.

## Rationale

This keeps gift help useful without turning relationship memory into an opaque
shopping profile. Reusing Gift for accepted ideas preserves one history and one
owner boundary, while a separate recommendation record supports review,
dismissal, alternatives, provenance, and selective AI deletion.

## Alternatives Considered

- Extending deterministic `Suggestion` was rejected because CAR-53 needs
  generated product ideas, budgets, and per-result lifecycle state.
- Direct vendor lookup or purchase was deferred because live commerce and
  high-impact external actions are outside this ticket.

## Verification

- `bundle exec rspec spec/models/gift_recommendation_spec.rb spec/services/gift_recommendations spec/policies/gift_recommendation_policy_spec.rb spec/components/gift_recommendation_workspace_component_spec.rb spec/requests/gift_recommendations_spec.rb spec/services/data_deletions/delete_ai_data_spec.rb spec/system/gift_recommendations_spec.rb`
- `bin/rubocop app/models/gift_recommendation.rb app/controllers/gift_recommendations_controller.rb app/services/gift_recommendations app/policies/gift_recommendation_policy.rb app/views/components/gift_recommendation_workspace_component.rb`
- `bun run build:css`
- `bin/memory validate`
- `bin/memory coverage --git-diff`
- `bin/memory audit --git-diff`
- `bin/ci`
