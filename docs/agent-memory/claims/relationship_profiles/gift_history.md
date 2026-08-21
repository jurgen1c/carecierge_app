---
id: relationship_profiles.gift_history
type: fact
system: relationship_profiles
status: current
confidence: high
severity: important

title: Gift history is owner-scoped relationship memory

claim: >
  Gift records belong to an owner-scoped RelationshipProfile and store ideas or
  given gifts with occasion, price, vendor, reaction, outcome, and notes.
  Localized nested CRUD refreshes gift history through Turbo, protects terminal
  result metadata from generic form forging, and requires a date for given
  gifts. Same-profile normalized-name candidates use an aligned expression
  index and loaded-association cache. History orders newest given dates first
  with deterministic name ties. Gift mutations share the profile source lock
  used by recommendation generation, and accepted recommendations become
  ordinary idea or planned Gift records.

source_files:
  - app/models/gift.rb
  - app/controllers/gifts_controller.rb
  - app/policies/gift_policy.rb
  - app/views/gifts/_gift.html.erb
  - app/views/gifts/_form.html.erb
  - app/views/gifts/_section.html.erb
  - db/migrate/20260707123000_create_gifts.rb

related_files:
  - spec/models/gift_spec.rb
  - spec/requests/gifts_spec.rb
  - app/services/gift_recommendations/apply_action.rb
  - spec/requests/gift_recommendations_spec.rb
symbols:
  - Gift
  - GiftsController
  - GiftPolicy
  - RelationshipProfile#gift_ideas
  - RelationshipProfile#gift_history
routes:
  - relationship_profile_gifts
  - relationship_profile_gift
  - new_relationship_profile_gift
  - edit_relationship_profile_gift
  - mark_given_relationship_profile_gift
tags:
  - gifts
  - gift_history
  - recommendation_history

verification:
  - bundle exec rspec spec/models/gift_spec.rb spec/requests/gifts_spec.rb
  - bundle exec rspec spec/requests/relationship_profiles_spec.rb spec/models/relationship_profile_spec.rb spec/models/gift_spec.rb spec/requests/gifts_spec.rb
  - bundle exec rspec
last_verified_commit: null
---

# Gift history is owner-scoped relationship memory

## Claim

Gifts are relationship-profile-owned ideas or history records with occasion,
price, vendor, reaction, outcome, and notes. Owner-scoped nested CRUD updates
the profile inline. Generic params cannot forge terminal result metadata, and a
given gift requires its date. Duplicate detection uses the profile/lower-name
index and a loaded-association cache; history ordering is deterministic.

Gift writes acquire the profile source lock so recommendation generation cannot
persist against outdated history. Saving or marking a recommendation purchased
creates an ordinary idea or planned Gift rather than a parallel accepted-item
store.

## Why It Matters

Gift history includes sensitive relationship context and will feed future
recommendations for birthdays, anniversaries, holidays, and professional
gifting. It must stay attached to the existing owner-scoped relationship profile
boundary so recommendation logic can use prior outcomes without leaking private
relationship details or treating gift data as a separate tenant boundary.

## Evidence

- `app/models/gift.rb`
- `app/controllers/gifts_controller.rb`
- `app/policies/gift_policy.rb`
- `app/views/gifts/_section.html.erb`
- `app/views/gifts/_gift.html.erb`
- `db/migrate/20260707123000_create_gifts.rb`
- `spec/models/gift_spec.rb`
- `spec/requests/gifts_spec.rb`
- `app/services/gift_recommendations/apply_action.rb`
- `spec/requests/gift_recommendations_spec.rb`

## Verification

- `bundle exec rspec spec/models/gift_spec.rb spec/requests/gifts_spec.rb`
- `bundle exec rspec spec/requests/relationship_profiles_spec.rb spec/models/relationship_profile_spec.rb spec/models/gift_spec.rb spec/requests/gifts_spec.rb`
- `bundle exec rspec`
