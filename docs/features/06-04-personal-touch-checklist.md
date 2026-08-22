# 6.4 Personal Touch Checklist

**Area:** 6. Planning Workflows

Every plan should distinguish between logistics the app can help with and personal actions only the user should provide.

## Implemented Behavior

- An owner can attach one checklist to an event plan or any important date, including birthdays, anniversaries, and custom relationship moments.
- Checklist items use explicit preference, constraint, message, gift, dietary-need, accessibility-need, logistics, and follow-up categories.
- Creating a checklist adds deterministic prompts for a handwritten note, meaningful memory, final-message review, and follow-up. It also adds bounded suggestions from the relationship's structured preferences.
- Preference-backed suggestions retain bounded source identifiers and labels, and normalize preference confidence into a visible confirmed or inferred source explanation. Private notes and Privacy Vault items are not read by this deterministic flow.
- Owners can add, complete, reopen, move up, move down, and dismiss items. Ordering controls remain keyboard and touch accessible without drag-and-drop.
- Checklist and item reads are owner-scoped through the relationship profile. Creation and mutation lock the owning account before the profile and moment or checklist, then revalidate the active relationship; archived event plans cannot be changed.
- Relationship and account data exports include checklist items and their attached moment identifiers.

## Example Sections

App can help:

- reservation
- cake
- flowers
- reminders
- invitation draft

User should handle:

- personal note
- meaningful memory
- emotional presence
- final message approval

## Data Objects

- `PersonalTouchChecklist`
- `PersonalTouchItem`

## Implementation Notes

The interface is embedded in the existing event-plan and important-date surfaces. Copy stays concrete and caring; the product does not calculate a care score or automate the personal action.

## Verification

- `bundle exec rspec spec/models/personal_touch_checklist_spec.rb spec/models/personal_touch_item_spec.rb spec/services/personal_touch_checklists/create_spec.rb spec/policies/personal_touch_checklist_policy_spec.rb spec/policies/personal_touch_item_policy_spec.rb spec/components/personal_touch_checklist_component_spec.rb spec/requests/personal_touch_checklists_spec.rb spec/serializers/data_exports/snapshot_spec.rb`
- `bin/rubocop app/models/personal_touch_checklist.rb app/models/personal_touch_item.rb app/services/personal_touch_checklists app/controllers/personal_touch_checklists_controller.rb app/controllers/personal_touch_items_controller.rb app/policies/personal_touch_checklist_policy.rb app/policies/personal_touch_item_policy.rb app/views/components/personal_touch_checklist_component.rb`
- `bin/memory validate`
- `bin/memory coverage --git-diff`
- `bin/ci`
