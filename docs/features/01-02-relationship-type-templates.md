# 1.2 Relationship Type Templates

**Area:** 1. Core Relationship Management

Different relationship types should have different suggested fields, prompts, and workflows.

## Capabilities

- Provide default templates per relationship type.
- Suggest fields based on selected relationship type.
- Allow custom fields.
- Allow users to hide irrelevant fields.
- Allow future admin-configurable templates.

## Examples

For spouse:

- anniversary
- date ideas
- love language
- favorite restaurants
- emotional triggers
- gift preferences

For boss:

- communication style
- current priorities
- reporting preferences
- meeting style
- feedback preferences

For child:

- school events
- favorite activities
- clothing size
- food preferences
- allergies
- milestones

## Possible Data Objects

- `RelationshipTemplate`
- `TemplateField`
- `RelationshipCustomField`
- `RelationshipFieldValue`

## Implementation Notes

Avoid hardcoding every field directly into the profile table. Use a flexible model for custom attributes, but keep highly queried core fields normalized.
