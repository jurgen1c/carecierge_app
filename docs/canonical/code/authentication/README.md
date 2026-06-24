# Authentication

Last updated: "2026-06-24"
Status: implemented

## Purpose

Authentication owns Carecierge account access: email/password registration, email confirmation, login, logout, lockout, rememberable sessions, password recovery, and Google OAuth account creation.

## Behavior

- Visitors start at `welcome#index`, where they can create an account or sign in.
- Email/password registration is handled by Devise and creates a confirmable `User`.
- Successful login redirects to `dashboard#index`, an authenticated landing surface ready for onboarding.
- Logout redirects to `welcome#index`.
- Invalid registration and login attempts show recoverable, localized errors.
- English is the default locale; Spanish remains available.

## Source Files

- `app/models/user.rb`
- `app/controllers/application_controller.rb`
- `app/controllers/dashboard_controller.rb`
- `app/controllers/welcome_controller.rb`
- `app/controllers/users/omniauth_callbacks_controller.rb`
- `app/views/devise/registrations/new.html.erb`
- `app/views/devise/sessions/new.html.erb`
- `config/initializers/devise.rb`
- `config/routes.rb`

## Specs

- `spec/system/user_access_flow_spec.rb`
- `spec/models/user_spec.rb`
- `spec/controllers/users/omniauth_callbacks_controller_spec.rb`
- `spec/requests/localization_spec.rb`
