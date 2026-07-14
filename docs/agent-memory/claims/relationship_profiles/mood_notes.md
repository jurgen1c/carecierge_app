---
id: relationship_profiles.mood_notes
type: fact
system: relationship_profiles
status: current
confidence: high
severity: important

title: Mood notes are observation-first owner-scoped follow-up records

claim: >
  MoodNote records belong to a RelationshipProfile and are managed through
  authenticated, owner-scoped nested routes. Mood notes store a supported
  non-diagnostic observation category, user-authored observation with intentional
  line breaks preserved, observed time,
  optional supportive action, optional follow-up time, and an opt-in timeline
  visibility choice that defaults off. Manual create, edit, and delete actions
  refresh the profile mood-note and relationship-timeline sections with Turbo
  streams, preserve English and Spanish observation-first copy, and cannot access
  another user's relationship profile. Timeline-visible notes create or update a
  linked system TimelineEntry with entry_type mood_note; disabling timeline
  visibility or deleting the note removes that linked entry, and generic timeline actions
  cannot edit or delete the source-backed row. Sensitive observation and
  supportive-action parameters are filtered from application request logs.

source_files:
  - app/models/mood_note.rb
  - app/controllers/mood_notes_controller.rb
  - app/policies/mood_note_policy.rb
  - app/views/mood_notes/_mood_note.html.erb
  - app/views/mood_notes/_form.html.erb
  - app/views/mood_notes/_section.html.erb
  - db/migrate/20260714003747_create_mood_notes.rb

related_files:
  - spec/models/mood_note_spec.rb
  - spec/policies/mood_note_policy_spec.rb
  - spec/requests/mood_notes_spec.rb
symbols:
  - MoodNote
  - MoodNotesController
  - MoodNotePolicy
  - RelationshipProfile#mood_notes
routes:
  - relationship_profile_mood_notes
  - relationship_profile_mood_note
  - new_relationship_profile_mood_note
  - edit_relationship_profile_mood_note
tags:
  - mood_notes
  - observations
  - follow_ups

verification:
  - bundle exec rspec spec/models/mood_note_spec.rb spec/policies/mood_note_policy_spec.rb spec/requests/mood_notes_spec.rb spec/models/timeline_entry_spec.rb
  - bundle exec rspec
last_verified_commit: null
---

# Mood notes are observation-first owner-scoped follow-up records

## Claim

Mood notes capture what a user observed about someone in a relationship without
presenting the observation as a diagnosis. Each note can include a neutral
category, the observed moment, a concrete supportive action, and a follow-up
time. Leading and trailing observation whitespace is trimmed while intentional
line breaks remain available to the profile UI. The user explicitly controls
whether the note also appears in the relationship timeline, with new notes
defaulting to private. Enabling that choice writes a linked system timeline
entry; disabling it or deleting the note removes the linked entry.

All mood-note routes resolve the parent profile through the signed-in user and
authorize the nested record. The profile surface and Turbo refreshes use
localized English and Spanish copy that reinforces observable language and
keeps the workflow usable on mobile and desktop. Request parameter filtering
prevents observation and supportive-action text from appearing in plaintext
application logs.

## Why It Matters

Emotional observations are sensitive relationship data. Keeping them inside the
existing owner boundary, avoiding diagnostic claims, and making timeline
visibility reversible lets users plan care without turning a private impression
into an authoritative assessment.

## Evidence

- `app/models/mood_note.rb`
- `app/controllers/mood_notes_controller.rb`
- `app/policies/mood_note_policy.rb`
- `app/views/mood_notes/_section.html.erb`
- `app/views/mood_notes/_form.html.erb`
- `app/views/mood_notes/_mood_note.html.erb`
- `app/models/timeline_entry.rb`
- `db/migrate/20260714003747_create_mood_notes.rb`
- `config/initializers/filter_parameter_logging.rb`
- `spec/models/mood_note_spec.rb`
- `spec/policies/mood_note_policy_spec.rb`
- `spec/requests/mood_notes_spec.rb`
- `spec/config/filter_parameter_logging_spec.rb`

## Verification

- `bundle exec rspec spec/models/mood_note_spec.rb spec/policies/mood_note_policy_spec.rb spec/requests/mood_notes_spec.rb spec/models/timeline_entry_spec.rb`
- `bundle exec rspec spec/config/filter_parameter_logging_spec.rb spec/requests/localization_spec.rb`
- `bundle exec rspec`
