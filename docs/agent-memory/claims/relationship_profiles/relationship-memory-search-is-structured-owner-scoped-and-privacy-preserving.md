---
id: relationship_profiles.relationship_memory_search_is_structured_owner_scoped_and_privacy_preserving
type: fact
system: relationship_profiles
status: current
confidence: high
severity: important

title: Relationship memory search is structured, owner scoped, and privacy preserving

claim: >
  Authenticated relationship-memory search uses the Pundit-scoped profile relation
  to search profiles, unprotected notes, preferences, timeline entries and
  interactions, commitments, gifts, and important dates. It supports explicit
  text, source, relationship, archive-status, and date-range filters, groups
  normalized results by relationship, deduplicates derivative timeline records,
  links each result to an editable source workflow, bounds each source query to
  500 deterministically ordered candidates, and paginates twenty results at a time. Active relationships are the default;
  archived relationships require an explicit filter, foreign relationship UUIDs
  return no results, malformed scalar filters fail closed, and text queries are
  limited to 200 characters. Privacy-vault-backed notes never enter the result
  set. Search submissions and pagination use POST bodies so query text does not
  enter URLs or browser history, the dedicated search-text parameter is filtered
  from request and SQL logs, and query instrumentation records filter shape and
  result count but never the query text. Natural-language and semantic retrieval
  remain deferred behind the query interface.

source_files:
  - app/queries/relationship_memory_search/search_query.rb
  - app/models/relationship_memory_search/search_result.rb
  - app/controllers/relationship_searches_controller.rb
  - app/helpers/relationship_searches_helper.rb
  - app/views/relationship_searches/show.html.erb
  - config/routes.rb

related_files:
  - app/views/relationship_profiles/index.html.erb
  - app/views/relationship_profiles/_form.html.erb
  - config/initializers/filter_parameter_logging.rb
  - config/locales/en.yml
  - config/locales/es.yml
  - docs/features/04-05-relationship-search.md
  - spec/queries/relationship_memory_search/search_query_spec.rb
  - spec/requests/relationship_searches_spec.rb
  - spec/system/relationship_search_spec.rb
  - spec/config/filter_parameter_logging_spec.rb
symbols:
  - RelationshipMemorySearch::SearchQuery
  - RelationshipMemorySearch::SearchResult
  - RelationshipSearchesController
  - RelationshipSearchesHelper
routes:
  - relationship_search
tags:
  - relationship_profiles
  - relationship_search
  - privacy
  - pundit
  - pagy
  - instrumentation

verification:
  - bundle exec rspec spec/queries/relationship_memory_search/search_query_spec.rb spec/requests/relationship_searches_spec.rb spec/system/relationship_search_spec.rb
  - bundle exec rspec spec/requests/relationship_profiles_spec.rb spec/requests/privacy_vaults_spec.rb
  - bin/rubocop app/queries/relationship_memory_search/search_query.rb app/models/relationship_memory_search/search_result.rb app/controllers/relationship_searches_controller.rb app/helpers/relationship_searches_helper.rb spec/queries/relationship_memory_search/search_query_spec.rb spec/requests/relationship_searches_spec.rb spec/system/relationship_search_spec.rb
  - bin/memory validate
  - bin/memory coverage --git-diff
  - bin/ci

last_verified_commit: null
---

# Relationship memory search is structured, owner scoped, and privacy preserving

## Claim

Relationship memory search is a read-only, authenticated projection over the
signed-in owner's structured relationship data. The query object normalizes
heterogeneous records into source-identified results while preserving the
profile ownership, archive, and privacy-vault boundaries.

## Why It Matters

Search combines several sensitive data sources. A single unscoped association,
protected note, or logged query could expose private relationship context, so
future source additions must reuse the owner relation, explicitly exclude
vault-backed records, and preserve privacy-safe instrumentation.

## Evidence

- `app/queries/relationship_memory_search/search_query.rb`
- `app/controllers/relationship_searches_controller.rb`
- `app/views/relationship_searches/show.html.erb`
- `spec/queries/relationship_memory_search/search_query_spec.rb`
- `spec/requests/relationship_searches_spec.rb`

## Verification

- `bundle exec rspec spec/queries/relationship_memory_search/search_query_spec.rb spec/requests/relationship_searches_spec.rb spec/system/relationship_search_spec.rb`
- `bundle exec rspec spec/requests/relationship_profiles_spec.rb spec/requests/privacy_vaults_spec.rb`
- `bin/memory validate`
- `bin/memory coverage --git-diff`
- `bin/ci`
