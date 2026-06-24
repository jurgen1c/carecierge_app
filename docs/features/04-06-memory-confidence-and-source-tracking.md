# 4.6 Memory Confidence and Source Tracking

**Area:** 4. AI Assistance and Intelligence

The system tracks whether facts are user-confirmed, AI-inferred, imported, or outdated.

## Capabilities

- Mark facts as confirmed.
- Mark facts as inferred.
- Store source.
- Store confidence score.
- Allow correction.
- Allow expiration or review.

## Possible Data Objects

- `MemoryRecord`
- `MemorySource`
- `MemoryConfidence`
- `MemoryRevision`

## Implementation Notes

This will matter deeply once automation is introduced. The app should avoid making purchases or booking decisions based on low-confidence inferred data.
