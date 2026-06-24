# 2.5 Conversation Recaps

**Area:** 2. Relationship Memory

Users can quickly capture a conversation summary. AI can extract facts, preferences, dates, desires, and follow-ups from the recap.

## Capabilities

- Add text recap.
- Add voice-to-text recap later.
- Extract structured memories.
- Let user approve extracted memories.
- Create follow-up reminders from recap.
- Link recap to relationship timeline.

## Example Input

Had lunch with David. He is thinking about changing jobs. His wife is pregnant. He wants leadership book recommendations.

## Possible Extractions

- David may change jobs.
- David's wife is pregnant.
- Follow up with book recommendations.
- Ask about job search later.
- Important life event: upcoming child.

## Possible Data Objects

- `ConversationRecap`
- `MemoryExtraction`
- `ExtractedFact`
- `ExtractionApproval`

## Implementation Notes

Do not silently mutate important relationship memory without user visibility. Extract, suggest, then allow approval.
