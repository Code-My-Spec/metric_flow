# MetricFlow.Ai.SuggestionFeedback

User feedback on AI-generated suggestions (insights). Each record captures whether a user found a suggestion helpful or not, along with an optional free-text comment. Enforces a unique constraint on `[insight_id, user_id]` so each user submits at most one feedback record per insight. The context layer upserts on this constraint to allow users to change their rating.

## Type

schema

## Fields

| Field        | Type            | Required   | Description                                              | Constraints                                              |
| ------------ | --------------- | ---------- | -------------------------------------------------------- | -------------------------------------------------------- |
| id           | integer         | Yes (auto) | Primary key                                              | Auto-generated                                           |
| insight_id   | integer         | Yes        | Foreign key to the insight being rated                   | References ai_insights.id; assoc constraint              |
| user_id      | integer         | Yes        | Foreign key to the user submitting feedback              | References users.id; assoc constraint                    |
| rating       | enum (atom)     | Yes        | User rating: `:helpful` or `:not_helpful`                | Values: [:helpful, :not_helpful]; no other values valid  |
| comment      | string          | No         | Optional free-text elaboration on the rating             | Max: 1000 characters; defaults to nil                   |
| inserted_at  | utc_datetime_usec | Yes (auto) | Timestamp of record creation                           | Auto-generated                                           |
| updated_at   | utc_datetime_usec | Yes (auto) | Timestamp of last update                               | Auto-generated                                           |

### Associations

- `belongs_to :insight, MetricFlow.Ai.Insight` - The AI-generated insight being rated
- `belongs_to :user, MetricFlow.Users.User` - The user who submitted the feedback

### Unique Constraint

A composite unique constraint on `[insight_id, user_id]` (index name: `suggestion_feedback_insight_id_user_id_index`) ensures each user rates a given insight at most once. The context layer handles updates by upserting on this constraint rather than inserting a new record.

### Rating Enum State Transitions

The `rating` field accepts exactly two values:
- `:helpful` - user found the suggestion useful
- `:not_helpful` - user did not find the suggestion useful

A user may change their rating by submitting new feedback; the context performs an upsert on the unique constraint, replacing the existing record's `rating` and `comment`.

## Functions

### changeset/2

Builds and validates a changeset for creating or updating a SuggestionFeedback record.

```elixir
@spec changeset(t(), map()) :: Ecto.Changeset.t()
```

**Process**:
1. Cast `[:insight_id, :user_id, :rating, :comment]` from attrs
2. Validate that `[:insight_id, :user_id, :rating]` are present (required)
3. Validate `comment` length is at most 1000 characters
4. Apply `assoc_constraint` on `:insight` to enforce referential integrity at the database level
5. Apply `assoc_constraint` on `:user` to enforce referential integrity at the database level
6. Apply `unique_constraint` on `[:insight_id, :user_id]` using index name `suggestion_feedback_insight_id_user_id_index`

**Test Assertions**:
- returns a valid changeset when all required fields are present with a `:helpful` rating
- returns a valid changeset when rating is `:not_helpful`
- returns invalid changeset when `insight_id` is missing, with error on `insight_id`
- returns invalid changeset when `user_id` is missing, with error on `user_id`
- returns invalid changeset when `rating` is missing, with error on `rating`
- returns invalid changeset when `rating` is an unrecognised atom (not in enum values)
- returns valid changeset when `comment` is nil (field is optional)
- returns valid changeset when `comment` is exactly 1000 characters
- returns invalid changeset when `comment` exceeds 1000 characters, with error on `comment`
- raises assoc constraint error on insert when `insight_id` does not reference an existing insight
- raises assoc constraint error on insert when `user_id` does not reference an existing user
- raises unique constraint error on insert when the same `[insight_id, user_id]` pair already exists
- returns valid changeset when the same `insight_id` is used with a different `user_id`
- returns valid changeset when the same `user_id` is used with a different `insight_id`

### helpful?/1

Returns whether the feedback record represents a positive (helpful) rating.

```elixir
@spec helpful?(t()) :: boolean()
```

**Process**:
1. Pattern-match on the `rating` field of the given `SuggestionFeedback` struct
2. Return `true` if `rating` is `:helpful`
3. Return `false` for any other rating value (including `:not_helpful`)

**Test Assertions**:
- returns `true` when rating is `:helpful`
- returns `false` when rating is `:not_helpful`

## Dependencies

- MetricFlow.Ai.Insight
- MetricFlow.Users.User
