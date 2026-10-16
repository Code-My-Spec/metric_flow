# Entity-level metric storage

## Status
Accepted by main through question b4befd27-8ee8-4cf0-b2d1-348d3604e15c for story 57 and issue e5698cef-29fc-4c9b-82d9-d9f39f0c77e5. This approval came from main, not John. Implement the separate account-owned entity observation model, channel entities, total daily observations, snapshots, independent channel revenue, and explicit channel projections into All Metrics. Leave legacy metrics and other providers unchanged. John subsequently approved syncing and storing per-video data, per-video revenue, and breakdowns without displaying them (question 4e6fd25f, 2026-10-15). Issue 8684cf2c-36e2-46c9-a6cc-0f11e11209be implements that storage-only scope. Product retired criteria 1032, 1033, and 1035 and limited 1044 to channel revenue on the dashboard; these storage behaviors are covered by ExUnit.

## Evidence

The current metrics table stores user_id, provider, metric_name, recorded_at, value and JSON dimensions. It has no natural-key uniqueness constraint (priv/repo/migrations/20260223210000_create_metrics.exs). MetricRepository.create_metrics/2 inserts rows without conflict handling. query_time_series/3 sums matching rows by date without separating dimensions. Google Business Profile currently handles location/day replacement explicitly in SyncWorker.delete_stale_performance_metrics/2. Therefore existing storage is not strictly one row per platform/day, but neither identity nor aggregation grain is enforced consistently. Adding video rows to these queries would double-count channel totals. YouTube connections already belong to accounts, while metric queries remain user-scoped.

## Recommended design

Introduce separate account-owned entity observations, leaving legacy metric rows unchanged during the initial rollout. Store both YouTube channel and video observations in this model; expose only explicit channel-total projections to All Metrics. Never copy those observations into legacy metrics as a second authoritative store.

### Entities

metric_entities: id, account_id, provider, entity_type, external_id, parent_entity_id, display_name, published_at, metadata, timestamps. The unique identity is (account_id, provider, entity_type, external_id). A YouTube video belongs to a channel entity. Parent references must remain within the same account and provider, enforced with a composite foreign key; provider-specific validation enforces the permitted parent type. Titles and publication dates are attributes, not observation identity. Reconnecting must not change entity identity.

### Observations

entity_metric_observations: id, account_id, entity_id, metric_name, report_date, report_timezone, measurement_kind, breakdown_type, breakdown_key, value, unit, source_report, fetched_at, timestamps. Use decimal values for revenue and ratios. Measurement kind distinguishes daily flows from snapshots.

Use a database unique key on (account_id, entity_id, metric_name, report_date, report_timezone, measurement_kind, breakdown_type, breakdown_key). All key fields are non-null. Totals use breakdown_type=total and breakdown_key=all. A breakdown uses an explicit type such as country and a canonical key such as US; multi-dimension keys need deterministic serialization. The entity foreign key includes account_id to prevent cross-account observations. Metric definitions specify unit and semantics; conflicting units are rejected rather than silently combined.

Provider report dates retain their documented reporting timezone. Do not reinterpret a provider-local reporting day as a UTC instant. Daily snapshots and historical flow metrics remain distinguishable even if collected in the same run.

### Writes and retries

Derive account_id from an authorized scope and the account-owned integration, never from provider payloads or form params. Upsert exact observation identities and replace values when Google revises a report. For a complete successfully fetched report slice, reconcile obsolete breakdown rows transactionally. Do not delete rows for failed or incomplete report slices. Keep channel, analytics, and revenue outcomes independent so a failed request cannot erase successful data. Track incremental progress per entity and report family; a provider-wide latest date cannot represent partial success.

### Reads and aggregation

All Metrics explicitly selects channel entities, total breakdowns, and the appropriate measurement kind. Video totals and breakdowns never enter channel aggregates implicitly. Additive counts may sum across selected channels. Subscriber and lifetime totals are snapshots: select the latest applicable snapshot per channel rather than summing across dates. Average duration, percentages and CPM require documented weighted formulas and available denominators; otherwise present them per entity or as unavailable aggregates, not sums or unweighted averages. Revenue aggregates must retain currency compatibility.

Queries authorize membership in scope.account_id. Cache keys and any materialized projections include account_id, provider, entity grain, breakdown, metric and date filters. Invalidate affected account projections after committed writes. Existing user-keyed caches must not serve the new data. Video and breakdown display remains a separate product decision.

## Alternatives

1. Extend metrics in place with explicit account/entity/grain fields. This avoids a second repository but requires auditing every dashboard, correlation, AI, cache and export reader before video writes can safely begin. Legacy ownership cannot always be inferred from user_id where one user has multiple accounts.
2. Store video_id only in dimensions. Smallest change, but rejected as a durable design: current readers ignore dimensions, uniqueness remains undefined, and account ownership is still absent.
3. Defer per-video storage. Valid only if product explicitly revises the story; coding must not silently drop the criteria.

## Rollout and validation

After approval, add entity and observation migrations plus account-scoped repository APIs. Keep legacy metrics unchanged; no blanket historical ownership backfill. Implement YouTube writers and explicit channel projections, then integrate metric discovery, dashboard reads and account-aware caching. Other providers can migrate separately once their identity and ownership mappings are established.

Required regression coverage: identical video IDs in different accounts stay isolated; two videos on one day remain distinct; repeated and concurrent writes do not duplicate observations; changed titles do not create new entities; channel totals do not include video or breakdown rows; snapshots and ratios aggregate correctly; failed report slices preserve prior data; missing revenue differs from numeric zero; partial failures do not advance unrelated cursors; reconnecting retains identity. Acceptance assertions continue through approved public surfaces.

## Implementation status

Implemented the approved channel scope: account-owned entities and observations, transactional report replacement, independent analytics and revenue cursors, channel snapshots, and explicit All Metrics projections. Large backfills use batched inserts within one transaction. Sync History reads enforce account membership and live YouTube updates reload persisted outcomes.

Validation: mix precommit passed with 2,990 tests passed and two excluded; all 13 current Story57 channel acceptance scenarios passed. Acceptance selector corrections use LazyHTML.query for descendants without changing expected outcomes. Incidental repository-wide formatting and unused lockfile removals from precommit were restored.

The detailed storage extension adds channel-owned video entities with titles and publication dates, independently persisted video analytics and revenue, and channel traffic-source, device, country, subscription, and content-type observations. Cursor identity includes breakdown_type. Paginated slices replace stored rows only after every page validates; failed slices retain data and progress. Country reports use one-day requests because the provider report does not support a day dimension. Other breakdowns use bounded daily ranges, with a separate views/watch-time availability query. Missing or inaccessible videos retain existing observations. Video and breakdown observations remain excluded from All Metrics.

Sync HTTP requests reserve a shared PostgreSQL budget before each attempt, separately for Data and Analytics APIs. Budgets reset at Pacific midnight and default to 9,000 requests per API, configurable with :youtube_daily_request_budgets (string keys data and analytics). These are application allocations, not a claim about a project's configured Google limits. Operators must allocate room for other consumers of the same Cloud project; OAuth connection discovery is outside this sync counter. A provider quota response gets one budgeted retry and then blocks that API for the current window. Completed report cursors allow later jobs to resume.

Provider references: https://developers.google.com/youtube/analytics/channel_reports, https://developers.google.com/youtube/analytics/reference/reports/query, https://developers.google.com/youtube/analytics/data_model#quota-usage, and https://developers.google.com/youtube/v3/getting-started#quota-usage. The Analytics data-model reference specifies one quota unit per request; its project limits are configured in Google Cloud.

Detailed-storage validation includes account isolation, immutable video parentage, independent family failures, paginated discovery, complete-slice reconciliation, breakdown recovery, dashboard exclusion, quota accounting, and Pacific reset behavior. All 13 existing channel acceptance scenarios also passed with the expanded sync enabled. Final mix precommit passed with 3,021 tests passed and two excluded. Incidental formatter and lockfile changes outside this task were backed up and restored.
