# MetricFlow.Reviews.ReviewRepository

Data access layer for Review CRUD and query operations. All queries are scoped via Scope struct for multi-tenant isolation. Provides create_reviews/2 for bulk upsert (deduplicates on external_review_id), list_reviews/2 with filter options (provider, location_id, date_range, limit, offset), count_reviews/1 for total count, and delete_reviews_by_provider/2.

## Type

module

## Dependencies

- MetricFlow.Reviews.Review
- MetricFlow.Repo
- MetricFlow.Users.Scope

## Functions

### list_reviews/2

Returns a list of reviews for the scoped user, with optional filtering and pagination.

```elixir
@spec list_reviews(Scope.t(), keyword()) :: list(Review.t())
```

**Process**:
1. Base query scoped to user_id from Scope
2. Apply optional filters: provider, location_id, date_range {start_date, end_date}
3. Apply optional limit (default 10) and offset (default 0)
4. Order by review_date descending
5. Return list of Review structs

**Test Assertions**:
- returns all reviews for the user when no options given
- filters by provider when provider option is provided
- filters by location_id when location_id option is provided
- filters by date_range when date_range option is provided
- respects limit option
- respects offset option for pagination
- returns reviews ordered by review_date descending
- does not return reviews belonging to other users
- returns empty list when no reviews exist for the user

### get_review/2

Fetches a single review by ID, scoped to the current user.

```elixir
@spec get_review(Scope.t(), integer()) :: Review.t() | nil
```

**Process**:
1. Query reviews table for the given id scoped to user_id from Scope
2. Return the Review struct if found, nil otherwise

**Test Assertions**:
- returns the review when it exists and belongs to the user
- returns nil when the review does not exist
- returns nil when the review belongs to a different user

### create_reviews/2

Bulk upserts a list of review attribute maps. Deduplicates on external_review_id so re-syncing the same reviews is idempotent.

```elixir
@spec create_reviews(Scope.t(), list(map())) :: {:ok, list(Review.t())} | {:error, Ecto.Changeset.t()}
```

**Process**:
1. For each attribute map, build a changeset via Review.changeset/2 with user_id from Scope
2. Insert all records using Repo.insert_all with on_conflict: :replace_all, conflict_target: :external_review_id
3. Return {:ok, inserted_reviews} on success
4. Return {:error, changeset} if any changeset is invalid

**Test Assertions**:
- inserts new reviews successfully
- returns {:ok, reviews} with the inserted records
- deduplicates on external_review_id (upserts existing records)
- does not insert reviews with invalid attributes
- returns {:error, changeset} when any changeset is invalid
- sets user_id from Scope on all inserted records

### count_reviews/1

Returns the total number of reviews for the scoped user across all providers.

```elixir
@spec count_reviews(Scope.t()) :: non_neg_integer()
```

**Process**:
1. Count all review records scoped to user_id from Scope
2. Return the integer count

**Test Assertions**:
- returns 0 when no reviews exist for the user
- returns the correct count across all providers
- does not count reviews belonging to other users

### delete_reviews_by_provider/2

Deletes all reviews for the scoped user belonging to the given provider.

```elixir
@spec delete_reviews_by_provider(Scope.t(), atom()) :: {:ok, non_neg_integer()}
```

**Process**:
1. Delete all review records matching user_id from Scope and the given provider
2. Return {:ok, count} where count is the number of deleted records

**Test Assertions**:
- deletes all reviews for the given provider and user
- returns {:ok, count} with the number of deleted records
- does not delete reviews for other providers
- does not delete reviews belonging to other users
- returns {:ok, 0} when no reviews exist for the provider
