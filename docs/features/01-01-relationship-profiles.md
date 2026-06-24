# 1.1 Relationship Profiles

**Area:** 1. Core Relationship Management

Users can create a profile for each person they want to care for, remember, support, or manage intentionally.

## Capabilities

- Create, edit, archive, and delete relationship profiles.
- Assign a relationship type.
- Add personal details.
- Add contact details.
- Add important notes.
- Add structured preferences.
- Add private/sensitive notes.
- View a full profile summary.
- Search and filter relationships.

## Example Relationship Types

- Spouse / partner
- Child
- Parent
- Sibling
- Friend
- Extended family
- Coworker
- Boss
- Employee
- Client
- Mentor
- Neighbor
- Custom

## Possible Data Objects

- `User`
- `RelationshipProfile`
- `RelationshipType`
- `ContactMethod`
- `RelationshipNote`
- `RelationshipTag`

## Implementation Notes

Relationship profiles are the foundation of the product. Most other features should reference a profile.

The system should support both structured data and free-form notes because users will not always want to fill out rigid forms.
