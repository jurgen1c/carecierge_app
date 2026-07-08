---
id: relationship_profiles.gift_history
type: fact
system: relationship_profiles
status: current
confidence: verified
severity: important

title: Gift history is owner-scoped relationship memory

claim: >
  Gift records belong to a RelationshipProfile and are managed through
  authenticated, owner-scoped nested routes. Gifts store ideas and given gifts
  with name, status, occasion, price, vendor, given date, reaction, outcome, and
  notes. Manual create, edit, mark-given, and delete actions refresh the
  relationship profile gift-history section with Turbo streams when possible,
  preserve English and Spanish localized labels and validation copy, protect
  terminal given/outcome metadata from generic form forging, surface duplicate
  candidates from prior same-profile gifts with an index aligned to the
  normalized-name lookup and a loaded-association duplicate-name cache, require
  a given date on given gifts, order gift history by newest given date with
  names ascending for same-day ties, and cannot access another user's
  relationship profile.

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

Gifts are relationship-profile-owned records used to store gift ideas and gifts
given with occasion, price, vendor, reaction, outcome, and notes. Manual
create/edit/mark-given/delete actions are owner-scoped through the signed-in
user's relationship profiles and update inline through Turbo streams where
possible. Generic create and edit params cannot forge terminal given status,
given dates, reactions, or outcomes; explicit mark-given behavior owns those
metadata changes. Given gifts must have a given date so malformed mark-given
input cannot persist a gift as given without history ordering metadata.
Same-profile prior gifts with the same normalized name are surfaced as duplicate
candidates so future gift recommendations can avoid repeating what already
happened. The gifts table indexes relationship profile plus lowercased name to
match the duplicate-candidate lookup. When relationship profile gifts are
already loaded, duplicate detection reuses a normalized-name cache on the
profile instead of scanning the full collection for every gift card. Gift
history sorts newest given gifts first while keeping same-day gifts in ascending
name order.

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

## Verification

- `bundle exec rspec spec/models/gift_spec.rb spec/requests/gifts_spec.rb`
- `bundle exec rspec spec/requests/relationship_profiles_spec.rb spec/models/relationship_profile_spec.rb spec/models/gift_spec.rb spec/requests/gifts_spec.rb`
- `bundle exec rspec`
