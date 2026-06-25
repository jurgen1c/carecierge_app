---
id: feature_flags.localization_baseline
type: constraint
system: feature_flags
status: current
confidence: verified
severity: important

title: Feature flag user-facing copy keeps English and Spanish locales

claim: >
  User-facing feature flag copy must keep English as the default locale while preserving Spanish
  translations for admin registry and flag-related interface text.

source_files:
  - app/views/admin/feature_flags/index.html.erb
  - config/locales/en.yml
  - config/locales/es.yml

related_files:
  - spec/requests/admin_feature_flags_spec.rb
symbols: []
routes:
  - admin_feature_flags
tags:
  - feature_flags
  - localization

verification:
  - bundle exec rspec spec/requests/admin_feature_flags_spec.rb
last_verified_commit: 59c16d37d66419852ab109e5f68ef29f0a746e53
---

# Feature flag user-facing copy keeps English and Spanish locales

## Claim

User-facing feature flag copy must keep English as the default locale while preserving Spanish
translations for admin registry and flag-related interface text.

## Why It Matters

Admin-facing feature flag changes can introduce copy without matching localization coverage.

## Evidence

- `app/views/admin/feature_flags/index.html.erb`
- `config/locales/en.yml`
- `config/locales/es.yml`

## Verification

- `bundle exec rspec spec/requests/admin_feature_flags_spec.rb`
