# MetricFlow.Ai.ChatSession

Chat conversation tied to a user and account, with optional contextual focus on a specific correlation result, metric, or dashboard.

## Type

schema

## Fields

| Field        | Type     | Required   | Description                                                                                      | Constraints                                                  |
| ------------ | -------- | ---------- | ------------------------------------------------------------------------------------------------ | ------------------------------------------------------------ |
| id           | integer  | Yes (auto) | Primary key                                                                                      | Auto-generated                                               |
| user_id      | integer  | Yes        | Foreign key to the user who owns this session                                                    | References users.id                                          |
| account_id   | integer  | Yes        | Foreign key to the account this session belongs to                                               | References accounts.id                                       |
| title        | string   | No         | Human-readable session label; nil at creation, set after the first user message                  | Max: 255                                                     |
| context_type | enum     | Yes        | Scope of the AI conversation: :general, :correlation, :metric, or :dashboard                    | One of: general, correlation, metric, dashboard              |
| context_id   | integer  | No         | ID of the focused resource; must be nil when context_type is :general                            | May be set only when context_type is correlation/metric/dashboard |
| status       | enum     | Yes (auto) | Lifecycle state of the session; defaults to :active on creation                                  | One of: active, archived; default: active                    |
| inserted_at  | datetime | Yes (auto) | UTC timestamp of record creation                                                                 | Auto-generated, utc_datetime_usec                            |
| updated_at   | datetime | Yes (auto) | UTC timestamp of last update                                                                     | Auto-generated, utc_datetime_usec                            |

### Associations

- `belongs_to :user` — the user who owns the session (MetricFlow.Users.User)
- `belongs_to :account` — the account the session is scoped to (MetricFlow.Accounts.Account)
- `has_many :chat_messages` — ordered ascending by inserted_at to preserve conversation chronology (MetricFlow.Ai.ChatMessage)

### State Transitions

- `:active` -> `:archived`: user archives the session; this transition is irreversible

### Business Rules

- `context_id` must be nil when `context_type` is `:general`
- `context_id` may be set when `context_type` is `:correlation`, `:metric`, or `:dashboard`
- `title` is optional at creation; it is expected to be populated after the first user message is received

## Functions

### changeset/2

Creates an Ecto changeset for inserting or updating a ChatSession record. Casts all permitted fields, validates required fields, enforces the title length limit, and adds association constraints on user and account.

```elixir
@spec changeset(t(), map()) :: Ecto.Changeset.t()
```

**Process**:
1. Cast the following fields from attrs: `user_id`, `account_id`, `title`, `context_type`, `context_id`, `status`
2. Validate that `user_id`, `account_id`, and `context_type` are present
3. Validate `title` length does not exceed 255 characters
4. Add `assoc_constraint` on `:user` so that a missing foreign key is surfaced as a user-facing error on insert
5. Add `assoc_constraint` on `:account` so that a missing foreign key is surfaced as a user-facing error on insert

**Test Assertions**:
- returns a valid changeset when all required fields are provided
- defaults status to `:active` when status is not included in attrs
- accepts explicit status of `:active`
- accepts explicit status of `:archived`
- rejects invalid status values with an error on `:status`
- returns an invalid changeset when `user_id` is missing
- returns an invalid changeset when `account_id` is missing
- returns an invalid changeset when `context_type` is missing
- rejects unknown `context_type` values
- accepts all valid `context_type` values: `:general`, `:correlation`, `:metric`, `:dashboard`
- allows a nil `title`
- accepts a title of exactly 255 characters
- rejects a title exceeding 255 characters with an error on `:title`
- allows a nil `context_id`
- accepts a `context_id` when `context_type` is `:correlation`
- accepts a `context_id` when `context_type` is `:metric`
- accepts a `context_id` when `context_type` is `:dashboard`
- surfaces a user-facing error on `:user` when the referenced user does not exist (assoc_constraint evaluated at insert time)
- surfaces a user-facing error on `:account` when the referenced account does not exist (assoc_constraint evaluated at insert time)

### archive_changeset/1

Creates an Ecto changeset that transitions a ChatSession from `:active` to `:archived`. Guards against archiving an already-archived session and returns an invalid changeset when the precondition is not met.

```elixir
@spec archive_changeset(t()) :: Ecto.Changeset.t()
```

**Process**:
1. Build a bare changeset from the given `%ChatSession{}` struct using `Ecto.Changeset.change/1`
2. Check whether the current `status` field on the struct is `:active`; if not, add an error on `:status` with message "must be active to archive"
3. Put the change `status: :archived` on the changeset

**Test Assertions**:
- returns a valid changeset with `status` changed to `:archived` when the session is currently `:active`
- returns an invalid changeset with an error on `:status` when the session is already `:archived`
- does not require any additional attributes to be passed

## Dependencies

- MetricFlow.Accounts.Account
- MetricFlow.Ai.ChatMessage
- MetricFlow.Users.User
