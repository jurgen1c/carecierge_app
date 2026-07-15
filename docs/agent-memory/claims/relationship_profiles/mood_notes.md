---
id: relationship_profiles.mood_notes
type: fact
system: relationship_profiles
status: current
confidence: high
severity: important

title: Mood notes are observation-first owner-scoped follow-up records

claim: >
  MoodNote records use authenticated, owner-scoped RelationshipProfile routes and
  store a non-diagnostic category, multiline observation, normalized timeline
  title, observed time, optional supportive action and follow-up, and timeline
  visibility that defaults off. Timeline-visible notes control one protected
  system TimelineEntry. Every saved note also controls one protected,
  source-backed derived Interaction for contact-cadence history. Deleting the
  note removes both derived records; disabling timeline visibility removes only
  the timeline entry. Turbo UI and validation copy remain localized in English
  and Spanish, and sensitive text is filtered from request logs.

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

Mood notes capture an observation without presenting it as a diagnosis. A note
can include a neutral category, observed moment, supportive action, and follow-up
time. Trimming preserves intentional line breaks, while timeline titles use a
single-line summary. New notes default off the timeline; enabling visibility
writes a protected system entry and disabling it removes that entry. Saving any
note also synchronizes one protected, source-backed Interaction for contact
cadence, and deleting the note removes both derived records.

All mood-note routes resolve the parent profile through the signed-in user and
authorize the nested record. The responsive Turbo surface uses localized English
and Spanish observation-first copy. Request parameter filtering
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
