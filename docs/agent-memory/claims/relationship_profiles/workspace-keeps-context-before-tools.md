---
id: relationship_profiles.workspace_keeps_context_before_tools
type: fact
system: relationship_profiles
status: current
confidence: verified
severity: normal

title: Relationship workspace keeps person context before tools

claim: >
  The owner-scoped People directory uses Ransack filters with 24 records per Pagy page, batch last-interaction dates and upcoming date context without eagerly loading note bodies or vault contents. Profiles lead with identity, practical actions and recorded facts, then six native addressable sections. Primary interaction and date actions target their inline form frames, and manual, recap and mood interaction changes refresh the recorded overview. Inline creation and generation forms open on intent; validation, Turbo refreshes and legacy fragments reveal the relevant section. Saved AI tools redirect with section=ideas while retaining legacy anchors.

source_files:
  - app/controllers/relationship_profiles_controller.rb
  - app/queries/people/summaries.rb
  - app/helpers/profile_workspace_helper.rb
  - app/javascript/controllers/profile_workspace_controller.js
  - app/views/relationship_profiles/index.html.erb
  - app/views/relationship_profiles/show.html.erb

related_files:
  - app/views/relationship_profiles/_about.html.erb
  - app/views/relationship_profiles/_overview.html.erb
  - app/views/components/person_card_component.rb
  - app/views/components/person_card_component.html.erb
  - app/views/components/profile_section_component.rb
  - app/views/components/profile_section_component.html.erb
  - app/views/components/form_reveal_component.rb
  - app/views/components/form_reveal_component.html.erb
  - app/controllers/gift_recommendations_controller.rb
  - app/controllers/message_drafts_controller.rb
  - app/controllers/relationship_briefings_controller.rb
  - app/views/interactions/refresh.turbo_stream.erb
  - app/views/conversation_recaps/refresh.turbo_stream.erb
  - app/views/mood_notes/refresh.turbo_stream.erb
  - app/views/important_dates/_upcoming.html.erb
  - app/views/components/action_link_component.rb
  - app/views/components/action_link_component.html.erb
  - spec/requests/conversation_recaps_spec.rb
  - spec/requests/mood_notes_spec.rb
  - config/locales/people.en.yml
  - config/locales/people.es.yml
  - config/locales/profile_workspace.en.yml
  - config/locales/profile_workspace.es.yml
  - spec/requests/people_workspace_spec.rb
  - spec/requests/profile_workspace_spec.rb
  - spec/system/workspace_experience_spec.rb

symbols:
  - People::Summaries
  - ProfileWorkspaceHelper
  - ProfileSectionComponent
  - FormRevealComponent
  - RelationshipProfilesController#index

routes:
  - relationship_profiles
  - relationship_profile

tags:
  - relationship_profiles
  - workspace
  - localization

verification:
  - bundle exec rspec spec/requests/people_workspace_spec.rb spec/requests/profile_workspace_spec.rb spec/requests/conversation_recaps_spec.rb spec/requests/mood_notes_spec.rb spec/requests/gift_recommendations_spec.rb spec/requests/message_drafts_spec.rb spec/requests/relationship_briefings_spec.rb spec/system/workspace_experience_spec.rb

last_verified_commit: 2d93680db18b6ed38fedaca363b27416b90346f3
---

# Relationship workspace keeps person context before tools

## Claim

The owner-scoped People directory uses Ransack filters with 24 records per Pagy page, batch last-interaction dates and upcoming date context without eagerly loading note bodies or vault contents. Profiles lead with identity, practical actions and recorded facts, then six native addressable sections. Primary interaction and date actions target their inline form frames, and manual, recap and mood interaction changes refresh the recorded overview. Inline creation and generation forms open on intent; validation, Turbo refreshes and legacy fragments reveal the relevant section. Saved AI tools redirect with section=ideas while retaining legacy anchors.

## Why It Matters

Grouping an existing capability must not remove it or strand its errors inside a closed section. Directory context must not copy sensitive note bodies. Actual source actions and professional/privacy guards remain authoritative.

## Verification

- `bundle exec rspec spec/requests/people_workspace_spec.rb spec/requests/profile_workspace_spec.rb spec/requests/conversation_recaps_spec.rb spec/requests/mood_notes_spec.rb spec/requests/gift_recommendations_spec.rb spec/requests/message_drafts_spec.rb spec/requests/relationship_briefings_spec.rb spec/system/workspace_experience_spec.rb`

Full `bin/ci` passed on `2d93680db18b6ed38fedaca363b27416b90346f3` with all claim-related examples included.
