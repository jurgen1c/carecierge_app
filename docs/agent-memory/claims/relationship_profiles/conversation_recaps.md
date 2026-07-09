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
  transcript text, and extraction request status for future AI workflows. Manual
  create, edit, and delete actions refresh the profile conversation-recaps and
  relationship-timeline sections with Turbo streams, preserve English and
  Spanish localized labels and validation copy, create or update a linked
  system TimelineEntry with entry_type conversation_recap, delete the linked
  timeline entry with the recap, keep that source-backed timeline entry protected
  from direct generic timeline edit and delete actions, and cannot access another
  user's relationship profile. User params can request extraction review, but cannot approve
  extracted facts or create MemoryRecord rows directly; memory mutation remains
  blocked until a later explicit approval workflow.

source_files:
  - app/models/conversation_recap.rb
  - app/controllers/conversation_recaps_controller.rb
  - app/policies/conversation_recap_policy.rb
  - app/views/conversation_recaps/_conversation_recap.html.erb
  - app/views/conversation_recaps/_form.html.erb
  - app/views/conversation_recaps/_section.html.erb
  - db/migrate/20260709183000_create_conversation_recaps.rb

related_files:
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
  - bundle exec rspec
last_verified_commit: null
---

# Conversation recaps are owner-scoped and approval-gated before memory mutation

## Claim

Conversation recaps are relationship-profile-owned records used to capture text
summaries of conversations while preserving room for future voice-to-text and AI
extraction flows. The recap stores typed or voice-transcript capture source,
optional transcript text, occurrence time, extraction request status, and
approval timestamps that cannot be set by user-facing create/update params.
Creating or updating a recap writes a linked system TimelineEntry with
`entry_type` `conversation_recap`, and deleting the recap deletes that linked
timeline entry. That source-backed timeline row cannot be directly edited or
deleted through the generic timeline actions. The profile surface renders recaps
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
- `app/policies/conversation_recap_policy.rb`
- `app/views/conversation_recaps/_section.html.erb`
- `app/views/conversation_recaps/_conversation_recap.html.erb`
- `app/views/relationship_profiles/show.html.erb`
- `db/migrate/20260709183000_create_conversation_recaps.rb`
- `spec/models/conversation_recap_spec.rb`
- `spec/requests/conversation_recaps_spec.rb`

## Verification

- `bundle exec rspec`
