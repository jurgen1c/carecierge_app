---
id: relationship_profiles.important_dates
type: fact
system: relationship_profiles
status: current
confidence: high
severity: important

title: Important dates are owner-scoped relationship memory

claim: >
  ImportantDate records belong to a RelationshipProfile and are managed through
  authenticated, owner-scoped nested routes. Important dates support birthday,
  anniversary, milestone, appointment, holiday, and custom date types; one-time,
  yearly, monthly, and weekly recurrence; importance levels; reminder schedule
  intent; notes; deterministic next-occurrence calculations; and soft localized
  planning prompts for upcoming dates. Onboarding can capture optional initial
  important dates while creating the first relationship profile, rejects blank
  date rows, and validates supported date, recurrence, importance, and reminder
  options before completing onboarding. The relationship profile show surface
  presents a richer important-dates work area plus a compact upcoming-dates
  right rail, and create, update, and delete actions refresh those surfaces with
  Turbo streams when possible instead of requiring a full page reload. Planning
  links only target suggestions rendered in the current profile surface, and
  planning prompts resolve through date-specific locale keys with a default
  locale-key fallback.

source_files:
  - app/models/important_date.rb
  - app/models/relationship_profile.rb
  - app/controllers/onboarding_controller.rb
  - app/controllers/important_dates_controller.rb
  - app/policies/important_date_policy.rb
  - app/views/onboarding/show.html.erb
  - app/views/important_dates/_important_date.html.erb
  - app/views/important_dates/_form_frame.html.erb
  - app/views/important_dates/_section.html.erb
  - app/views/important_dates/_upcoming.html.erb
  - app/views/important_dates/edit.html.erb
  - app/views/important_dates/new.html.erb
  - db/migrate/20260704193000_create_important_dates.rb

related_files:
  - spec/models/important_date_spec.rb
  - spec/requests/important_dates_spec.rb
  - spec/requests/onboarding_spec.rb
symbols:
  - ImportantDate
  - ImportantDatesController
  - OnboardingController
  - RelationshipProfile#important_dates_attributes=
  - ImportantDatePolicy
  - RelationshipProfile#upcoming_important_dates
  - RelationshipProfile#planning_important_dates
routes:
  - relationship_profile_important_dates
  - relationship_profile_important_date
  - new_relationship_profile_important_date
  - edit_relationship_profile_important_date
tags:
  - important_dates
  - turbo
  - planning

verification:
  - bundle exec rspec spec/models/important_date_spec.rb spec/requests/important_dates_spec.rb
  - bundle exec rspec spec/requests/onboarding_spec.rb
  - bundle exec rspec spec/requests/relationship_profiles_spec.rb spec/models/relationship_profile_spec.rb spec/models/important_date_spec.rb spec/requests/important_dates_spec.rb
  - bundle exec rspec
last_verified_commit: null
---

# Important dates are owner-scoped relationship memory

## Claim

Important dates are relationship-profile-owned records used to store recurring
and one-time moments with reminder intent and planning prompts. They are
localized, scoped through the signed-in user's relationship profiles, can be
captured during onboarding as optional nested profile details, and are updated
inline through Turbo streams where possible. Timeline and upcoming-date planning
links are shown only when the matching planning suggestion anchor is rendered.
Planning prompts use date-type-specific translations with a shared default
fallback key.

## Why It Matters

Important dates will feed later reminders, planning workflows, digests, and
automation. They must stay attached to the owner-scoped relationship profile
boundary so future planning systems do not introduce a parallel personal-memory
store or leak dates across users.

## Evidence

- `app/models/important_date.rb`
- `app/models/relationship_profile.rb`
- `app/controllers/onboarding_controller.rb`
- `app/controllers/important_dates_controller.rb`
- `app/policies/important_date_policy.rb`
- `app/views/onboarding/show.html.erb`
- `app/views/important_dates/_important_date.html.erb`
- `app/views/important_dates/_section.html.erb`
- `app/views/important_dates/_upcoming.html.erb`
- `db/migrate/20260704193000_create_important_dates.rb`
- `spec/models/important_date_spec.rb`
- `spec/requests/important_dates_spec.rb`
- `spec/requests/onboarding_spec.rb`

## Verification

- `bundle exec rspec spec/models/important_date_spec.rb spec/requests/important_dates_spec.rb`
- `bundle exec rspec spec/requests/onboarding_spec.rb`
- `bundle exec rspec spec/requests/relationship_profiles_spec.rb spec/models/relationship_profile_spec.rb spec/models/important_date_spec.rb spec/requests/important_dates_spec.rb`
- `bundle exec rspec`
