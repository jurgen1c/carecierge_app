# 4.5 Relationship Search

**Area:** 4. AI Assistance and Intelligence

Users can search across structured relationship memory while retaining clear
source identity and privacy boundaries.

## Example Queries

- Who has a birthday next month?
- What does Ana like?
- What gifts have I given my wife?
- Who did I promise to follow up with?
- Which friends like hiking?
- What should I remember before meeting David?
- What restaurants does Maria dislike?

## Capabilities

- Search structured fields.
- Search notes.
- Search timeline.
- Search preferences.
- Search commitments.
- Search gift history.
- Filter by source, relationship, active or archived status, and useful date
  ranges.
- Group results by relationship and link every result to its source record.
- Exclude privacy-vault-backed notes from ordinary search.
- Keep natural-language and semantic queries as a later enhancement.

## Possible Data Objects

- `SearchQuery`
- `SearchResult`
- `RelationshipMemorySearch::SearchQuery`
- `RelationshipMemorySearch::SearchResult`
- Embeddings or a vector index later

## Implementation Notes

The shipped first stage uses a bounded text query and explicit filters over the
signed-in owner's Pundit-scoped relationship profiles. Active profiles are the
default; archived profiles must be requested explicitly. Results cover profiles,
unprotected relationship notes, preferences, timeline entries and interactions,
commitments, gifts, and important dates. Pagy limits the visible result set to
twenty rows per page.

Each selected source query loads at most 500 candidates before normalization.
Derivative timeline entries and interactions are deduplicated against their
underlying source, and their result links open that source's editable workflow.

Search instrumentation records only filter shape and result count; it never
records the relationship query text. Search submissions and pagination send the
query in POST bodies rather than URLs or browser history, and request and SQL
logging filter the dedicated search parameter. Semantic search should extend
the query interface without bypassing owner scope, source identity, or
privacy-vault exclusion.

## Verification

- `bundle exec rspec spec/queries/relationship_memory_search/search_query_spec.rb spec/requests/relationship_searches_spec.rb spec/system/relationship_search_spec.rb`
- `bundle exec rspec spec/requests/relationship_profiles_spec.rb spec/requests/privacy_vaults_spec.rb`
- `bin/ci`
