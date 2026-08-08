---
id: relationship_profiles.conversation_recaps
type: fact
system: relationship_profiles
status: current
confidence: high
severity: important

title: Conversation recaps are owner-scoped and approval-gated before memory mutation

claim: >
  ConversationRecap records belong to a RelationshipProfile and are managed
  through authenticated, owner-scoped nested routes. Recaps store a title, text
  recap body, occurrence time, typed or voice-transcript capture source, optional
  transcript text, and extraction status. Feature-flagged extraction requests
  enqueue MemoryExtractionJob after the recap transaction commits. Manual
  CRUD refreshes the profile recap and timeline sections with Turbo streams,
  preserves localized English and Spanish copy, creates or updates a linked
  system TimelineEntry with entry_type conversation_recap, delete the linked
  timeline entry with the recap, sync one source-backed derived
  Interaction for contact-cadence history, delete that interaction with the
  recap, keep those source-backed history rows protected
  from direct generic timeline edit and delete actions, and cannot access another
  user's relationship profile. Extracted proposals remain separate until owner
  review under relationship_profiles.ai_memory_extraction. Recap bodies and transcripts remain filtered
  from Rails parameter logging when the shared filter also protects account
  deletion confirmations. User params can request extraction review during
  creation or a later edit while the recap remains not_requested, but cannot
  approve extracted facts or create MemoryRecord rows directly; memory mutation
  remains blocked until explicit proposal approval or correction.

source_files:
  - app/models/conversation_recap.rb
  - app/controllers/conversation_recaps_controller.rb
  - config/initializers/filter_parameter_logging.rb
  - app/policies/conversation_recap_policy.rb
  - app/views/conversation_recaps/_conversation_recap.html.erb
  - app/views/conversation_recaps/_form.html.erb
  - app/views/conversation_recaps/_section.html.erb
  - app/jobs/memory_extraction_job.rb
  - db/migrate/20260709183000_create_conversation_recaps.rb

related_files:
  - spec/config/filter_parameter_logging_spec.rb
  - spec/models/conversation_recap_spec.rb
  - spec/requests/conversation_recaps_spec.rb
symbols:
  - ConversationRecap
  - ConversationRecapsController
  - ConversationRecapPolicy
  - RelationshipProfile#conversation_recaps
  - ConversationRecap#request_memory_extraction
  - MemoryExtractionJob
routes:
  - relationship_profile_conversation_recaps
  - relationship_profile_conversation_recap
  - new_relationship_profile_conversation_recap
  - edit_relationship_profile_conversation_recap
  - retry_extraction_relationship_profile_conversation_recap
tags:
  - conversation_recaps
  - memory_approval
  - ai_extraction

verification:
  - bundle exec rspec spec/config/filter_parameter_logging_spec.rb spec/requests/conversation_recaps_spec.rb
  - bundle exec rspec
last_verified_commit: null
---

# Conversation recaps are owner-scoped and approval-gated before memory mutation

## Claim

Conversation recaps are relationship-profile-owned records that capture
conversation summaries with typed or voice-transcript sources, optional
transcript text, occurrence time, and system-managed extraction state. Recap
bodies and transcripts are filtered from logs. Enabled first-time requests
enqueue `MemoryExtractionJob` after the recap transaction commits; disabled
rollout contexts ignore forged request parameters.

Create and update synchronize linked system `TimelineEntry` and derived
`Interaction` rows; recap deletion removes both. Generic history routes cannot
edit or delete those source-backed rows. The localized profile surface refreshes
recap and timeline sections through Turbo. Extracted proposals remain separate
under `relationship_profiles.ai_memory_extraction` until individual owner
approval, rejection, or correction.

## Why It Matters

Conversation recaps can contain sensitive relationship context and are a likely
input to future AI extraction. Keeping recaps owner-scoped, linked to the
relationship timeline, and separated from MemoryRecord mutation until explicit
approval prevents silent memory changes and keeps automation reviewable.

## Evidence

- `app/models/conversation_recap.rb`
- `app/controllers/conversation_recaps_controller.rb`
- `config/initializers/filter_parameter_logging.rb`
- `app/policies/conversation_recap_policy.rb`
- `app/views/conversation_recaps/_section.html.erb`
- `app/views/conversation_recaps/_conversation_recap.html.erb`
- `app/views/relationship_profiles/show.html.erb`
- `db/migrate/20260709183000_create_conversation_recaps.rb`
- `spec/models/conversation_recap_spec.rb`
- `spec/requests/conversation_recaps_spec.rb`
- `spec/config/filter_parameter_logging_spec.rb`

## Verification

- `bundle exec rspec spec/config/filter_parameter_logging_spec.rb spec/requests/conversation_recaps_spec.rb`
- `bundle exec rspec`
