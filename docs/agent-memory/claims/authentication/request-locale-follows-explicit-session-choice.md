---
id: authentication.request_locale_follows_explicit_session_choice
type: fact
system: authentication
status: current
confidence: high
severity: normal

title: Request locale follows explicit session choice

claim: >
  An allowlisted explicit request locale updates the session before authentication. Requests without a locale keep the valid session choice; malformed explicit values reset to English. Spanish generated paths and Devise failure redirects preserve locale, and the shared language switch copies only supported navigation/filter parameters.

source_files:
  - app/controllers/application_controller.rb
  - app/helpers/workspace_helper.rb
  - lib/localized_failure_app.rb
  - config/initializers/devise.rb

related_files:
  - app/views/layouts/application.html.erb
  - app/views/components/app_navigation_component.html.erb
  - config/locales/workspace.en.yml
  - config/locales/workspace.es.yml
  - spec/requests/app_workspace_spec.rb
  - spec/system/workspace_experience_spec.rb

symbols:
  - ApplicationController#with_request_locale
  - ApplicationController#default_url_options
  - WorkspaceHelper#workspace_locale_path
  - LocalizedFailureApp#scope_url

routes: []

tags:
  - authentication
  - workspace
  - localization

verification:
  - bundle exec rspec spec/requests/app_workspace_spec.rb spec/system/workspace_experience_spec.rb

last_verified_commit: null
---

# Request locale follows explicit session choice

## Claim

An allowlisted explicit request locale updates the session before authentication. Requests without a locale keep the valid session choice; malformed explicit values reset to English. Spanish generated paths and Devise failure redirects preserve locale, and the shared language switch copies only supported navigation/filter parameters.

## Why It Matters

Translation availability alone does not make a Spanish journey work. Authentication, generated links and subsequent requests must preserve the selected language without echoing unrelated query data.

## Verification

- `bundle exec rspec spec/requests/app_workspace_spec.rb spec/system/workspace_experience_spec.rb`

Local changes are validated before commit; no committed revision is claimed as verified.
