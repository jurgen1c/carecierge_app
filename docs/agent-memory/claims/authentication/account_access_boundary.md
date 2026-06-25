---
id: authentication.account_access_boundary
type: fact
system: authentication
status: current
confidence: verified
severity: important

title: Authentication owns account access and session lifecycle

claim: >
  The authentication system owns Carecierge account access through Devise-backed registration,
  email confirmation, login, logout, lockout, rememberable sessions, password recovery, and
  Google OAuth account creation.

source_files:
  - app/models/user.rb
  - app/controllers/users/omniauth_callbacks_controller.rb
  - config/initializers/devise.rb
  - config/routes.rb

related_files: []
symbols:
  - User
  - Users::OmniauthCallbacksController
routes:
  - new_user_registration
  - new_user_session
tags:
  - authentication
  - devise

verification:
  - bundle exec rspec spec/models/user_spec.rb spec/controllers/users/omniauth_callbacks_controller_spec.rb spec/system/user_access_flow_spec.rb
last_verified_commit: 59c16d37d66419852ab109e5f68ef29f0a746e53
---

# Authentication owns account access and session lifecycle

## Claim

The authentication system owns Carecierge account access through Devise-backed registration,
email confirmation, login, logout, lockout, rememberable sessions, password recovery, and
Google OAuth account creation.

## Why It Matters

Changes to account access should route through the authentication boundary rather than being
spread across unrelated systems.

## Evidence

- `app/models/user.rb`
- `app/controllers/users/omniauth_callbacks_controller.rb`
- `config/initializers/devise.rb`
- `config/routes.rb`

## Verification

- `bundle exec rspec spec/models/user_spec.rb spec/controllers/users/omniauth_callbacks_controller_spec.rb spec/system/user_access_flow_spec.rb`
