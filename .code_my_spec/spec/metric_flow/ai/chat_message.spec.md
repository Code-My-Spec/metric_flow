# MetricFlow.Ai.ChatMessage

Individual message: session_id, role, content

## Type

schema

## Fields

| Field            | Type         | Required   | Description                                                                 | Constraints                                     |
| ---------------- | ------------ | ---------- | --------------------------------------------------------------------------- | ----------------------------------------------- |
| id               | integer      | Yes (auto) | Primary key                                                                 | Auto-generated                                  |
| chat_session_id  | integer      | Yes        | Foreign key to the owning chat session                                      | References chat_sessions.id                     |
| role             | enum         | Yes        | Author of the message: :user, :assistant, or :system                       | One of: user, assistant, system                 |
| content          | string       | Yes        | Text body of the message                                                    | Min length: 1 (blank strings rejected)          |
| token_count      | integer      | No         | Number of tokens consumed; populated for :assistant messages after streaming completes | nil for :user and :system messages |
| inserted_at      | utc_datetime | Yes (auto) | Immutable creation timestamp (microsecond precision)                        | Auto-generated; no updated_at column            |

### Associations

- belongs_to :chat_session — each message belongs to exactly one ChatSession and must not be reused across sessions.

### Role Semantics

- **:user** — message authored by the human user. token_count is always nil.
- **:assistant** — message produced by the LLM. token_count is populated after streaming completes with the final token count.
- **:system** — injected at the start of every conversation to supply the LLM with marketing analytics context. token_count is nil.

### Ordering

Messages within a session are ordered by inserted_at ascending to replay the conversation in chronological sequence. No updated_at column is present; messages are immutable once persisted.

## Functions

### changeset/2

Creates an Ecto changeset for inserting a new ChatMessage record. Used for both user-submitted messages and internally constructed system or assistant messages.

```elixir
@spec changeset(t(), map()) :: Ecto.Changeset.t()
```

**Process**:
1. Cast the permitted fields: chat_session_id, role, content, token_count
2. Validate that chat_session_id, role, and content are all present (validate_required)
3. Validate content has a minimum length of 1, rejecting blank strings
4. Add an assoc_constraint on :chat_session so that inserting a message with a non-existent session_id returns a database-level "does not exist" error rather than a raw constraint violation

**Test Assertions**:
- returns a valid changeset for a :user message with chat_session_id, role, and content
- returns a valid changeset for an :assistant message that includes token_count
- returns a valid changeset for a :system message
- returns an invalid changeset when chat_session_id is missing (error on :chat_session_id)
- returns an invalid changeset when role is missing (error on :role)
- returns an invalid changeset when content is missing (error on :content)
- returns an invalid changeset when content is an empty string (error on :content)
- returns an invalid changeset when role is not one of the permitted enum values
- allows nil token_count for :user messages
- allows nil token_count for :system messages
- accepts an integer token_count for :assistant messages and preserves the value
- triggers the assoc_constraint error ("does not exist") on Repo.insert when chat_session_id references a non-existent session

## Dependencies

- MetricFlow.Ai.ChatSession
