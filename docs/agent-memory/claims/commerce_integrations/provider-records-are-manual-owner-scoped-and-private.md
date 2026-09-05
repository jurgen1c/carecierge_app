---
id: commerce_integrations.provider_records_are_manual_owner_scoped_and_private
type: constraint
system: commerce_integrations
status: current
confidence: verified
severity: critical
title: Provider records are manual owner scoped and private
claim: >
  ExternalProviderAction records are explicit owner-authored observations of commerce,
  booking, vendor and reservation provider state, never live connections or executable
  provider commands. Recording a purchase, booking, quote or logistics status cannot
  mutate linked plans, confirm bookings, contact providers, buy or pay. Provider name,
  source, URL, reference and failure details are encrypted and parameter-filtered.
  Pundit scopes every web action to the owner; typed UUID links to gift purchase plans,
  event plans, bookings, vendor quotes and directly relationship-linked reminders must
  belong to that same owner and relationship, with consistent event context. Saves
  require an active relationship and serialize with account/profile locks and optimistic
  edit versions. Every explicit create/update/delete is atomic with privacy-minimized
  relationship audit evidence; local cleanup remains available after archival. Owner
  exports include decrypted records. Context, relationship and account deletion cascade
  records. No credentials, provider adapters, background sync or delegated action endpoint
  exists; future live integrations require separate consent and permission enforcement.
source_files:
  - app/models/external_provider_action.rb
  - app/controllers/external_provider_actions_controller.rb
  - app/policies/external_provider_action_policy.rb
  - app/services/external_provider_actions/save.rb
  - app/services/external_provider_actions/destroy.rb
  - app/serializers/data_exports/snapshot.rb
  - config/initializers/filter_parameter_logging.rb
  - db/migrate/20260905135433_create_external_provider_actions.rb
related_files:
  - app/views/relationship_profiles/show.html.erb
  - db/schema.rb
  - app/models/user.rb
  - app/models/relationship_profile.rb
  - app/models/event_plan.rb
  - app/models/booking.rb
  - app/models/gift_purchase_plan.rb
  - app/models/reminder.rb
  - app/models/vendor_quote.rb
  - app/models/audit_event.rb
  - config/routes.rb
  - app/helpers/external_provider_actions_helper.rb
  - app/views/components/external_provider_action_component.rb
  - app/views/components/external_provider_action_component.html.erb
  - app/views/external_provider_actions/index.html.erb
  - app/views/external_provider_actions/_form.html.erb
  - app/views/external_provider_actions/new.html.erb
  - app/views/external_provider_actions/edit.html.erb
  - config/locales/external_provider_actions.en.yml
  - config/locales/external_provider_actions.es.yml
  - spec/models/external_provider_action_spec.rb
  - spec/requests/external_provider_actions_spec.rb
  - spec/system/external_provider_actions_spec.rb
symbols:
  - ExternalProviderAction
  - ExternalProviderActions::Save.call
  - ExternalProviderActions::Destroy.call
routes:
  - GET /relationship_profiles/:relationship_profile_id/external_provider_actions
  - POST /relationship_profiles/:relationship_profile_id/external_provider_actions
  - PATCH /external_provider_actions/:id
  - DELETE /external_provider_actions/:id
tags: [commerce_integrations, privacy, ownership, manual, provider, booking]
verification:
  - bundle exec rspec
  - bundle exec rspec spec/models/external_provider_action_spec.rb spec/requests/external_provider_actions_spec.rb
  - bin/memory validate
last_verified_commit: 2be8a13a9cb8fc20726f1e7a42890614638a3da1
---

# Provider records are manual owner scoped and private

Saving a provider record updates local evidence only. Its reported status is distinct
from the linked purchase, booking, quote, event or reminder status. Do not infer live
provider access, delegated permission or approval from a manually entered confirmation.
