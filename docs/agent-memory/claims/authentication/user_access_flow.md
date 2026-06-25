---
id: authentication.user_access_flow
type: workflow
system: authentication
status: current
confidence: verified
severity: normal

title: User access flow redirects through welcome and dashboard surfaces

claim: >
  Visitors start at welcome#index, Devise registration creates a confirmable User, successful
  login redirects to dashboard#index, logout redirects to welcome#index, and invalid access
  attempts keep localized recovery paths available.

source_files:
  - app/controllers/application_controller.rb
  - app/controllers/dashboard_controller.rb
  - app/controllers/welcome_controller.rb
  - app/views/devise/registrations/new.html.erb
  - app/views/devise/sessions/new.html.erb
  - config/routes.rb

related_files:
  - spec/system/user_access_flow_spec.rb
  - spec/requests/localization_spec.rb
symbols:
  - DashboardController
  - WelcomeController
routes:
  - root
  - dashboard
  - new_user_registration
  - new_user_session
tags:
  - authentication
  - user-access-flow

verification:
  - bundle exec rspec spec/system/user_access_flow_spec.rb spec/requests/localization_spec.rb
last_verified_commit: 59c16d37d66419852ab109e5f68ef29f0a746e53
---

# User access flow redirects through welcome and dashboard surfaces

## Claim

Visitors start at `welcome#index`, Devise registration creates a confirmable `User`, successful
login redirects to `dashboard#index`, logout redirects to `welcome#index`, and invalid access
attempts keep localized recovery paths available.

## Why It Matters

This preserves the expected post-authentication landing behavior and recoverable failure modes
when changing routes, controllers, or Devise views.

## Evidence

- `app/controllers/application_controller.rb`
- `app/controllers/dashboard_controller.rb`
- `app/controllers/welcome_controller.rb`
- `app/views/devise/registrations/new.html.erb`
- `app/views/devise/sessions/new.html.erb`
- `config/routes.rb`

## Verification

- `bundle exec rspec spec/system/user_access_flow_spec.rb spec/requests/localization_spec.rb`
