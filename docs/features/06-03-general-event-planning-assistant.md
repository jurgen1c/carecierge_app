# 6.3 General Event Planning Assistant

**Area:** 6. Planning Workflows

A reusable, owner-scoped planning workspace for relationship-based events. It
combines a deterministic starting plan with optional, explicitly requested AI
suggestions that remain source-backed and review-only.

## Event Types

- Birthday
- Anniversary
- Graduation
- Baby shower
- Retirement
- Promotion
- Family reunion
- Date night
- Children's party
- Holiday event
- Apology/repair gesture
- Custom event

## Capabilities

- Create, edit, complete, reopen, and archive an event plan for an owned active
  relationship.
- Define an optional date, budget, guest list, and planning notes.
- Start with a deterministic, localized runway covering decisions, tasks,
  reminders, vendor needs, gift ideas, message drafts, milestones, and backup
  steps.
- Group work into Decide, Arrange, and Follow-through phases while showing
  progress, outstanding decisions, and the next active reminder.
- Create, edit, complete, reopen, and remove individual plan steps.
- Hand any incomplete step on an active plan into the existing reminder flow
  without scheduling or sending anything automatically. Deleting a step
  detaches its reminders instead of deleting their history.
- Request optional AI suggestions with current, non-stale public relationship
  context by default.
  Private notes require explicit per-request selection and show a bounded text
  excerpt so same-day choices remain identifiable; protected vault items
  additionally require suggestion approval and an active, revalidated vault
  lease, and unlocked choices are identified by their protected title before
  selection. Previously generated sourced steps are excluded from later provider
  requests unless every persisted source remains currently authorized. Memory
  staleness and important-date eligibility use the owner's local calendar.
- Show source provenance on generated steps and retain only known, bounded
  source identifiers and labels.
- Export plans and tasks with owner data, and selectively delete AI-origin plan
  suggestions while preserving the plan, non-AI birthday-origin provenance,
  template/manual work, and reminders.

## Possible Data Objects

- `EventPlan`
- `PlanTask`
- `Reminder`

## Implementation Notes

- `EventPlans::Create` creates the plan and localized template steps in one
  transaction.
- `EventPlans::Update` rebases deadlines that still match the deterministic
  template when the event date changes, while preserving dates the user
  customized.
- `EventPlans::Suggest` uses account, relationship, and plan generation locks;
  eligible relationship-context writers participate in the relationship lock,
  every plan or task mutation revalidates the active relationship under that
  lock, lifecycle changes advance the generation fence, and a complete bounded
  source fingerprint rejects stale provider output. Important-date context uses
  each date's next occurrence and excludes expired one-time dates.
- Reminder creation and reassignment hold relationship, plan, and task locks
  through persistence so terminal planning work cannot gain a new active
  reminder through a concurrent request.
- Event-plan table creation remains transactional. A separate safely rerunnable
  migration adds reminder foreign-key columns with concurrent indexes and
  separately validated constraints so deployment does not block normal reminder
  writes for the duration of an index build or table scan.
- `EventPlans::LlmSuggester` and `BackupPlans::LlmGenerator` use RubyLLM's
  structured-output interface so the configured model and provider can change
  without changing the planning operations. Provider defaults resolve to a
  compatible OpenAI, Anthropic, or Gemini model, and explicit provider-neutral
  model configuration takes precedence over the legacy OpenAI-only credential;
  Kamal leaves that shared override unset unless the operator supplies it.
  OpenAI responses explicitly use `store: false`, while all provider payloads
  have bounded output-token limits and remain subject to application-side schema,
  provenance, tenancy, and lifecycle validation. Their instructions prohibit
  sending messages, contacting vendors, booking, purchasing, or scheduling
  actions. Event-plan and task content is filtered from request logs, task
  titles stay out of reminder URLs, and event-plan pages disable Turbo
  snapshots.
- The responsive workspace uses Carecierge's existing semantic palette and
  component/style-variant conventions. It is available globally and from each
  relationship profile.
- Birthday and anniversary concierge workflows can specialize this generic
  model without introducing separate planning stores.

## Verification

- `bundle exec rspec spec/models/event_plan_spec.rb spec/models/plan_task_spec.rb spec/models/reminder_spec.rb`
- `bundle exec rspec spec/services/event_plans spec/policies/event_plan_policy_spec.rb spec/policies/plan_task_policy_spec.rb`
- `bundle exec rspec spec/components/event_plan_workspace_component_spec.rb spec/requests/event_plans_spec.rb spec/requests/reminders_spec.rb`
- `bundle exec rspec spec/requests/data_controls_spec.rb spec/services/data_deletions/delete_ai_data_spec.rb`
- `bin/ci`
