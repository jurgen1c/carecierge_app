---
id: authentication.production_seeds_provision_the_initial_account_without_replacing_credentials
type: fact
system: authentication
status: current
confidence: verified
severity: important
title: Production seeds provision the initial account without replacing credentials
claim: >
  db:seed loads db/seeds/production.rb in production after baseline data. The production
  file finds the initial account case-insensitively by its explicitly configured seed
  email and creates it only when missing.
  Creation requires PRODUCTION_SEED_PASSWORD and normal User validations, retains the
  regular-user and unconfirmed defaults, and suppresses the confirmation email.
  Existing accounts keep their password, role, confirmation and security state; reruns
  do not require the password environment variable. Development demo accounts are never
  loaded in production because the common entry point loads only the current Rails
  environment seed file.
source_files:
  - db/seeds.rb
  - db/seeds/production.rb
  - README.md
related_files:
  - app/models/user.rb
  - config/initializers/devise.rb
  - spec/db/seeds_spec.rb
symbols:
  - User
routes: []
tags:
  - authentication
  - seeds
  - production
verification:
  - bundle exec rspec spec/db/seeds_spec.rb
  - bin/ci
last_verified_commit: 7559337422b419fae6e64d414310574d502c8a70
---

# Production seeds provision the initial account without replacing credentials

The production account is separate from deterministic synthetic development users.
The password is an environment input for initial creation, never a committed default.
Email confirmation is requested through the existing Devise flow after provisioning.
Reruns must not reset existing credentials or change authority.
