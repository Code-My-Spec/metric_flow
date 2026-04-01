# MetricFlow.Reviews.Review

Ecto schema representing an individual customer review. Stores integration_id, provider, external_review_id, reviewer_name, star_rating (1-5), comment text, review_date, location_id, and metadata map for provider-specific fields. Belongs to User via integration. Indexed on [user_id, provider], [user_id, review_date], and [external_review_id] for deduplication during sync.

## Type

schema

## Dependencies

- MetricFlow.Integrations.Integration

## Functions

