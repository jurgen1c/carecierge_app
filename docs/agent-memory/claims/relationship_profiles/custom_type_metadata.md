---
id: relationship_profiles.custom_type_metadata
type: fact
system: relationship_profiles
status: current
confidence: verified
severity: important

title: Relationship profiles store custom type metadata in JSONB

claim: >
  RelationshipProfile stores type-specific metadata in the profile_attributes
  JSONB column. The custom_type_label store_accessor is accepted by onboarding
  and the reusable relationship profile form, is retained only for the
  RelationshipProfiles::Other STI type, and replaces the generic Other label
  for display and relationship-profile search when present.

source_files:
  - db/migrate/20260706120000_add_profile_attributes_to_relationship_profiles.rb

related_files: []

symbols: []

routes: []

tags:
  - custom_type_metadata

verification:
  - bundle exec rspec spec/models/relationship_profile_spec.rb spec/requests/onboarding_spec.rb spec/queries/relationship_profile/search_query_spec.rb spec/requests/relationship_profiles_spec.rb

last_verified_commit: null
---

# Relationship profiles store custom type metadata in JSONB

## Claim

RelationshipProfile stores type-specific metadata in the `profile_attributes`
JSONB column. The `custom_type_label` `store_accessor` is accepted by
onboarding and the reusable relationship profile form, is retained only for the
`RelationshipProfiles::Other` STI type, and replaces the generic Other label for
display and relationship-profile search when present.

## Why It Matters

Custom relationship labels keep onboarding practical without introducing a
parallel relationship-type system or weakening the existing STI boundary.

## Evidence

- `app/models/relationship_profile.rb`
- `app/controllers/onboarding_controller.rb`
- `app/controllers/relationship_profiles_controller.rb`
- `app/views/onboarding/show.html.erb`
- `app/views/relationship_profiles/_form.html.erb`
- `db/migrate/20260706120000_add_profile_attributes_to_relationship_profiles.rb`
- `spec/models/relationship_profile_spec.rb`
- `spec/requests/onboarding_spec.rb`
- `spec/queries/relationship_profile/search_query_spec.rb`
- `spec/requests/relationship_profiles_spec.rb`

## Verification

- `bundle exec rspec spec/models/relationship_profile_spec.rb spec/requests/onboarding_spec.rb spec/queries/relationship_profile/search_query_spec.rb spec/requests/relationship_profiles_spec.rb`
