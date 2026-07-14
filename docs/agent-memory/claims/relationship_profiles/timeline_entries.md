---
id: relationship_profiles.timeline_entries
type: fact
system: relationship_profiles
status: current
confidence: high
severity: important

title: Timeline entries are owner-scoped relationship history

claim: >
  TimelineEntry records belong to a RelationshipProfile and are managed through
  authenticated, owner-scoped nested routes. Timeline entries store a supported
  entry type, manual or system origin, title, optional body, occurrence time, and
  optional polymorphic source record reference constrained to the same
  relationship profile when the source exposes relationship_profile_id. The
  current relationship profile UI supports manual create, edit, delete, and type
  filtering with Turbo stream refreshes that preserve the active type filter,
  preserves English and Spanish localized labels and validation copy, renders
  entries as an unboxed chronological feed with a responsive context summary, and
  does not accept forged system-origin or source-record params from the manual
  form. Source-backed entries cannot be edited or deleted through the generic
  timeline actions, so conversation recap and mood-note entries stay controlled
  by their source workflows. Conversation recaps create linked system
  conversation_recap entries, while timeline-visible mood notes create linked
  system mood_note entries that are removed when timeline visibility is disabled.

source_files:
  - app/models/timeline_entry.rb
  - app/controllers/timeline_entries_controller.rb
  - app/policies/timeline_entry_policy.rb
  - app/views/timeline_entries/_timeline_entry.html.erb
  - app/views/timeline_entries/_form.html.erb
  - app/views/timeline_entries/_section.html.erb
  - db/migrate/20260709120000_create_timeline_entries.rb

related_files:
  - spec/models/timeline_entry_spec.rb
  - spec/requests/timeline_entries_spec.rb
symbols:
  - TimelineEntry
  - TimelineEntriesController
  - TimelineEntryPolicy
  - RelationshipProfile#timeline_entries
routes:
  - relationship_profile_timeline_entries
  - relationship_profile_timeline_entry
  - new_relationship_profile_timeline_entry
  - edit_relationship_profile_timeline_entry
tags:
  - timeline_entries
  - relationship_history

verification:
  - bundle exec rspec
last_verified_commit: null
---

# Timeline entries are owner-scoped relationship history

## Claim

Timeline entries are relationship-profile-owned records that store chronological
relationship history with type, origin, occurrence time, title, optional body,
and optional source-object references. Source records that expose
`relationship_profile_id` must belong to the same profile before the timeline
entry can be saved. Manual create, edit, delete, and type filtering are scoped
through the signed-in user's relationship profiles and update inline through
Turbo streams where possible while preserving the active timeline type filter.
Manual params cannot forge system-origin metadata or source-record references.
Source-backed entries cannot be edited or deleted through the generic timeline
actions, so linked source records remain the owner of their generated timeline
content. Conversation recaps create linked system conversation-recap entries,
and timeline-visible mood notes create linked system mood-note entries. The
profile show surface renders entries as an unboxed chronological feed with a context summary
that stacks below the feed on smaller screens.

## Why It Matters

The timeline is the relationship history backbone for notes, gifts, promises,
corrections, plans, and later automation. It must stay attached to the existing
owner-scoped relationship profile boundary so future source-object and
system-created entries do not create a parallel memory store or leak private
relationship history across users.

## Evidence

- `app/models/timeline_entry.rb`
- `app/models/conversation_recap.rb`
- `app/controllers/timeline_entries_controller.rb`
- `app/controllers/conversation_recaps_controller.rb`
- `app/controllers/mood_notes_controller.rb`
- `app/policies/timeline_entry_policy.rb`
- `app/views/timeline_entries/_section.html.erb`
- `app/views/timeline_entries/_timeline_entry.html.erb`
- `app/views/relationship_profiles/show.html.erb`
- `db/migrate/20260709120000_create_timeline_entries.rb`
- `spec/models/timeline_entry_spec.rb`
- `spec/requests/timeline_entries_spec.rb`
- `spec/requests/conversation_recaps_spec.rb`
- `spec/requests/mood_notes_spec.rb`

## Verification

- `bundle exec rspec`
