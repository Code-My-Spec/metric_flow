# MetricFlow.Ai.AiRepository

Data access layer for all Ai context CRUD operations. All queries are scoped by account_id and/or user_id via the Scope struct for multi-tenant isolation. Provides CRUD for Insight, ChatSession, ChatMessage, and SuggestionFeedback records with filtering and ordering.

## Type

module

## Functions

### list_insights/2

Lists AI insights for the scoped account with optional filtering and pagination.

```elixir
@spec list_insights(Scope.t(), keyword()) :: list(Insight.t())
```

**Process**:
1. Extract account_id from Scope
2. Build base query on Insight scoped by account_id
3. Apply optional filter: suggestion_type when provided
4. Apply optional filter: correlation_result_id when provided
5. Apply limit and offset when provided
6. Order by generated_at descending (most recent first)
7. Execute query and return list

**Test Assertions**:
- returns list of insights scoped to account
- returns empty list when no insights exist for account
- filters by suggestion_type when option provided
- filters by correlation_result_id when option provided
- orders by generated_at descending
- applies limit and offset correctly
- does not return insights from other accounts

### get_insight/2

Retrieves a specific insight by ID, scoped to the account.

```elixir
@spec get_insight(Scope.t(), integer()) :: {:ok, Insight.t()} | {:error, :not_found}
```

**Process**:
1. Extract account_id from Scope
2. Query Insight by id and account_id
3. Return ok tuple with insight when found
4. Return error :not_found when no matching record exists

**Test Assertions**:
- returns ok tuple with insight when found
- returns error :not_found when insight does not exist
- returns error :not_found when insight belongs to a different account

### create_insight/2

Creates a new Insight record with the account_id taken from the Scope.

```elixir
@spec create_insight(Scope.t(), map()) :: {:ok, Insight.t()} | {:error, Ecto.Changeset.t()}
```

**Process**:
1. Extract account_id from Scope
2. Merge account_id into attrs
3. Build Insight changeset with merged attrs
4. Insert into database with Repo.insert()
5. Return ok tuple with created Insight or error with changeset

**Test Assertions**:
- returns ok tuple with created insight on success
- sets account_id from Scope
- stores content, summary, and suggestion_type from attrs
- stores optional correlation_result_id when provided
- stores confidence value from attrs
- returns error changeset when required fields are missing
- returns error changeset when suggestion_type is invalid
- returns error changeset when confidence is outside the 0.0–1.0 range

### list_chat_sessions/1

Lists all chat sessions for the user from Scope, ordered by most recently updated.

```elixir
@spec list_chat_sessions(Scope.t()) :: list(ChatSession.t())
```

**Process**:
1. Extract user_id from Scope
2. Build query on ChatSession scoped by user_id
3. Order by updated_at descending
4. Execute query and return list

**Test Assertions**:
- returns list of chat sessions for scoped user
- returns empty list when user has no sessions
- orders by updated_at descending
- does not return sessions belonging to other users

### get_chat_session/2

Retrieves a specific chat session with all messages preloaded, scoped to the user.

```elixir
@spec get_chat_session(Scope.t(), integer()) :: {:ok, ChatSession.t()} | {:error, :not_found}
```

**Process**:
1. Extract user_id from Scope
2. Query ChatSession by id and user_id
3. Return error :not_found when no matching record exists
4. Preload messages association ordered by inserted_at ascending
5. Return ok tuple with the session and its messages

**Test Assertions**:
- returns ok tuple with ChatSession when found
- preloads messages ordered by inserted_at ascending
- returns error :not_found when session does not exist
- returns error :not_found when session belongs to a different user

### create_chat_session/2

Creates a new ChatSession with user_id and account_id from Scope.

```elixir
@spec create_chat_session(Scope.t(), map()) :: {:ok, ChatSession.t()} | {:error, Ecto.Changeset.t()}
```

**Process**:
1. Extract user_id and account_id from Scope
2. Merge user_id and account_id into attrs
3. Build ChatSession changeset with merged attrs
4. Insert into database with Repo.insert()
5. Return ok tuple with created ChatSession or error with changeset

**Test Assertions**:
- returns ok tuple with ChatSession on success
- sets user_id from Scope
- sets account_id from Scope
- stores context_type from attrs
- allows optional context_id to be nil
- stores context_id when provided
- returns error changeset when context_type is invalid
- returns error changeset when required fields are missing

### update_chat_session/3

Updates an existing ChatSession record (e.g., title, status).

```elixir
@spec update_chat_session(Scope.t(), ChatSession.t(), map()) :: {:ok, ChatSession.t()} | {:error, Ecto.Changeset.t()}
```

**Process**:
1. Build ChatSession changeset from the given session struct and attrs
2. Update the record in the database with Repo.update()
3. Return ok tuple with the updated ChatSession or error with changeset

**Test Assertions**:
- returns ok tuple with updated session on success
- updates title field
- updates status field
- returns error changeset when status is invalid

### create_chat_message/2

Creates a new ChatMessage record.

```elixir
@spec create_chat_message(Scope.t(), map()) :: {:ok, ChatMessage.t()} | {:error, Ecto.Changeset.t()}
```

**Process**:
1. Build ChatMessage changeset with attrs
2. Insert into database with Repo.insert()
3. Return ok tuple with created ChatMessage or error with changeset

**Test Assertions**:
- returns ok tuple with ChatMessage on success
- stores chat_session_id, role, and content from attrs
- stores optional token_count when provided
- returns error changeset when role is invalid
- returns error changeset when required fields are missing

### upsert_feedback/3

Upserts user feedback for an insight. Uses on_conflict update on [insight_id, user_id] so a user can change their rating.

```elixir
@spec upsert_feedback(Scope.t(), integer(), map()) :: {:ok, SuggestionFeedback.t()} | {:error, Ecto.Changeset.t()}
```

**Process**:
1. Extract user_id from Scope
2. Merge user_id and insight_id into attrs
3. Build SuggestionFeedback changeset with merged attrs
4. Insert with on_conflict: {:replace, [:rating, :comment]}, conflict_target: [:insight_id, :user_id]
5. Return ok tuple with persisted SuggestionFeedback or error with changeset

**Test Assertions**:
- returns ok tuple with SuggestionFeedback on success
- creates new feedback when none exists for the user and insight
- updates rating and comment when feedback already exists for the user and insight
- sets user_id from Scope
- stores insight_id from the second argument
- allows nil comment
- returns error changeset when rating is invalid

### get_feedback_for_insight/2

Gets the current user's feedback for a specific insight. Returns nil when no feedback has been submitted.

```elixir
@spec get_feedback_for_insight(Scope.t(), integer()) :: SuggestionFeedback.t() | nil
```

**Process**:
1. Extract user_id from Scope
2. Query SuggestionFeedback by insight_id and user_id
3. Execute query with Repo.one()
4. Return the feedback struct or nil

**Test Assertions**:
- returns SuggestionFeedback when the user has submitted feedback for the insight
- returns nil when the user has not submitted feedback for the insight
- returns nil when the insight does not exist
- does not return feedback submitted by other users

## Dependencies

- None
