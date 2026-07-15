# 3.3 Contact Cadence Tracking

**Area:** 3. Reminders and Commitments

Users can define how often they want to check in with someone.

## Capabilities

- Set desired contact frequency.
- Track last meaningful interaction.
- Remind when overdue.
- Allow different cadence by relationship type.
- Detect stale relationships.

## Examples

- Call mom weekly.
- Text best friend every two weeks.
- Check in with client monthly.
- Have one-on-one time with each child weekly.

## Possible Data Objects

- `ContactCadence`
- `Interaction`
- `InteractionType`

## Implementation Notes

Be careful not to make relationships feel mechanical. Use supportive language.

## Implemented Behavior

- Relationship types provide a suggested cadence, but the suggestion remains inactive until the user accepts or adjusts it for that relationship.
- Manual interactions and source-backed interactions share one chronological history. Conversation recaps and mood notes currently synchronize derived entries; the polymorphic source boundary supports later integration adapters.
- The latest recorded interaction determines the next check-in window. When no interaction exists, the cadence acceptance time starts the first window.
- Overdue prompts explicitly acknowledge that a recent interaction may not have been logged. They offer manual logging or a link to the existing Reminder form and never create a reminder automatically.
- Manual interaction routes cannot edit or delete source-backed entries.
