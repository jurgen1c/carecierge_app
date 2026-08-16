# 5.2 Relationship Briefing

**Area:** 5. Daily Experience

Before a meeting, date, call, or event, a user can request a concise, private briefing about the person.

## Capabilities

- Accept the user's specific interaction context.
- Organize recent activity, open commitments, upcoming dates, preferences, and optional conversation topics.
- Label every item as confirmed or inferred and show its saved-record provenance.
- Include private notes only when explicitly selected for that request.
- Include privacy-vault items only when explicitly selected during an active vault lease.
- Let the user save or dismiss the briefing, create a separate reminder, or open the existing message-draft workspace.
- Never send, schedule, or contact anyone automatically.

## Example

You are seeing your sister tomorrow. She recently mentioned stress at work and wanting help moving. You promised to send her a mover recommendation.

## Data Objects

- `RelationshipBriefing` stores an encrypted snapshot of the request and source-backed sections.
- Briefing items retain bounded provenance labels, not copied source contents.

## Implementation Notes

Briefings are user-triggered from the relationship profile. The generation request uses a structured, non-stored provider response and rejects results when the profile's source fingerprint or generation fence changes while the provider is running.

Calendar-triggered briefings remain a possible later capability and are not enabled by this feature.
