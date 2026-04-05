# MetricFlow.Reviews.Review

Ecto schema representing an individual customer review. Stores integration_id, provider, external_review_id, reviewer_name, star_rating (1-5), comment text, review_date, location_id, and metadata map for provider-specific fields. Belongs to User via integration. Indexed on [user_id, provider], [user_id, review_date], and [external_review_id] for deduplication during sync.

## Type

schema

## Fields

| Field | Type | Required | Description | Constraints |
|-------|------|----------|-------------|-------------|
| id | integer | Yes (auto) | Primary key | Auto-generated |
| integration_id | integer | Yes | Foreign key to the integration that sourced this review | References integrations.id |
| provider | Ecto.Enum | Yes | The external platform that produced this review | Must be one of: :google_business |
| external_review_id | string | Yes | Provider-assigned unique identifier for this review | Used for deduplication during sync; unique index |
| reviewer_name | string | No | Display name of the reviewer as provided by the platform | Max: 255 |
| star_rating | integer | Yes | Numeric star rating given by the reviewer | Must be between 1 and 5 inclusive |
| comment | string | No | Full text of the review comment | May be nil when reviewer submits rating without text |
| review_date | date | Yes | Calendar date the review was published | Must be a valid date |
| location_id | string | No | Provider-specific identifier for the business location being reviewed | Max: 255 |
| metadata | map | No | Provider-specific supplemental fields (e.g., reply text, language code) | Defaults to empty map |
| user_id | integer | Yes | Foreign key to users table for multi-tenant scoping | References users.id |
| inserted_at | utc_datetime_usec | Yes (auto) | Timestamp when record was created | Auto-generated |
| updated_at | utc_datetime_usec | Yes (auto) | Timestamp when record was last updated | Auto-generated |

## Functions

### changeset/2

Creates an Ecto changeset for creating or updating a Review record. Validates all required fields, type constraints, and enforces the association constraints on user and integration.

```elixir
@spec changeset(Review.t(), map()) :: Ecto.Changeset.t()
```

**Process**:
1. Cast attributes: integration_id, user_id, provider, external_review_id, reviewer_name, star_rating, comment, review_date, location_id, metadata
2. Validate required fields: integration_id, user_id, provider, external_review_id, star_rating, review_date
3. Validate star_rating is an integer between 1 and 5 inclusive
4. Validate metadata is a map when present
5. Add association constraint on user (ensures referenced user exists)
6. Add association constraint on integration (ensures referenced integration exists)
7. Return changeset with validations applied

**Test Assertions**:
- Creates valid changeset with all required fields
- Casts each field attribute correctly (integration_id, user_id, provider, external_review_id, reviewer_name, star_rating, comment, review_date, location_id, metadata)
- Validates integration_id is required
- Validates user_id is required
- Validates provider is required
- Validates external_review_id is required
- Validates star_rating is required
- Validates review_date is required
- Rejects star_rating below 1
- Rejects star_rating above 5
- Accepts star_rating of exactly 1 (lower boundary)
- Accepts star_rating of exactly 5 (upper boundary)
- Allows nil reviewer_name (optional field)
- Allows nil comment (optional field)
- Allows nil location_id (optional field)
- Allows nil metadata (defaults to empty map)
- Validates metadata is a map when provided
- Rejects metadata when not a map
- Rejects metadata when it is a list
- Accepts all valid provider enum values (:google_business)
- Rejects unknown provider values
- Validates user association exists (assoc_constraint triggers on insert)
- Validates integration association exists (assoc_constraint triggers on insert)
- Creates valid changeset for updating existing review
- Preserves existing fields when updating subset of attributes
- Handles empty attributes map gracefully

## Dependencies

- Ecto.Schema
- Ecto.Changeset
- MetricFlow.Integrations.Integration
- MetricFlow.Users.User
