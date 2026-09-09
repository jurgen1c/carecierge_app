---
id: authentication.user_access_flow
type: workflow
system: authentication
status: current
confidence: high
severity: normal

title: User access flow redirects through welcome, onboarding, and the concierge

claim: >
  Visitors start at welcome#index, Devise registration creates a confirmable User, successful
  login redirects users with pending onboarding to onboarding#show before concierge_conversations#index, users
  can skip onboarding and return from the shared navigation until completion, onboarding completion
  creates the first owner-scoped relationship profile, and users with existing relationship
  profiles are treated as completed onboarding so established accounts continue to concierge_conversations#index.
  Skipped users are not pending and short-circuit that check before relationship profile lookup.
  Completed users cannot be marked skipped, and completing onboarding clears prior skipped state.
  Logout redirects to welcome#index, and invalid access attempts keep localized recovery paths
  available. Authenticated application access is enforced from ApplicationController, with
  welcome#index explicitly opted out and Devise controllers left public for sign-in and registration.

source_files:
  - app/controllers/concierge_conversations_controller.rb
  - app/views/concierge_conversations/index.html.erb
  - app/views/layouts/application.html.erb
  - app/views/components/app_navigation_component.rb
  - app/controllers/application_controller.rb
  - app/controllers/dashboard_controller.rb
  - app/controllers/onboarding_controller.rb
  - app/controllers/welcome_controller.rb
  - app/models/user.rb
  - app/views/onboarding/show.html.erb
  - app/views/devise/registrations/new.html.erb
  - app/views/devise/sessions/new.html.erb
  - config/routes.rb

related_files:
  - db/migrate/20260705160000_add_onboarding_state_to_users.rb
  - db/data/20260705160100_backfill_user_onboarding_completed_at.rb
  - spec/requests/onboarding_spec.rb
  - spec/models/user_spec.rb
  - spec/system/user_access_flow_spec.rb
symbols:
  - DashboardController
  - OnboardingController
  - WelcomeController
routes:
  - root
  - onboarding
  - skip_onboarding
  - dashboard
  - new_user_registration
  - new_user_session
tags:
  - authentication
  - user-access-flow

verification:
  - bundle exec rspec spec/requests/concierge_spec.rb spec/system/concierge_spec.rb
  - bundle exec rspec spec/requests/onboarding_spec.rb spec/system/user_access_flow_spec.rb spec/requests/localization_spec.rb
  - bundle exec rspec spec/requests/authentication_gate_spec.rb
last_verified_commit: cc0ce9edfa8a02156d651f817eea75d9f8ec4a7f
---

# User access flow redirects through welcome, onboarding, and the concierge

## Claim

Visitors start at `welcome#index`, Devise registration creates a confirmable `User`, successful
login redirects users with pending onboarding to `onboarding#show` before `concierge_conversations#index`, users
can skip onboarding and return from the shared navigation until completion, onboarding completion
creates the first owner-scoped relationship profile, and users with existing relationship
profiles are treated as completed onboarding so established accounts continue to `concierge_conversations#index`.
Skipped users are not pending and short-circuit that check before relationship profile lookup.
Completed users cannot be marked skipped, and completing onboarding clears prior skipped state.
Logout redirects to `welcome#index`, and invalid access attempts keep localized recovery paths
available. Authenticated application access is enforced from `ApplicationController`, with
`welcome#index` explicitly opted out and Devise controllers left public for sign-in and
registration.

## Why It Matters

This preserves the expected post-authentication landing behavior and recoverable failure modes
when changing routes, controllers, or Devise views.

## Review Notes

The concierge is the normal authenticated landing. Onboarding completion selects the newly created person in chat. Valid same-origin stored destinations still take precedence after access requirements, and Today, People, plans, and shared spaces remain in the shared navigation.

Stored concierge transcript polling destinations are normalized to the conversation HTML route after sign-in, preserving the active locale. Session expiry during polling therefore restores the complete workspace instead of returning a Turbo Stream to the sign-in screen. Verify with bundle exec rspec spec/requests/concierge_spec.rb spec/requests/app_workspace_spec.rb.

## Evidence

- `app/controllers/application_controller.rb`
- `app/controllers/dashboard_controller.rb`
- `app/controllers/onboarding_controller.rb`
- `app/models/user.rb`
- `app/controllers/welcome_controller.rb`
- `app/views/onboarding/show.html.erb`
- `app/views/devise/registrations/new.html.erb`
- `app/views/devise/sessions/new.html.erb`
- `config/routes.rb`
- `db/migrate/20260705160000_add_onboarding_state_to_users.rb`
- `db/data/20260705160100_backfill_user_onboarding_completed_at.rb`

## Verification

- `bundle exec rspec spec/requests/onboarding_spec.rb spec/system/user_access_flow_spec.rb spec/requests/localization_spec.rb`
- `bundle exec rspec spec/models/user_spec.rb`
- `bundle exec rspec spec/requests/authentication_gate_spec.rb`
