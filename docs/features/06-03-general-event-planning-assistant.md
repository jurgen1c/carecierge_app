# 6.3 General Event Planning Assistant

**Area:** 6. Planning Workflows

A reusable event planning system for relationship-based events.

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

- Create event plan.
- Define budget.
- Define guest list.
- Create checklist.
- Suggest vendors.
- Suggest gifts.
- Draft invitations.
- Create timeline.
- Track tasks.
- Generate backup plan.
- Add reminders.

## Possible Data Objects

- `EventPlan`
- `EventType`
- `EventTask`
- `EventGuest`
- `EventBudget`
- `EventTimelineItem`
- `EventChecklistItem`

## Implementation Notes

Use a generic planning model. Birthday and anniversary concierge can be specialized workflows built on top.
