---
id: relationship_profiles.conversation_recaps
type: fact
system: relationship_profiles
status: current
confidence: verified
severity: important

title: Conversation recaps are owner-scoped and approval-gated before memory mutation

claim: >
  ConversationRecap records belong to a RelationshipProfile and are managed
  through authenticated, owner-scoped nested routes. Recaps store a title, text
  recap body, occurrence time, typed or voice-transcript capture source, optional
  transcript text, and extraction status. Manual
  CRUD refreshes the profile recap and timeline sections with Turbo streams,
  preserves localized English and Spanish copy, creates or updates a linked
  system TimelineEntry with entry_type conversation_recap, delete the linked
  timeline entry with the recap, sync one source-backed derived
  Interaction for contact-cadence history, delete that interaction with the
  recap, keep those source-backed history rows protected
  from direct generic timeline edit and delete actions, and cannot access another
  user's relationship profile. Recap bodies and transcripts remain filtered
  from Rails parameter logging when the shared filter also protects account
  deletion confirmations. User params can request extraction review during
  creation or a later edit while the recap remains not_requested, but cannot
  approve extracted facts or create MemoryRecord rows directly; memory mutation
  remains blocked until a later explicit approval workflow.

source_files:
  - app/models/conversation_recap.rb
  - app/controllers/conversation_recaps_controller.rb
  - config/initializers/filter_parameter_logging.rb
  - app/policies/conversation_recap_policy.rb
  - app/views/conversation_recaps/_conversation_recap.html.erb
  - app/views/conversation_recaps/_form.html.erb
  - app/views/conversation_recaps/_section.html.erb
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
routes:
  - relationship_profile_conversation_recaps
  - relationship_profile_conversation_recap
  - new_relationship_profile_conversation_recap
  - edit_relationship_profile_conversation_recap
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
conversation summaries, including voice transcript and future AI extraction.
The recap stores typed or voice-transcript capture source,
optional transcript text, occurrence time, extraction request status, and
approval timestamps that cannot be set by user-facing create/update params.
Recap bodies and transcripts remain filtered when the shared parameter filter
adds account-deletion confirmation protection, and
users can request extraction during creation or a later edit while the recap
has not yet requested extraction.
Creating or updating a recap writes a linked system TimelineEntry with
`entry_type` `conversation_recap`, and deleting the recap deletes that linked
timeline entry. It also synchronizes one source-backed derived Interaction used
by contact cadence, and deleting the recap removes that interaction. Those
source-backed rows cannot be directly edited or deleted through generic manual
history actions. The profile surface renders recaps
inline, refreshes the recap and timeline sections through Turbo streams, and
keeps copy localized in English and Spanish.

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
