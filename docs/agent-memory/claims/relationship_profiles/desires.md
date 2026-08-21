---
id: relationship_profiles.desires
type: fact
system: relationship_profiles
status: current
confidence: high
severity: important

title: Desires are owner-scoped relationship memory

claim: >
  Desire records belong to a RelationshipProfile and are managed through
  authenticated, owner-scoped nested routes. Desires store a title, category,
  status, source, captured date, notes, suggestion contexts for downstream gift,
  date, birthday, plan, and gesture workflows, and fulfillment history through
  DesireFulfillment records. Captured dates default on validation, while the
  profile view renders localized fallback text if imported or legacy data leaves
  the date blank. Desire writes lock their relationship profile so gift
  recommendation source snapshots cannot race a concurrent source mutation.
  Manual create, edit, fulfill, and delete actions refresh the relationship
  profile desire section with Turbo streams when possible, preserve English and
  Spanish localized labels and validation copy, and cannot access another user's
  relationship profile.

source_files:
  - app/models/desire.rb
  - app/models/concerns/briefing_source_lock.rb
  - app/models/desire_fulfillment.rb
  - app/controllers/desires_controller.rb
  - app/policies/desire_policy.rb
  - app/views/desires/_desire.html.erb
  - app/views/desires/_form.html.erb
  - app/views/desires/_section.html.erb
  - db/migrate/20260707120000_create_desires.rb
  - db/migrate/20260707120100_create_desire_fulfillments.rb

related_files:
  - app/services/gift_recommendations/context_builder.rb
  - app/services/gift_recommendations/generate.rb
  - spec/models/desire_spec.rb
  - spec/requests/desires_spec.rb
  - spec/services/gift_recommendations/context_builder_spec.rb
  - spec/services/gift_recommendations/generate_spec.rb
symbols:
  - Desire
  - DesireFulfillment
  - BriefingSourceLock
  - DesiresController
  - DesirePolicy
  - RelationshipProfile#active_desires
  - RelationshipProfile#fulfilled_desires
routes:
  - relationship_profile_desires
  - relationship_profile_desire
  - new_relationship_profile_desire
  - edit_relationship_profile_desire
  - fulfill_relationship_profile_desire
tags:
  - desires
  - relationship_memory
  - fulfillment_history
  - source_locking

verification:
  - bundle exec rspec spec/models/desire_spec.rb spec/requests/desires_spec.rb
  - bundle exec rspec spec/services/gift_recommendations/context_builder_spec.rb spec/services/gift_recommendations/generate_spec.rb
  - bundle exec rspec spec/requests/relationship_profiles_spec.rb spec/models/relationship_profile_spec.rb spec/models/desire_spec.rb spec/requests/desires_spec.rb
  - bundle exec rspec
last_verified_commit: null
---

# Desires are owner-scoped relationship memory

## Claim

Desires are relationship-profile-owned records used to store wants, needs, and
future ideas with localized categories, status, source metadata, captured date,
notes, downstream suggestion contexts, and fulfillment history. Captured dates
default during validation, and the relationship profile view renders localized
fallback text if stored/imported data has no captured date. Manual
create/edit/fulfill/delete actions are owner-scoped through the signed-in user's
relationship profiles and update inline through Turbo streams where possible.
Desire saves and deletes take the relationship-profile source lock used by gift
recommendation generation, keeping the bounded source snapshot and its
fingerprint consistent with concurrent desire changes.

## Why It Matters

Desires can include sensitive relationship context and will feed future gift,
date, birthday, plan, and gesture suggestions. They must stay attached to the
existing owner-scoped relationship profile boundary so future automation does
not introduce a parallel memory store or leak private relationship details.
Serializing desire mutations with recommendation snapshot generation also keeps
the evidence attached to a result from becoming stale while it is generated.

## Evidence

- `app/models/desire.rb`
- `app/models/concerns/briefing_source_lock.rb`
- `app/models/desire_fulfillment.rb`
- `app/controllers/desires_controller.rb`
- `app/policies/desire_policy.rb`
- `app/views/desires/_section.html.erb`
- `app/views/desires/_desire.html.erb`
- `db/migrate/20260707120000_create_desires.rb`
- `db/migrate/20260707120100_create_desire_fulfillments.rb`
- `spec/models/desire_spec.rb`
- `spec/requests/desires_spec.rb`
- `spec/services/gift_recommendations/context_builder_spec.rb`
- `spec/services/gift_recommendations/generate_spec.rb`

## Verification

- `bundle exec rspec spec/models/desire_spec.rb spec/requests/desires_spec.rb`
- `bundle exec rspec spec/services/gift_recommendations/context_builder_spec.rb spec/services/gift_recommendations/generate_spec.rb`
- `bundle exec rspec spec/requests/relationship_profiles_spec.rb spec/models/relationship_profile_spec.rb spec/models/desire_spec.rb spec/requests/desires_spec.rb`
- `bundle exec rspec`
