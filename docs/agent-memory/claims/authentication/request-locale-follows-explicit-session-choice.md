---
id: authentication.request_locale_follows_explicit_session_choice
type: fact
system: authentication
status: current
confidence: high
severity: normal

title: Request locale follows explicit session choice

claim: >
  An allowlisted explicit request locale updates the session before authentication. Language links disable Turbo prefetch, and speculative Turbo requests do not change the saved locale. Requests without a locale keep the valid session choice; malformed explicit values reset to English. Spanish generated paths and Devise failure redirects preserve locale, and the shared language switch copies only supported navigation/filter parameters, including source IDs, marketplace/vendor selections, reminder milestone/time-zone context and the selected approval ID; unrelated query data is excluded. Validation-response fallback links start from a query-free dashboard path. Calendar, Contacts and Messaging OAuth authorization and token exchange use locale-neutral registered callback URLs while the session retains the chosen UI language.

source_files:
  - app/controllers/application_controller.rb
  - app/helpers/workspace_helper.rb
  - lib/localized_failure_app.rb
  - config/initializers/devise.rb
  - app/controllers/calendar_connections_controller.rb
  - app/controllers/contacts_connections_controller.rb
  - app/controllers/messaging_connections_controller.rb

related_files:
  - app/views/layouts/application.html.erb
  - app/views/components/app_navigation_component.html.erb
  - config/locales/workspace.en.yml
  - config/locales/workspace.es.yml
  - spec/requests/app_workspace_spec.rb
  - spec/requests/calendar_connections_spec.rb
  - spec/requests/contacts_connections_spec.rb
  - spec/requests/messaging_connections_spec.rb
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
  - bundle exec rspec spec/requests/app_workspace_spec.rb spec/requests/calendar_connections_spec.rb spec/requests/contacts_connections_spec.rb spec/requests/messaging_connections_spec.rb spec/system/workspace_experience_spec.rb

last_verified_commit: 2d93680db18b6ed38fedaca363b27416b90346f3
---

# Request locale follows explicit session choice

## Claim

An allowlisted explicit request locale updates the session before authentication. Language links disable Turbo prefetch, and speculative Turbo requests do not change the saved locale. Requests without a locale keep the valid session choice; malformed explicit values reset to English. Spanish generated paths and Devise failure redirects preserve locale, and the shared language switch copies only supported navigation/filter parameters, including source IDs, marketplace/vendor selections, reminder milestone/time-zone context and the selected approval ID; unrelated query data is excluded. Validation-response fallback links start from a query-free dashboard path. Calendar, Contacts and Messaging OAuth authorization and token exchange use locale-neutral registered callback URLs while the session retains the chosen UI language.

## Why It Matters

Translation availability alone does not make a Spanish journey work. Authentication, generated links and subsequent requests must preserve the selected language without echoing unrelated query data.

## Verification

- `bundle exec rspec spec/requests/app_workspace_spec.rb spec/requests/calendar_connections_spec.rb spec/requests/contacts_connections_spec.rb spec/requests/messaging_connections_spec.rb spec/system/workspace_experience_spec.rb`
