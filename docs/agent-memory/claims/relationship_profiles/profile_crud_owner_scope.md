---
id: relationship_profiles.profile_crud_owner_scope
type: fact
system: relationship_profiles
status: current
confidence: verified
severity: important

title: Relationship profile CRUD is owner scoped

claim: >
  Relationship profiles are authenticated, user-owned records for core details,
  contact methods, notes, structured preferences, private notes, tags, and archive
  status; RelationshipProfilePolicy and policy scopes restrict CRUD, archive,
  search, and filter access to the signed-in owner.

source_files:
  - app/models/user.rb
  - app/models/relationship_profile.rb
  - app/models/relationship_type.rb
  - app/models/contact_method.rb
  - app/models/relationship_note.rb
  - app/models/relationship_tag.rb
  - app/controllers/relationship_profiles_controller.rb
  - app/policies/relationship_profile_policy.rb
  - config/routes.rb
  - db/migrate/20260625121000_add_relationship_profile_integrity_constraints.rb

related_files:
  - app/views/relationship_profiles/index.html.erb
  - app/views/relationship_profiles/_form.html.erb
  - app/views/relationship_profiles/show.html.erb
  - config/locales/en.yml
  - config/locales/es.yml
symbols:
  - User
  - RelationshipProfile
  - RelationshipType
  - ContactMethod
  - RelationshipNote
  - RelationshipTag
  - RelationshipProfilesController
  - RelationshipProfilePolicy
routes:
  - relationship_profiles
  - relationship_profile
  - archive_relationship_profile
tags:
  - relationship_profiles
  - pundit
  - ransack
  - privacy

verification:
  - bundle exec rspec spec/requests/relationship_profiles_spec.rb
  - bundle exec rspec spec/models/contact_method_spec.rb spec/models/relationship_profile_spec.rb
  - bundle exec rspec
last_verified_commit: null
---

# Relationship profile CRUD is owner scoped

## Claim

Relationship profiles are authenticated, user-owned records for core details,
contact methods, notes, structured preferences, private notes, tags, and archive
status; RelationshipProfilePolicy and policy scopes restrict CRUD, archive,
search, and filter access to the signed-in owner.

## Why It Matters

Relationship data is sensitive and foundational to Carecierge. Future reminders,
automation, and sharing work should reference profiles through the owner-scoped
relationship profile boundary rather than introducing parallel personal-context
stores.

## Evidence

- `app/models/relationship_profile.rb`
- `app/models/user.rb`
- `app/controllers/relationship_profiles_controller.rb`
- `app/policies/relationship_profile_policy.rb`
- `app/views/relationship_profiles/show.html.erb`
- `config/routes.rb`
- `db/migrate/20260625121000_add_relationship_profile_integrity_constraints.rb`

## Verification

- `bundle exec rspec spec/models/contact_method_spec.rb spec/models/relationship_profile_spec.rb`
- `bundle exec rspec spec/requests/relationship_profiles_spec.rb`
- `bundle exec rspec`
