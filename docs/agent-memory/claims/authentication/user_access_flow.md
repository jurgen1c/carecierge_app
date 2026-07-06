---
id: authentication.user_access_flow
type: workflow
system: authentication
status: current
confidence: high
severity: normal

title: User access flow redirects through welcome, onboarding, and dashboard surfaces

claim: >
  Visitors start at welcome#index, Devise registration creates a confirmable User, successful
  login redirects users with pending onboarding to onboarding#show before dashboard#index, users
  can skip onboarding and return from dashboard#index until completion, onboarding completion
  creates the first owner-scoped relationship profile, and users with existing relationship
  profiles are treated as completed onboarding so established accounts continue to dashboard#index.
  Logout redirects to welcome#index, and invalid access attempts keep localized recovery paths
  available. Authenticated application access is enforced from ApplicationController, with
  welcome#index explicitly opted out and Devise controllers left public for sign-in and registration.

source_files:
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
  - bundle exec rspec spec/requests/onboarding_spec.rb spec/system/user_access_flow_spec.rb spec/requests/localization_spec.rb
  - bundle exec rspec spec/requests/authentication_gate_spec.rb
last_verified_commit: null
---

# User access flow redirects through welcome, onboarding, and dashboard surfaces

## Claim

Visitors start at `welcome#index`, Devise registration creates a confirmable `User`, successful
login redirects users with pending onboarding to `onboarding#show` before `dashboard#index`, users
can skip onboarding and return from `dashboard#index` until completion, onboarding completion
creates the first owner-scoped relationship profile, and users with existing relationship
profiles are treated as completed onboarding so established accounts continue to `dashboard#index`.
Logout redirects to `welcome#index`, and invalid access attempts keep localized recovery paths
available. Authenticated application access is enforced from `ApplicationController`, with
`welcome#index` explicitly opted out and Devise controllers left public for sign-in and
registration.

## Why It Matters

This preserves the expected post-authentication landing behavior and recoverable failure modes
when changing routes, controllers, or Devise views.

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
- `bundle exec rspec spec/requests/authentication_gate_spec.rb`
