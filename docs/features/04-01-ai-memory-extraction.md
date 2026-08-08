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

CAR-43 implements conversation-recap extraction as a feature-flagged background
workflow. Set `OPENAI_API_KEY` and optionally
`CARECIERGE_MEMORY_EXTRACTION_MODEL` (default: `gpt-5-mini`), then enable the
`ai_memory_extraction` flag for the intended rollout context. Provider responses
use strict structured output and `store: false`. Kamal injects the API key and
the configured model from the deploy environment, and a data migration installs the flag disabled so an
existing deployment can opt into the rollout safely. If credentials, the
provider, or the rollout are unavailable after a request is queued, the recap
enters a retryable failure state without storing provider response content or
creating canonical memory. Requests that predate the worker are also made
retryable during the upgrade.

Interrupted jobs can reclaim `processing` recaps on retry. Recap Turbo responses
also replace the review queue so source changes and deletions do not leave stale
proposal controls in the browser.

Each proposal stays separate from `MemoryRecord` until the profile owner reviews
it. Approval preserves the AI source and confidence, rejection creates nothing,
and correction preserves the original proposal while creating a confirmed
`user_corrected` memory. A proposal is accepted only when its whitespace-normalized
source excerpt occurs in the recap title, body, or transcript. Selective AI-data
deletion locks and cancels every active extraction before removing proposals so
an in-flight provider response cannot recreate deleted data.

Example:

- Preference: likes jazz
- Source: Dinner recap, May 5
- Confidence: confirmed by user or inferred by AI
