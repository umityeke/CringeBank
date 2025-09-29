# Style Search – System Design & Implementation Guide

_Last updated: September 29, 2025_

## 0. Goals
- Return fast, relevant results for Accounts, Hashtags, Places, and (optionally) Posts.
- Provide type-ahead autocomplete, personalized ordering, and Turkish-aware matching.
- Support both Turkish and English queries with robust diacritic/casing handling.
- Start with an MVP (Firestore-only) but leave a clean migration path to a dedicated search engine such as Algolia, Typesense, Meilisearch, or Elasticsearch.

## 1. Indices & Entities
Maintain a distinct logical index per entity so ranking, facets, and visibility rules remain independent.

| Index | Required fields | Ranking signals | Visibility flags |
|-------|-----------------|-----------------|------------------|
| `accounts` | `id`, `username`, `displayName`, `bio`, `avatar`, `followerCount`, `followingCount`, `isVerified`, `isBusiness`, `interests[]`, `search_normalized_tr`, `search_ascii` | text match weights (`username` > `displayName` > `bio`), log follower count, engagement affinity | `isSuspended`, `isPrivate`, `isShadowLimited` |
| `hashtags` | `id`, `tag` (no `#`), `postCount`, `recentUsageCount`, `trendScore`, `relatedTopics[]`, normalization fields | exact/prefix match, recency & growth | `isBlocked`, `isLimited` |
| `places` | `placeId`, `name`, `city`, `country`, `geo.lat/lng`, `popularityScore`, `category`, normalization fields | text match, geo proximity, popularity | `isHidden`, `hasSafetyFlags` |
| `posts` (optional early) | `id`, `caption`, `hashtags[]`, `taggedUsers[]`, `placeId`, `likeCount`, `commentCount`, `createdAt`, `safetyFlags[]`, normalization fields | text/hashtag match, engagement, recency | `isPrivate`, `isShadowLimited`, `creatorBlocked` |

All indices must store the normalized search tokens (§4), lightweight scoring features, visibility booleans, and timestamps (`updatedAt`, `indexedAt`).

## 2. Data Flow & Sync (Firestore ⇄ Search Index)
- **Source of truth:** Firestore collections (`users`, `hashtags`, `places`, `posts`).
- **Indexer:** Cloud Functions triggered on create/update/delete.
  1. Fetch the Firestore document.
  2. Normalize search fields (Turkish-aware lowercasing & diacritic folding).
  3. Compute or refresh ranking features (e.g., log follower count, trend score).
  4. Upsert or delete the corresponding search index document.
- **Resilience:**
  - Wrap index calls in retries with exponential backoff.
  - Push failures to a Pub/Sub dead-letter topic for later reprocessing.
  - Make upserts idempotent (document `id` == index `objectID`).
- **MVP fallback:**
  - Within Firestore, store prefix tokens (`username_tokens`) or n-grams to back simple range queries for autocomplete.
  - Understand this approach is limited: carefully watch document size & index costs, and plan the migration to a dedicated engine once traffic grows.

## 3. Query Pipeline (Client → Backend → Index)
1. Client debounces keystrokes (≈250 ms) and ignores queries shorter than two characters.
2. Client hits `/search` (Callable/HTTPS Cloud Function) with payload `{ query, userId, locale, categoryHints, cursors }`.
3. Backend normalizes the query, fans out to each index in parallel, applies visibility filters, and assembles a sectioned response:
   ```json
   {
     "top": [...],
     "accounts": { "items": [...], "nextCursor": "..." },
     "hashtags": { ... },
     "places": { ... },
     "posts": { ... },
     "timing": { "totalMs": 83, "byIndex": { "accounts": 41, ... } }
   }
   ```
4. Client renders sections with sticky headers, allowing infinite scroll per entity.
5. When the query is empty, backend returns Recent Searches and Trending results (see §8).

## 4. Text Normalization (Turkish-aware)
Create utilities that:
- Lowercase with locale `tr-TR` (proper handling of `İ/ı`).
- Remove/replace Turkish diacritics (`ç→c`, `ğ→g`, `ı→i`, `İ→i`, `ö→o`, `ş→s`, `ü→u`).
- Normalize Unicode (NFKC/NFKD) to collapse compatibility characters.
- Produce:
  - `search_normalized_tr`: locale-aware lowercase, diacritics preserved or consistently mapped.
  - `search_ascii`: ASCII-folded version for cross-language matching.
- Tokenize into unigrams/bigrams for autocomplete support; full tokens for exact match ranking.

**Copilot reminder:** “Always build and update search_normalized_tr and search_ascii for username, displayName, hashtag name, and place name; prefer Turkish locale lowercasing and deterministic diacritic folding.”

## 5. Retrieval & Ranking
1. Fetch candidate results from each index using text match filters (prefix/exact/contains).
2. Compute a base relevance score from textual proximity.
3. Apply heuristic weighting until ML re-ranking is available:
   ```
   FinalScore = 0.55 * TextMatch + 0.20 * Popularity + 0.15 * PersonalAffinity + 0.10 * Recency - Penalties
   ```
4. Normalize scores to `[0,1]` per index, then blend the highest overall into the `top` section.

**Entity-specific factors:**
- **Accounts**: text match priority (`username` > `displayName` > `bio`), log follower count, interaction proximity (follow/DM history), verification & business boosts, downrank spam signals.
- **Hashtags**: text match, `recentUsageCount` (48 h window), `trendScore` (time-decayed growth), content safety checks.
- **Places**: name match, check-ins/popularity, geo proximity (if user allowed location), category preference boosts.
- **Posts**: caption & hashtag match, engagement & recency, safety flags
- **Personalization**: prior clicks, graph distance, inferred interests, language preference weighting (Turkish > English when ambiguous).

## 6. Autocomplete & Suggestions
- Trigger when query length ≥ 2 after normalization.
- Return ≤8 results per entity with fast response (<150–250 ms perceived).
- Favor prefix matches on both `search_normalized_tr` and `search_ascii`.
- Support Did-You-Mean via edit-distance ≤1.
- Maintain synonyms/aliases (e.g., `GS`, `Cimbom` → `Galatasaray`; `İst`, `Istanbul` → `İstanbul`).
- Rank suggestions by text proximity, popularity, and user affinity.

## 7. Trending & No-Query Results
- Hourly aggregation job (Cloud Scheduler + Function) recalculates trend metrics for hashtags & places:
  - `trendScore = log(1 + recentUsageCount) + α * growthRate − β * timeDecay`.
- Provide trending lists only after safety filtering.
- Personalize lightly (boost entries from user’s city or interests).
- Client shows Recent Searches (local cache with TTL) and Trending sections when search box is empty.

## 8. Client UX (Flutter)
- Debounce input at 250 ms; display skeleton loaders while fetching.
- Cancel in-flight requests on new keystrokes to avoid stale results.
- Render a sectioned list: `Top`, followed by individual `Accounts`, `Hashtags`, `Places`, `Posts` sections.
- Highlight matched substrings.
- Show Recent Searches with quick "clear all" action.
- Respect privacy: private accounts appear but their posts aren’t previewed. Blocked/Muted users never surface.
- Provide explicit empty states with guidance (“No results for …”).

## 9. Safety, Privacy, and Abuse Handling
- Filter out suspended, private (where not authorized), or shadow-limited entities before scoring.
- Respect all block/mute relationships server side.
- Downrank or exclude reported/spammy accounts and unsafe hashtags/posts.
- When using hosted search (e.g., Algolia):
  - Issue secured API keys with tenant-specific filters.
  - Enforce rate limits and quotas.
  - Log queries with anonymization/pseudonymization.

## 10. Analytics & Feedback Loop
Track the funnel:
- Query metadata: string, locale, result counts per index.
- Result interactions: clicks, taps, dwell time, follow/sub actions.
- CTR by rank per entity.
Use analytics to tune synonyms, blacklists, scoring weights, and to prepare labeled data for an ML re-ranker (start with gradient-boosted trees or logistic regression).

## 11. MVP vs Production
- **MVP (Firestore-only)**:
  - Support Accounts & Hashtags only.
  - Store `username_lower`, `hashtag_lower`, plus prefix tokens for crude autocomplete.
  - Range query pattern: `where field >= query` and `< query + '\uf8ff'`.
  - Monitor document sizes; keep tokens modest.
- **Production**:
  - Adopt Algolia / Typesense / Meilisearch / Elasticsearch.
  - Define per-index schemas with searchable attributes, ranking weights, typo tolerance, Turkish analyzers.
  - Keep Cloud Functions for sync; server merges responses and applies personalization.

## 12. Pagination, Caching, & Performance
- Use cursor-based pagination from the search engine per index.
- Cache recent query results (e.g., in-memory LRU) to handle quick back/forward navigation.
- Apply request timeouts (≈800 ms) and serve partial sections if any index lags.
- Store recent searches locally with TTL, synced with server suggestions.

## 13. Copilot Task Prompts
Embed these prompts in code comments or tasks to guide Copilot:
1. “Add a search service that queries four indices (accounts, hashtags, places, posts) in parallel and returns a sectioned payload: top, accounts, hashtags, places, posts. Include pagination cursors per section and return timing metadata.”
2. “Implement Turkish-aware text normalization utilities that: lowercase with ‘tr-TR’ rules, remove diacritics, Unicode-normalize (NFKC/NFKD), and also produce an ASCII-folded variant. Use them to populate search_normalized_tr and search_ascii fields for all searchable names.”
3. “Create Cloud Functions that upsert/delete index records on Firestore create/update/delete for users, hashtags, places, and posts. Make the upsert idempotent and push failures to a dead-letter queue.”
4. “Define ranking features per entity (e.g., followerCount log-scaled for accounts, recentUsageCount & trendScore for hashtags). Add a simple weighted scoring: textMatch, popularity, personalAffinity, recency; then normalize to [0,1].”
5. “Build an autocomplete endpoint returning up to 8 suggestions per entity using prefix search and typo tolerance (1 edit). Add synonyms (GS→Galatasaray, Cimbom→Galatasaray, Ist→İstanbul, etc.).”
6. “Implement a trending job that computes trend scores hourly for hashtags and places using time-decayed growth. Return a safe, localized trending list when the query is empty.”
7. “On the client, debounce input (250ms), ignore queries shorter than 2 chars, cancel in-flight requests on new keystrokes, and render sectioned results with highlighted matches. Add Recent Searches with clear-all.”
8. “Add safety filters to exclude private or suspended entities and downrank reported/spammy accounts. Respect blocks/mutes at retrieval time.”
9. “Instrument analytics for query→result→click funnels, store CTR by rank, and expose metrics to tune synonyms and weights. Prepare hooks for future ML re-ranking.”

## 14. Anti-Patterns to Avoid
- Relying solely on Firestore `array-contains` or naive token arrays for full text search.
- Ignoring Turkish diacritics/casing—causes major recall loss.
- Mixing private/sensitive fields into public payloads.
- Performing heavy personalization on the client; keep it server-side.

## 15. Acceptance Checklist
- Turkish queries match both with and without diacritics.
- Autocomplete responses feel instant (<150–250 ms perceived).
- Sectioned results + `Top` blend stay consistent.
- Private or blocked entities never leak sensitive data.
- Trending and recent searches populate with safe defaults.
- Analytics capture CTR and query success metrics.

## Appendix A – Search Engine Schema Hints (Algolia / Typesense)

### Accounts Index
- **Searchable attributes:** `username`, `displayName`, `bio`, `search_normalized_tr`, `search_ascii`.
- **Filterable/facetable:** `isVerified`, `isBusiness`, `isPrivate`, `isSuspended`, `interests`.
- **Custom ranking:** `desc(followerCountLog)`, `desc(personalAffinity)`, `desc(recentInteractionTs)`.
- **Optional ranking formula:** tie in `accountQualityScore` to penalize spam.

### Hashtags Index
- **Searchable:** `tag`, `search_normalized_tr`, `search_ascii`, `relatedTopics`.
- **Filterable:** `isBlocked`, `language`.
- **Ranking:** `desc(trendScore)`, `desc(recentUsageCountLog)`, `desc(postCountLog)`.
- **Typo tolerance:** allow 1 edit, disable for extremely short tags (≤2 chars).

### Places Index
- **Searchable:** `name`, `city`, `country`, normalization fields.
- **Filterable:** `category`, `isHidden`.
- **Geo settings:** enable geo search with `geo.lat`, `geo.lng`.
- **Ranking:** `geo`, `desc(popularityScore)`, `desc(recentCheckins)`.

### Posts Index (future)
- **Searchable:** `caption`, `search_normalized_tr`, `hashtags`, `taggedUsers`.
  - Consider splitting hashtags into normalization fields to reuse the same analyzers.
- **Filterable:** `hasSafetyFlags`, `language`, `creatorVerified`.
- **Ranking:** `desc(engagementScore)`, `desc(recencyScore)`, plus text relevance.

When configuring Typesense/Meilisearch, mirror the same fields but use their native analyzers. Ensure the Turkish analyzer or custom pipeline handles `İ/ı` correctly and apply synonyms & stop-words as needed.
