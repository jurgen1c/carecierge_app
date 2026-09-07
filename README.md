# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...

## Development journeys

After `bin/setup`, run `bin/rails db:seed` for isolated synthetic accounts. See the [journey manifest](docs/development/journeys.md) for credentials, routes, reference dates and safe reset.

## Production account

`db/seeds/production.rb` provisions Jurgen Clausen's account (`jurgen1c@gmail.com`). Configure `PRODUCTION_SEED_PASSWORD` in the production environment before its first creation, then run:

```sh
RAILS_ENV=production bin/rails db:seed
```

A new account is a regular user and requires email confirmation. Seeds do not send email; use the sign-in page's confirmation-instructions link to request it. Existing accounts retain their password, role, confirmation and security state, and do not require the environment variable on reruns. The application currently identifies users by email and has no name field.
