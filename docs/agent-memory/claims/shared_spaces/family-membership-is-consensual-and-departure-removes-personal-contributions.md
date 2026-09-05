---
id: shared_spaces.family_membership_is_consensual_and_departure_removes_personal_contributions
type: fact
system: shared_spaces
status: current
confidence: high
severity: critical

title: Family membership is consensual and departure removes personal contributions

claim: >
  Family spaces extend shared planning through owner-managed, expiring in-app invitations with confirmed-recipient acceptance and descriptive family relationship types. Accepted members see deliberately shared items and RSVP responses, never private profiles or pending invitation addresses. Only the organizer ends the group; members can leave. Removal serializes under the space lock, deletes the departing person’s contributions, responses and reminder subscriptions/alerts, and releases responsibilities while preserving other content. Account deletion follows the same lifecycle. Self-selected reminders recheck current membership at delivery; category starters never access private context or act automatically.

source_files:
  - app/models/family_membership.rb
  - app/models/family_response.rb
  - app/models/shared_relationship_space.rb
  - app/models/user.rb
  - app/controllers/family_memberships_controller.rb
  - app/controllers/shared_relationship_spaces_controller.rb
  - app/serializers/data_exports/snapshot.rb
  - app/views/shared_relationship_spaces/_family_roster.html.erb
  - app/views/shared_relationship_spaces/_family_coordination.html.erb
  - config/locales/family_spaces.en.yml
  - config/locales/family_spaces.es.yml
  - db/migrate/20260905200615_add_family_coordination.rb
  - spec/models/family_membership_spec.rb
  - spec/requests/family_spaces_spec.rb
  - spec/system/family_spaces_spec.rb

related_files:
  - docs/features/14-02-family-mode.md
  - config/initializers/filter_parameter_logging.rb
  - config/routes.rb
symbols: []
routes:
  - /shared_relationship_spaces
  - /family_memberships/:id/accept
tags:
  - shared_spaces

verification:
  - bundle exec rspec spec/requests/family_spaces_spec.rb spec/models/family_membership_spec.rb spec/system/family_spaces_spec.rb spec/jobs/dispatch_shared_reminders_job_spec.rb

last_verified_commit: null
---

# Family membership is consensual and departure removes personal contributions

## Claim

Family spaces extend shared planning through owner-managed, expiring in-app invitations with confirmed-recipient acceptance and descriptive family relationship types. Accepted members see deliberately shared items and RSVP responses, never private profiles or pending invitation addresses. Only the organizer ends the group; members can leave. Removal serializes under the space lock, deletes the departing person’s contributions, responses and reminder subscriptions/alerts, and releases responsibilities while preserving other content. Account deletion follows the same lifecycle. Self-selected reminders recheck current membership at delivery; category starters never access private context or act automatically.

## Why It Matters

Family participation must remain voluntary and must not expose private relationship context or retain access after withdrawal.

## Evidence

- `app/models/family_membership.rb
  - app/models/family_response.rb
  - app/models/shared_relationship_space.rb
  - app/models/user.rb
  - app/controllers/family_memberships_controller.rb
  - app/controllers/shared_relationship_spaces_controller.rb
  - app/serializers/data_exports/snapshot.rb
  - app/views/shared_relationship_spaces/_family_roster.html.erb
  - app/views/shared_relationship_spaces/_family_coordination.html.erb
  - config/locales/family_spaces.en.yml
  - config/locales/family_spaces.es.yml
  - db/migrate/20260905200615_add_family_coordination.rb
  - spec/models/family_membership_spec.rb
  - spec/requests/family_spaces_spec.rb
  - spec/system/family_spaces_spec.rb`

## Verification

- bundle exec rspec spec/requests/family_spaces_spec.rb spec/models/family_membership_spec.rb spec/system/family_spaces_spec.rb spec/jobs/dispatch_shared_reminders_job_spec.rb
