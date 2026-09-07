# Synthetic development journeys (CAR-105)

After normal `bin/setup`, run:

```sh
DEVELOPMENT_SEEDS=true REFERENCE_DATE=2026-09-06 bin/rails db:seed
```

`db/seeds.rb` loads the file for the current Rails environment after installing baseline data. In development, `db/seeds/development.rb` adds synthetic journeys only when `DEVELOPMENT_SEEDS=true`. Ordinary `db:seed` keeps development data limited to the baseline. Requesting development scenarios in another environment fails before any seed mutation. Existing feature flag assignments are preserved. No factories, live tokens, customer data, AI generators, OAuth exchanges, payment calls, emails or jobs are used by scenario creation. Notifications use in-app delivery only. Existing integration credentials on unrelated accounts are never read.

All accounts below use `Synthetic-only-105!` and are confirmed. Sign out between personas. The `.example` addresses are fictional. Locale is selected by `?locale=en` or `?locale=es`, not a persisted user setting. The application retains English as its default.

| Persona email | Route | Expected state / walkthrough |
| --- | --- | --- |
| new_en@carecierge.example | /onboarding?locale=en | New account, no relationships; English onboarding |
| new_es@carecierge.example | /onboarding?locale=es | New account, no relationships; Spanish onboarding |
| owner_en@carecierge.example | /relationship_profiles/alex-synthetic-owner_en?locale=en | Private synthetic memory, reviewable extraction proposal, failed extraction example, gift idea |
| owner_es@carecierge.example | /relationship_profiles/alex-synthetic-owner_es?locale=es | Equivalent isolated Spanish workspace; cannot access the English owner's private profile |
| owner_en@carecierge.example | /relationship_profiles/alex-synthetic-owner_en/privacy_vault | Locked vault with protected synthetic memory; reauthenticate using the demo password; no shared-space visibility |
| owner_en@carecierge.example | /vault_mfa | MFA unenrolled; no pre-shared MFA secret or active vault lease. Enroll manually to explore MFA |
| owner_en@carecierge.example | /reminders | One upcoming reminder relative to reference date |
| owner_en@carecierge.example | /notification_preference/edit | Daily in-app digest configuration; email/push/SMS disabled. Synthetic historical dispatched digest record; no generated alert or email |
| owner_en@carecierge.example | /event_plans | Active synthetic birthday tea, seven days after reference date |
| owner_en@carecierge.example | /relationship_profiles/alex-synthetic-owner_en | Ceramic mug idea; open purchase planning manually; no purchase or provider action recorded |
| vendor@carecierge.example | /vendor_account | Synthetic vendor submitted for moderation, unpublished |
| admin@carecierge.example | /admin/vendor_accounts | Submitted synthetic vendor in moderation queue; admin dashboard at /admin |
| owner_en@carecierge.example and owner_es@carecierge.example | /shared_relationship_spaces | Accepted synthetic couple and family, each with a shared picnic plan; private memories stay separate |
| owner_en@carecierge.example | /relationship_profiles/sam-synthetic-colleague-owner_en | Professional context with work-only boundaries and gifts disallowed |
| owner_en@carecierge.example | /calendar_connection | Disconnected; no credential record |
| owner_en@carecierge.example | /contacts_connection and /messaging_connection | Authorization required, empty credentials; revoked-access state |

AI results are synthetic persisted states. Seeding does not enable feature flags. The proposal/retry controls remain subject to existing flags and configuration. Live generation, connection, export-email and other explicit actions made later in the browser retain their normal application behavior; they are outside the offline seed command. Avoid those actions during the offline walkthrough.

The default reference date is fixed at 2026-09-06. Choose a current or past date to browse timely reminders; invalid or future reference dates are rejected up front with a `REFERENCE_DATE` error. Repeating with the same date keeps record identities/counts stable. Repeating with a different date moves scenario dates and restores fixture fields, while leaving password/MFA changes intact. If you have approved, rejected, or corrected a synthetic memory proposal, reseeding refuses the scenario transaction and preserves its review evidence. Deliberately retain or remove those review records before rebuilding; seeds never silently undo a review decision.

## Seed-only reset

```sh
bin/rails development:reset_seeds
```

Rails also provides `db:seed:replant`, which truncates all tables before seeding. Use it only for a database you intend to erase completely; the selective reset above preserves unrelated records.

The reserved UUID prefix `ca105000-` identifies these records; emails alone never confer ownership. Reset deletes only those records from the explicit scenario model allowlist. It refuses the entire transaction when dependent records outside that reserved set would be changed, including records created manually beneath a demo account. Remove those dependencies intentionally before retrying. Unrelated accounts and their data are preserved. Never assign this reserved prefix to developer-created records.

## Pending journeys

Billing dependencies must extend this manifest with plan, trial, paid, exhausted and payment-failure personas once shipped. Conversation-import dependencies must add import review/failure journeys once shipped. Neither capability exists in the CAR-105 baseline; typed conversation recaps above are available now.

## Verification

`bundle exec rspec spec/db/seeds_spec.rb spec/lib/development_seeds/world_spec.rb` checks environment guards, repeatability, isolation, collisions, reset and outbound boundaries. Full `bin/ci` is the coverage authority. Walk through the routes above using the indicated persona and locale; verify private profile denial when switching owners. No new interface is introduced by these fixtures.
