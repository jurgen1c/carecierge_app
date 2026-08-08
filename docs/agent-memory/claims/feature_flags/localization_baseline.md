---
id: feature_flags.localization_baseline
type: constraint
system: feature_flags
status: current
confidence: high
severity: important

title: Feature flag user-facing copy keeps English and Spanish locales

claim: >
  User-facing feature flag copy must keep English as the default locale while preserving Spanish
  translations with standard diacritics for admin registry and flag-related interface text.

source_files:
  - app/views/admin/feature_flags/index.html.erb
  - config/locales/en.yml
  - config/locales/es.yml

related_files:
  - spec/requests/admin_feature_flags_spec.rb
symbols: []
routes: []
tags:
  - feature_flag_localization

verification:
  - bundle exec rspec spec/requests/admin_feature_flags_spec.rb
  - bundle exec rspec spec/requests/relationship_personas_spec.rb
last_verified_commit: null
---

# Feature flag user-facing copy keeps English and Spanish locales

## Claim

User-facing feature flag copy must keep English as the default locale while preserving Spanish
translations with standard diacritics for admin registry and flag-related interface text.

## Why It Matters

Admin-facing feature flag changes can introduce copy without matching localization coverage.

## Review Notes

CAR-25 reviewed this claim while adding onboarding important-date copy to English and Spanish
locales. Feature flag copy and localization behavior remain unchanged.
CAR-44 reviewed this shared locale boundary while adding English and Spanish
relationship-persona copy. Feature flag copy, the English default, and Spanish
availability remain unchanged.

## Evidence

- `app/views/admin/feature_flags/index.html.erb`
- `config/locales/en.yml`
- `config/locales/es.yml`

## Verification

- `bundle exec rspec spec/requests/admin_feature_flags_spec.rb`
- `bundle exec rspec spec/requests/relationship_personas_spec.rb`
