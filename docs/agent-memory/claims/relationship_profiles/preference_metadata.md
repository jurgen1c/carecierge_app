---
id: relationship_profiles.preference_metadata
type: fact
system: relationship_profiles
status: current
confidence: verified
severity: important

title: Relationship preferences store structured metadata

claim: >
  RelationshipPreference stores type, category, confidence, learned date, and
  source notes. Legacy/default metadata uses neutral, general, and inferred
  labels; preference enum params are sanitized before assignment and nil nested
  preference attribute containers are ignored; localized preference labels render
  in profile forms and shows and participate in owner-scoped profile search.

source_files:
  - app/controllers/relationship_profiles_controller.rb
  - app/models/relationship_preference.rb
  - app/queries/relationship_profile/search_query.rb
  - app/views/relationship_profiles/_form.html.erb
  - app/views/relationship_profiles/show.html.erb
  - config/locales/en.yml
  - config/locales/es.yml
  - db/migrate/20260704203217_add_structured_fields_to_relationship_preferences.rb

related_files:
  - spec/models/relationship_preference_spec.rb
  - spec/queries/relationship_profile/search_query_spec.rb
  - spec/requests/relationship_profiles_spec.rb
symbols: []
routes: []
tags:
  - preference_metadata

verification:
  - bundle exec rspec spec/models/relationship_preference_spec.rb spec/queries/relationship_profile/search_query_spec.rb spec/requests/relationship_profiles_spec.rb

last_verified_commit: null
---

# Relationship preferences store structured metadata

## Claim

RelationshipPreference stores type, category, confidence, learned date, and
source notes. Legacy/default metadata uses neutral, general, and inferred labels;
preference enum params are sanitized before assignment and nil nested preference
attribute containers are ignored; localized preference labels render in profile
forms and shows and participate in owner-scoped profile search.

## Why It Matters

Preference data can include allergies, boundaries, cultural constraints, and
other sensitive relationship context. The metadata must be explicit, localized,
and scoped to the signed-in owner's profiles.

## Review Notes

CAR-25 reviewed this claim while adding onboarding important-date copy to English and Spanish
locales. Preference metadata behavior and localized preference labels remain unchanged.

## Evidence

- `db/migrate/20260704203217_add_structured_fields_to_relationship_preferences.rb`
- `app/models/relationship_preference.rb`
- `app/controllers/relationship_profiles_controller.rb`
- `app/queries/relationship_profile/search_query.rb`
- `app/views/relationship_profiles/_form.html.erb`
- `app/views/relationship_profiles/show.html.erb`
- `config/locales/en.yml`
- `config/locales/es.yml`

## Verification

- `bundle exec rspec spec/models/relationship_preference_spec.rb spec/queries/relationship_profile/search_query_spec.rb spec/requests/relationship_profiles_spec.rb`
