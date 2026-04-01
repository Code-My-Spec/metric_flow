# MetricFlow.Reviews.ReviewRepository

Data access layer for Review CRUD and query operations. All queries are scoped via Scope struct for multi-tenant isolation. Provides create_reviews/2 for bulk upsert (deduplicates on external_review_id), list_reviews/2 with filter options (provider, location_id, date_range, limit, offset), and delete_reviews_by_provider/2.

## Type

module

## Dependencies

- MetricFlow.Reviews.Review

## Functions

