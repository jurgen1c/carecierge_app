# 4.1 AI Memory Extraction

**Area:** 4. AI Assistance and Intelligence

AI extracts structured memory from unstructured notes, recaps, messages, and planning conversations.

## Capabilities

- Extract preferences.
- Extract dates.
- Extract desires.
- Extract commitments.
- Extract gift ideas.
- Extract boundaries.
- Extract emotional context.
- Request user approval.
- Track source and confidence.

## Possible Data Objects

- `AIExtractionJob`
- `ExtractedMemory`
- `MemorySource`
- `MemoryApprovalStatus`

## Implementation Notes

Every extracted item should preserve source context.

Example:

- Preference: likes jazz
- Source: Dinner recap, May 5
- Confidence: confirmed by user or inferred by AI
