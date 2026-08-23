# 6.1 Birthday Concierge

**Area:** 6. Planning Workflows

A guided, owner-scoped birthday workflow built on the reusable `EventPlan`
workspace. It starts from an upcoming birthday, prepares an editable runway,
and keeps one practical next action prominent without acting outside the app.

## Capabilities

- Start a prefilled birthday plan from an owned active relationship's birthday
  `ImportantDate`, preserving the date with an explicit birthday-origin
  provenance role. The sourced occasion remains birthday on later edits so its
  provenance and localized runway cannot drift into another event type.
- Seed a localized English or Spanish runway for the birthday intention,
  format, participants, restaurant or activity ideas, gift, message draft,
  reminders, backup option, and day-of review.
- Prioritize the earliest due incomplete current step as the next action.
- Hand gift, message, reminder, and backup steps into their existing
  review-only workspaces.
- Track progress, status, outstanding decisions, reminders, provenance, and
  personal touches in the shared event-plan workspace.
- Request optional source-backed suggestions and backup options through the
  RubyLLM provider boundary.
- Keep all messages as drafts and all reminders, contacts, bookings, and
  purchases under explicit user control.

## Workflow Steps

1. Upcoming birthday detected.
2. User starts planning.
3. App prefills the relationship, birthday occurrence, and localized title.
4. User reviews or changes budget, participants, and constraints.
5. App creates the deterministic birthday runway.
6. Workspace highlights one next action and relevant existing workflow.
7. User optionally requests source-backed suggestions or backup options.
8. User explicitly edits, completes, promotes, schedules, sends, contacts,
   books, or purchases through separate user-controlled actions.

## Possible Data Objects

- `EventPlan`
- `PlanTask`
- `ImportantDate`
- `Reminder`
- `BackupPlan`
- `PersonalTouchChecklist`

## Implementation Notes

`EventPlan` remains the single planning store; no parallel `BirthdayPlan` model
is introduced. `EventPlans::LlmSuggester` and `BackupPlans::LlmGenerator` use
`CARECIERGE_EVENT_PLAN_PROVIDER` and `CARECIERGE_EVENT_PLAN_MODEL` (defaulting
to OpenAI and `gpt-5-mini`) so a supported RubyLLM provider can be selected
without rewriting the planning operations. Without an explicit shared model,
OpenAI, Anthropic, and Gemini select compatible defaults as a provider/model
pair. OpenAI requests explicitly disable provider response storage, and every
provider request has a bounded output-token limit. Explicit model overrides are
sent to the selected provider even when the model is newer than RubyLLM's
bundled registry; repository defaults continue to use normal registry
validation. Provider keys can come from the matching environment variable or
encrypted Rails credentials.
Application-side source, tenancy, schema, length, and lifecycle validation
remains authoritative for every provider.

RSVP tracking, automatic vendor integrations, booking, purchasing, and
post-event recap automation remain future work.

## Verification

- `bundle exec rspec spec/requests/event_plans_spec.rb spec/requests/important_dates_spec.rb spec/models/event_plan_spec.rb spec/services/event_plans/template_spec.rb spec/components/event_plan_workspace_component_spec.rb`
- `bundle exec rspec spec/services/event_plans spec/services/backup_plans spec/agents/event_plans spec/agents/backup_plans`
- `bin/ci`
