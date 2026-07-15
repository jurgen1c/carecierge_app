---
id: relationship_profiles.contact_cadence
type: fact
system: relationship_profiles
status: current
confidence: high
severity: important

title: Contact cadence uses owner-scoped meaningful interactions and supportive prompts

claim: >
  ContactCadence records store one user-accepted check-in interval per
  RelationshipProfile while relationship types provide unpersisted suggestions.
  Interaction records form an owner-scoped chronological history of manual calls,
  messages, visits, video calls, and other check-ins plus polymorphic derived
  sources. Conversation recaps and mood notes transactionally create or update one
  traceable derived interaction, and existing non-future source records are
  backfilled while legacy future-dated sources remain untouched.
  Derived interactions remain controlled by their source workflows and cannot be
  changed through manual interaction routes. Interaction notes are filtered from
  request logs, and owner-scoped cadence controls remain available when viewing an
  archived relationship profile. Conversation recaps and mood notes reject future
  source timestamps before derived-interaction synchronization. The latest
  recorded interaction, or cadence acceptance time when history is empty,
  determines the next check-in window. Overdue UI copy explicitly treats missing
  history as uncertain and can link to the existing Reminder form, but cadence
  never creates reminders or claims that contact did not happen.

source_files:
  - app/models/contact_cadence.rb
  - app/models/interaction.rb
  - app/controllers/contact_cadences_controller.rb
  - app/controllers/interactions_controller.rb
  - app/views/contact_cadences/_section.html.erb
  - db/migrate/20260715030524_create_contact_cadences.rb
  - db/migrate/20260715030525_create_interactions.rb
  - db/migrate/20260715032726_enforce_interaction_origin_type_pairing.rb
  - db/data/20260715031947_backfill_interactions_from_relationship_sources.rb

related_files:
  - app/controllers/conversation_recaps_controller.rb
  - app/controllers/mood_notes_controller.rb
  - app/policies/contact_cadence_policy.rb
  - app/policies/interaction_policy.rb
  - app/views/interactions/_interaction.html.erb
  - config/locales/contact_rhythm.en.yml
  - config/locales/contact_rhythm.es.yml
  - spec/models/contact_cadence_spec.rb
  - spec/models/interaction_spec.rb
  - spec/data_migrations/backfill_interactions_from_relationship_sources_spec.rb
  - spec/requests/contact_cadences_spec.rb
  - spec/requests/interactions_spec.rb
symbols:
  - ContactCadence
  - Interaction
  - ContactCadencesController
  - InteractionsController
routes:
  - relationship_profile_contact_cadence
  - new_relationship_profile_contact_cadence
  - edit_relationship_profile_contact_cadence
  - relationship_profile_interactions
  - relationship_profile_interaction
  - new_relationship_profile_interaction
  - edit_relationship_profile_interaction
tags:
  - contact_cadence
  - interactions

verification:
  - bundle exec rspec spec/config/filter_parameter_logging_spec.rb
  - bundle exec rspec spec/data_migrations/backfill_interactions_from_relationship_sources_spec.rb
  - bundle exec rspec spec/models/contact_cadence_spec.rb spec/models/interaction_spec.rb spec/policies/contact_cadence_policy_spec.rb spec/policies/interaction_policy_spec.rb spec/requests/contact_cadences_spec.rb spec/requests/interactions_spec.rb spec/requests/conversation_recaps_spec.rb spec/requests/mood_notes_spec.rb
last_verified_commit: null
---

# Contact cadence uses owner-scoped meaningful interactions and supportive prompts

## Claim

Each relationship can accept or adjust one suggested contact rhythm and build a
meaningful interaction history without turning missing data into a relationship
score. Manual interactions and source-backed derived interactions share the same
owner-scoped history, while polymorphic provenance keeps later integration
adapters possible without coupling cadence to those external systems.
The historical backfill includes only source timestamps that have already
occurred, so legacy future-dated rows cannot postpone cadence prompts.

Cadence uses the most recent interaction to calculate a next check-in window.
When the window passes, Carecierge explains that a recent contact may simply be
missing, offers manual logging, and links to the existing reminder workflow. It
does not automatically schedule or deliver anything.

## Why It Matters

Relationship data is incomplete by nature. The product must support follow-through
without presenting incomplete records as evidence of neglect or creating a second
notification system beside Reminder.

## Evidence

- `app/models/contact_cadence.rb`
- `app/models/interaction.rb`
- `app/controllers/contact_cadences_controller.rb`
- `app/controllers/interactions_controller.rb`
- `app/controllers/conversation_recaps_controller.rb`
- `app/controllers/mood_notes_controller.rb`
- `app/views/contact_cadences/_section.html.erb`
- `spec/models/contact_cadence_spec.rb`
- `spec/models/interaction_spec.rb`
- `spec/data_migrations/backfill_interactions_from_relationship_sources_spec.rb`
- `spec/requests/contact_cadences_spec.rb`
- `spec/requests/interactions_spec.rb`

## Verification

- `bundle exec rspec spec/config/filter_parameter_logging_spec.rb`
- `bundle exec rspec spec/data_migrations/backfill_interactions_from_relationship_sources_spec.rb`
- `bundle exec rspec spec/models/contact_cadence_spec.rb spec/models/interaction_spec.rb spec/policies/contact_cadence_policy_spec.rb spec/policies/interaction_policy_spec.rb spec/requests/contact_cadences_spec.rb spec/requests/interactions_spec.rb spec/requests/conversation_recaps_spec.rb spec/requests/mood_notes_spec.rb`
