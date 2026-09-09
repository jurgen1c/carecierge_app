---
id: relationship_profiles.professional_mode_uses_only_explicitly_selected_work_context
type: constraint
system: relationship_profiles
status: current
confidence: high
severity: critical
title: Professional mode uses only explicitly selected work context
claim: Concierge execution and decisions preflight professional scope before mutation,
  including known-ID writes and global queries. Personal records and birthdays cannot
  enter professional turns. Newly requested work notes, preferences, commitments and
  dates, suitable gifts and gift boxes, plans, reminders, vendors and comparisons add only their new record to the bounded work selection; existing personal
  records are not imported and full categories refuse creation before persistence.
  Work metadata and gift-suitability edits require exact inline approval and preserve
  selected IDs. Authorized context extension also refreshes the profile source
  in the same action result, preserving follow-through after people lookup and
  revalidation of unrelated later profile changes. Generated work content keeps an immutable authorization fingerprint
  including selected source content versions, so later edits cannot reauthorize old output.
  Chat reuses the owner-facing work-context editor with exact profile-version checks.
  Changed mode or source selection starts an empty conversation, invalidates prior
  captured context even before its first tool, and preserves the old messages without
  importing them. Suitable generated gifts are accepted into selected work records;
  earlier ideas must be refreshed after the work selection changes.
  Selected plans, reminders, gift boxes, vendors and comparisons authorize conversational control without automatically
  importing their contents or related records into generated work guidance. Plans,
  tasks, suggestions and reviewed backups retain selected work evidence; old tasks
  with unselected personal sources remain excluded even inside a selected plan.
  Reminder links resolve only selected same-person sources, and source-backed work
  suggestions can create explicitly timed selected reminders. Adding a new work
  record prunes unavailable old selections without importing other records. Gift preparation
  requires selected gifts and plans plus explicit suitability. Manual quotes require a
  selected vendor and plan; comparisons expose only selected vendor options. Manual
  booking receipts omit personal timeline entries in work mode. Checklists require a
  selected occasion and selected preference evidence; new work checklists use practical
  work prompts and omit gift prompts when gifts are unsuitable.
  Active owners explicitly choose professional mode independently of the profile
  STI type. Encrypted work context supplements at most six explicitly selected live
  notes, preferences, commitments, milestones, gifts, plans, reminders, gift boxes, vendors
  and comparisons per category. Vendors are owner-scoped; other selectors are
  profile-scoped and exclude private or vault-protected notes. Professional draft,
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
- app/services/concierge/operations/gift_purchases.rb
- app/services/concierge/operations/gift_boxes.rb
- app/services/concierge/gift_sources.rb
- app/services/concierge/operations/vendors.rb
- app/services/concierge/operations/shortlists.rb
- app/services/concierge/operations/vendor_options.rb
- app/services/concierge/operations/quotes.rb
- app/services/concierge/operations/bookings.rb
- app/services/concierge/operations/manual_plan_records.rb
- app/services/concierge/vendor_sources.rb
- app/services/concierge/operations/touches.rb
- app/services/personal_touch_checklists/create.rb
- app/services/concierge/operations/plans.rb
- app/services/concierge/operations/tasks.rb
- app/services/concierge/operations/reminders.rb
- app/services/concierge/operations/plan_ideas.rb
- app/services/concierge/operations/backups.rb
- app/services/concierge/operations/ideas.rb
- app/services/concierge/occasion_sources.rb
- app/services/concierge/history.rb
- app/services/concierge/configure_context.rb
- app/services/concierge/context.rb
- app/controllers/concierge_contexts_controller.rb
- app/views/concierge_contexts/edit.html.erb
- app/views/concierge_conversations/index.html.erb
- app/services/concierge/operations/gifts.rb
- app/services/concierge/operations/gift_ideas.rb
- app/services/concierge/professional_scope.rb
- app/services/concierge/operations/work.rb
- app/services/concierge/operations/profile_records.rb
- app/services/concierge/operations/people.rb
- app/services/concierge/operations/notes.rb
- app/services/concierge/generated_sources.rb
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
- spec/services/concierge/vendors_spec.rb
- spec/services/personal_touch_checklists/create_spec.rb
- spec/services/concierge/plan_ideas_spec.rb
- spec/services/concierge/occasions_spec.rb
- spec/services/concierge/ideas_spec.rb
- spec/services/concierge/configure_context_spec.rb
- spec/requests/concierge_contexts_spec.rb
- spec/system/concierge_spec.rb
- spec/services/concierge/gifts_spec.rb
- spec/services/concierge/professional_scope_spec.rb
- spec/services/concierge/generated_actions_spec.rb
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
- GET /concierge/:concierge_conversation_id/relationship_context/edit
- PATCH /concierge/:concierge_conversation_id/relationship_context
- GET /relationship_profiles/:id
- PATCH /relationship_profiles/:id
tags:
- relationship_profiles
- professional
- privacy
- source-selection
verification:
- bundle exec rspec spec/services/concierge/gifts_spec.rb spec/services/concierge/vendors_spec.rb spec/services/concierge/occasions_spec.rb spec/services/personal_touch_checklists/create_spec.rb
- bundle exec rspec spec/services/concierge/professional_scope_spec.rb spec/services/concierge/plan_ideas_spec.rb spec/services/concierge/occasions_spec.rb spec/services/concierge/ideas_spec.rb
- bundle exec rspec spec/services/concierge/configure_context_spec.rb spec/services/concierge/professional_scope_spec.rb spec/services/concierge/gifts_spec.rb spec/requests/concierge_contexts_spec.rb spec/system/concierge_spec.rb
- bundle exec rspec spec/services/concierge/professional_scope_spec.rb spec/services/concierge/generated_actions_spec.rb
- bundle exec rspec spec/models/professional_relationship_spec.rb spec/services/professional_context_spec.rb
  spec/requests/professional_relationships_spec.rb spec/system/professional_relationships_spec.rb
- bundle exec rspec
- bin/memory validate
- bin/memory audit --git-diff
last_verified_commit: cc0ce9edfa8a02156d651f817eea75d9f8ec4a7f
---

# Professional work context

Active owners explicitly choose professional mode independently of the profile STI type. Encrypted work context permits at most six live records per category. Notes, preferences, commitments, milestones and gifts supply generated work guidance. Plans, reminders, gift boxes, vendors and comparisons additionally authorize conversational control without importing their related records. Vendors belong to the owner account; other selectors belong to the profile and exclude private or vault-protected notes. Professional draft, briefing, gift and event context excludes unselected personal sources even when sensitive flags are submitted; personal generation ignores dedicated work context. Work drafts force professional tone, generation rechecks source changes and mode/context writes advance profile fences. Local suggestions offer work follow-ups from selected commitments and date-only cadence prompts; gift recommendations require explicit suitability and work boundaries. Existing core records remain manually editable, and professional preparation links expose notes, follow-ups, milestones and review briefings. Generated draft history and briefings are filtered by mode and gift recommendations persist their mode. Owner exports include decrypted work context, account/profile deletion removes it, and requests filter context with no-store profile pages.

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
