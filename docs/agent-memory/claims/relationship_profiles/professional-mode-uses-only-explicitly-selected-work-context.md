---
id: relationship_profiles.professional_mode_uses_only_explicitly_selected_work_context
type: constraint
system: relationship_profiles
status: current
confidence: verified
severity: critical
title: Professional mode uses only explicitly selected work context
claim: Active owners explicitly choose professional mode independently of the profile
  STI type. Encrypted work context supplements at most six explicitly selected live
  notes, preferences, commitments, milestones and gift records per category; selectors
  are profile-scoped and exclude private or vault-protected notes. Professional draft,
  briefing, gift and event context excludes unselected personal sources even when
  sensitive flags are submitted; personal generation ignores dedicated work context.
  Work drafts force professional tone, generation rechecks source changes and mode/context
  writes advance profile fences. Local suggestions offer work follow-ups from selected
  commitments and date-only cadence prompts; gift recommendations require explicit
  suitability and work boundaries. Existing core records remain manually editable,
  and professional preparation links expose notes, follow-ups, milestones and review
  briefings. Generated draft history and briefings are filtered by mode and gift recommendations
  persist their mode. Owner exports include decrypted work context, account/profile
  deletion removes it, and requests filter context with no-store profile pages.
source_files:
- app/controllers/relationship_briefings_controller.rb
- app/controllers/gift_recommendations_controller.rb
- app/controllers/event_plans_controller.rb
- app/controllers/backup_plans_controller.rb
- app/services/event_plans/suggest.rb
- app/services/backup_plans/generate.rb
- app/agents/backup_plans/llm_generator.rb
- app/views/components/relationship_briefing_workspace_component.html.erb
- app/views/components/gift_recommendation_workspace_component.html.erb
- app/views/components/event_plan_workspace_component.html.erb
- app/controllers/message_drafts_controller.rb
- app/agents/event_plans/llm_suggester.rb
- db/migrate/20260905223854_add_relationship_mode_to_relationship_briefings.rb
- app/services/relationship_briefings/generate.rb
- app/models/relationship_briefing.rb
- db/migrate/20260905223316_add_relationship_mode_to_message_drafts.rb
- app/models/concerns/professional_relationship.rb
- app/models/professional_context.rb
- app/models/relationship_profile.rb
- app/controllers/relationship_profiles_controller.rb
- app/controllers/concerns/relationship_profile_show_workspace.rb
- app/models/message_draft.rb
- app/models/draft_revision.rb
- app/models/gift_recommendation.rb
- app/services/message_drafts/context_builder.rb
- app/services/message_drafts/generate.rb
- app/services/message_drafts/open_ai_generator.rb
- app/services/relationship_briefings/context_builder.rb
- app/services/relationship_briefings/open_ai_generator.rb
- app/services/gift_recommendations/context_builder.rb
- app/services/gift_recommendations/generate.rb
- app/services/gift_recommendations/open_ai_generator.rb
- app/services/event_plans/context_builder.rb
- app/services/gift_boxes/companions.rb
- app/services/suggestions/for_profile.rb
- app/views/components/professional_context_component.rb
- app/views/components/professional_context_component.html.erb
- app/views/components/message_draft_workspace_component.rb
- app/views/components/message_draft_workspace_component.html.erb
- app/views/relationship_profiles/_form.html.erb
- app/views/relationship_profiles/show.html.erb
- config/initializers/filter_parameter_logging.rb
- config/locales/professional_relationships.en.yml
- config/locales/professional_relationships.es.yml
- db/migrate/20260905221747_add_professional_context_to_relationship_profiles.rb
- db/migrate/20260905222535_add_relationship_mode_to_gift_recommendations.rb
- db/schema.rb
- docs/features/14-03-professional-relationship-mode.md
related_files:
- spec/requests/professional_generation_modes_spec.rb
- spec/requests/event_plans_spec.rb
- spec/components/professional_context_boundary_spec.rb
- spec/models/professional_relationship_spec.rb
- spec/services/professional_context_spec.rb
- spec/requests/professional_relationships_spec.rb
- spec/system/professional_relationships_spec.rb
symbols:
- ProfessionalContext
- ProfessionalRelationship
- MessageDrafts::ContextBuilder
- RelationshipBriefings::ContextBuilder
routes:
- GET /relationship_profiles/:id
- PATCH /relationship_profiles/:id
tags:
- relationship_profiles
- professional
- privacy
- source-selection
verification:
- bundle exec rspec spec/models/professional_relationship_spec.rb spec/services/professional_context_spec.rb
  spec/requests/professional_relationships_spec.rb spec/system/professional_relationships_spec.rb
- bundle exec rspec
- bin/memory validate
- bin/memory audit --git-diff
last_verified_commit: 7559337422b419fae6e64d414310574d502c8a70
---

# Professional work context

Active owners explicitly choose professional mode independently of the profile STI type. Encrypted work context supplements at most six explicitly selected live notes, preferences, commitments, milestones and gift records per category; selectors are profile-scoped and exclude private or vault-protected notes. Professional draft, briefing, gift and event context excludes unselected personal sources even when sensitive flags are submitted; personal generation ignores dedicated work context. Work drafts force professional tone, generation rechecks source changes and mode/context writes advance profile fences. Local suggestions offer work follow-ups from selected commitments and date-only cadence prompts; gift recommendations require explicit suitability and work boundaries. Existing core records remain manually editable, and professional preparation links expose notes, follow-ups, milestones and review briefings. Generated draft history and briefings are filtered by mode and gift recommendations persist their mode. Owner exports include decrypted work context, account/profile deletion removes it, and requests filter context with no-store profile pages.

## Why It Matters

Changing a relationship classification must never silently repurpose personal history for work suggestions. Selection references live core records rather than copying data into a second system. Existing types remain unchanged, and no external actions are automatic.

## Verification

- `bundle exec rspec spec/models/professional_relationship_spec.rb spec/services/professional_context_spec.rb spec/requests/professional_relationships_spec.rb spec/system/professional_relationships_spec.rb`
- `bundle exec rspec`

Draft settings retain their own mode even when provider generation fails, so a failed personal situation cannot prefill a work draft. Gift suitability additionally requires nonblank recorded work boundaries.

Recurring selected milestones use their next occurrence in the owner time zone. Generating guidance retires only results in the active mode, and the briefing uniqueness index permits one generated result per profile and mode.

Draft, briefing, gift (including alternatives), event suggestion and backup generation forms submit their expected relationship mode. Edits and generation reject cross-mode stale submissions under the profile lock, in either direction; legacy forms without the mode field are treated as personal. Event provider instructions prioritize business-appropriate language and work boundaries for professional sources.

Mode mismatches redirect to a freshly loaded workspace without retaining stale free-form text. Event and backup plan workspaces retain explicit plan intent while professional source boundaries override conflicting tone.

Professional event suggestion and backup-generation forms hide private-note and vault selectors, matching the server's source exclusion. Personal forms retain their existing per-request consent controls.
