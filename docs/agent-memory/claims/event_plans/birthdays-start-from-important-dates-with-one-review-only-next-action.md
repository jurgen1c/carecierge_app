---
id: event_plans.birthdays_start_from_important_dates_with_one_review_only_next_action
type: fact
system: event_plans
status: needs_verification
confidence: high
severity: critical

title: Important-date birthday plans start with one review-only next action

claim: >
  The ImportantDate-backed birthday concierge entry accepts only a birthday
  ImportantDate on an active relationship the owner controls. The new-plan form
  prefills the relationship, localized title, birthday occasion, and next
  occurrence; creation revalidates the date and relationship and retains the
  date ID with an explicit birthday-origin provenance role. The occasion is
  immutable for that sourced plan in both the edit form and model validation,
  so changing it cannot leave birthday provenance and localized template tasks
  attached to another event. The
  localized birthday template includes celebration, gift, message, reminder,
  backup, and day-of steps. The workspace highlights the earliest due
  incomplete non-superseded task and links it to an existing user-controlled
  workflow. Nothing is automatically sent, booked, contacted, or purchased.

source_files:
  - app/controllers/event_plans_controller.rb
  - app/models/event_plan.rb
  - app/services/event_plans/create.rb
  - app/services/event_plans/template.rb
  - app/views/event_plans/_form.html.erb
  - app/views/components/event_plan_workspace_component.rb
  - app/views/components/event_plan_workspace_component.html.erb
  - app/views/important_dates/_important_date.html.erb
  - app/views/important_dates/_section.html.erb
  - app/views/important_dates/_upcoming.html.erb
  - config/locales/event_plans.en.yml
  - config/locales/event_plans.es.yml

related_files:
  - app/models/important_date.rb
  - docs/features/06-01-birthday-concierge.md
  - spec/requests/event_plans_spec.rb
  - spec/requests/important_dates_spec.rb
  - spec/models/event_plan_spec.rb
  - spec/services/event_plans/template_spec.rb
  - spec/components/event_plan_workspace_component_spec.rb
symbols:
  - EventPlan#next_action
  - EventPlan#birthday_origin?
  - EventPlansController
  - EventPlans::Template
  - EventPlanWorkspaceComponent
routes:
  - new_event_plan
  - event_plans
tags:
  - event_plans
  - birthdays
  - important_dates
  - localization
  - user_control

verification:
  - bundle exec rspec spec/requests/event_plans_spec.rb spec/requests/important_dates_spec.rb spec/models/event_plan_spec.rb spec/services/event_plans/create_spec.rb spec/services/event_plans/template_spec.rb spec/components/event_plan_workspace_component_spec.rb

last_verified_commit: null
---

# Important-date birthday plans start with one review-only next action

## Claim

Birthday planning extends the shared EventPlan system. An owned birthday date
prefills a localized plan, creation preserves its provenance, and the workspace
surfaces one deterministic next action into existing review-only workflows.

## Why It Matters

Birthday entry combines tenant-scoped relationship data, recurring date
calculation, warm localized copy, and links into gift, message, reminder, and
backup workflows. Remembering these boundaries prevents a later implementation
from introducing a parallel planning store, trusting a foreign date ID, or
turning a planning suggestion into an external action.

## Evidence

- `app/controllers/event_plans_controller.rb`
- `app/models/event_plan.rb`
- `app/services/event_plans/template.rb`
- `app/views/components/event_plan_workspace_component.html.erb`
- `spec/requests/event_plans_spec.rb`
- `spec/components/event_plan_workspace_component_spec.rb`

## Verification

- bundle exec rspec spec/requests/event_plans_spec.rb spec/requests/important_dates_spec.rb spec/models/event_plan_spec.rb spec/services/event_plans/create_spec.rb spec/services/event_plans/template_spec.rb spec/components/event_plan_workspace_component_spec.rb
