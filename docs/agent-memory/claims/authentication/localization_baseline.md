---
id: authentication.localization_baseline
type: constraint
system: authentication
status: current
confidence: verified
severity: important

title: Authentication keeps English default and Spanish available

claim: >
  Authentication-facing copy and flows must keep English as the default locale while preserving
  Spanish as an available locale for localized registration, login, and access-error behavior.

source_files:
  - config/routes.rb
  - app/views/devise/registrations/new.html.erb
  - app/views/devise/sessions/new.html.erb

related_files:
  - spec/requests/localization_spec.rb
symbols: []
routes:
  - new_user_registration
  - new_user_session
tags:
  - authentication
  - localization

verification:
  - bundle exec rspec spec/requests/localization_spec.rb
last_verified_commit: 59c16d37d66419852ab109e5f68ef29f0a746e53
---

# Authentication keeps English default and Spanish available

## Claim

Authentication-facing copy and flows must keep English as the default locale while preserving
Spanish as an available locale for localized registration, login, and access-error behavior.

## Why It Matters

Locale regressions violate the repository baseline and are easy to introduce while editing
authentication views or routing behavior.

## Evidence

- `config/routes.rb`
- `app/views/devise/registrations/new.html.erb`
- `app/views/devise/sessions/new.html.erb`

## Verification

- `bundle exec rspec spec/requests/localization_spec.rb`
