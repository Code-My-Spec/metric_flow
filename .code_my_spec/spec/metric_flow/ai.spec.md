# MetricFlow.Ai

Public API boundary for the Ai bounded context.

Provides AI-powered features for MetricFlow: generating actionable insights from correlation data, conversational chat for data exploration, and Vega-Lite v5 visualization generation from natural language descriptions.

All public functions accept a `%Scope{}` as the first parameter for multi-tenant isolation.

## Type

context

## Delegates

- list_insights/2: MetricFlow.Ai.AiRepository.list_insights/2
- get_insight/2: MetricFlow.Ai.AiRepository.get_insight/2
- list_chat_sessions/1: MetricFlow.Ai.AiRepository.list_chat_sessions/1
- get_chat_session/2: MetricFlow.Ai.AiRepository.get_chat_session/2
- get_feedback_for_insight/2: MetricFlow.Ai.AiRepository.get_feedback_for_insight/2

## Functions

### submit_feedback/3

Records user feedback on a specific insight. Upserts on the unique `[insight_id, user_id]` constraint so a user can change their rating.

```elixir
@spec submit_feedback(Scope.t(), integer(), map()) ::
        {:ok, MetricFlow.Ai.SuggestionFeedback.t()} | {:error, :not_found | Ecto.Changeset.t()}
```

**Process**:
1. Call `AiRepository.get_insight/2` to verify the insight exists and belongs to the scoped account
2. Return `{:error, :not_found}` when the insight is not found
3. Call `AiRepository.upsert_feedback/3` with the scope, insight_id, and attrs
4. Return the ok or error tuple from the upsert

**Test Assertions**:
- returns ok tuple with SuggestionFeedback on success
- creates new feedback record when none exists for the user and insight
- updates existing feedback record when user changes their rating
- stores the user_id from the scope, not from attrs
- returns error :not_found when insight does not exist
- returns error :not_found when insight belongs to a different account
- returns error changeset when rating is invalid
- allows nil comment

### create_chat_session/2

Creates a new chat session for the scoped user with a context type and optional context_id. Defaults status to `:active` and generates a title from the context_type when no title is supplied.

```elixir
@spec create_chat_session(Scope.t(), map()) ::
        {:ok, MetricFlow.Ai.ChatSession.t()} | {:error, Ecto.Changeset.t()}
```

**Process**:
1. Merge `:status` default of `:active` into attrs when not already present
2. Merge a default `:title` derived from `context_type` when not already present
3. Call `AiRepository.create_chat_session/2` with the merged attrs
4. Return the ok or error tuple from the repository

**Test Assertions**:
- returns ok tuple with ChatSession on success
- sets user_id from scope
- sets account_id from scope
- sets status to :active
- sets context_type from attrs
- allows optional context_id to be nil
- stores context_id when provided
- returns error changeset when context_type is invalid
- returns error changeset when required fields are missing

### generate_insights/3

Generates AI insights for a completed correlation job. Loads correlation results, delegates to InsightsGenerator for LLM processing, and persists the returned Insight records.

```elixir
@spec generate_insights(Scope.t(), integer(), keyword()) ::
        {:ok, list(MetricFlow.Ai.Insight.t())} | {:error, term()}
```

**Process**:
1. Load the correlation job via `Correlations.get_correlation_job/2` — return `{:error, :not_found}` when the job does not exist or belongs to another account
2. Verify the job status is `:completed` — return `{:error, :job_not_complete}` otherwise
3. Load correlation results via `Correlations.list_correlation_results/1` — return `{:error, :no_results}` when the list is empty
4. Build a `correlation_data` map containing the results array and the job's data window dates
5. Extract a deduplicated list of metric names from the results
6. Call `InsightsGenerator.generate/3` with the correlation data, metric names, and opts — propagate any error tuple returned
7. Persist each returned insight attrs map as an Insight record via `AiRepository.create_insight/2`, stamping `generated_at` with the current UTC time
8. Return `{:ok, insights}` with the list of persisted Insight structs

**Test Assertions**:
- returns ok tuple with list of Insight structs on success
- persists one Insight per structured response item returned by InsightsGenerator
- links each insight to the account_id from the scope
- returns error :not_found when correlation job does not exist
- returns error :not_found when correlation job belongs to a different account
- returns error :job_not_complete when job status is not :completed
- returns error :no_results when the correlation job has no results
- propagates error tuple when InsightsGenerator returns an error

### generate_vega_spec/3

Generates a Vega-Lite v5 visualization specification from a natural language prompt. Fetches the available metric names for the scoped account and passes them to ReportGenerator, then validates that the returned map contains the required Vega-Lite fields.

```elixir
@spec generate_vega_spec(Scope.t(), String.t(), keyword()) ::
        {:ok, map()} | {:error, term()}
```

**Process**:
1. Retrieve available metric names for the scope via `Metrics.list_metric_names/1`
2. Call `ReportGenerator.generate/3` with the user prompt, metric names, and opts — propagate any error tuple returned
3. Validate the returned map contains the required fields: `"$schema"`, `"mark"`, and `"encoding"`
4. Return `{:ok, spec}` when all required fields are present, or `{:error, :invalid_vega_spec}` when any are missing

**Test Assertions**:
- returns ok tuple with Vega-Lite spec map on success
- returned spec map includes "$schema" pointing to the Vega-Lite v5 URL
- returned spec map includes mark and encoding keys
- passes available metric names from the scoped account to ReportGenerator
- returns error :invalid_vega_spec when returned map is missing required Vega-Lite fields
- propagates error tuple when ReportGenerator returns an error

### send_chat_message/4

Sends a user message in a chat session. Persists the user message synchronously, then spawns an async Task that streams the assistant response back to the caller process via messages.

```elixir
@spec send_chat_message(Scope.t(), integer(), String.t(), keyword()) ::
        {:ok, pid()} | {:error, :not_found | :session_archived}
```

**Process**:
1. Load the chat session via `AiRepository.get_chat_session/2` — return `{:error, :not_found}` when the session does not exist or belongs to a different user
2. Verify the session status is `:active` — return `{:error, :session_archived}` otherwise
3. Persist the user message via `AiRepository.create_chat_message/2` with role `:user` and the provided content
4. Capture the caller pid with `self()`
5. Spawn a `Task.async/1` that will stream the assistant response
6. Inside the task: reload the full session (with messages preloaded), build the messages list for the LLM, invoke `LlmClient.stream_chat/3` (or the `stream_chat_fn` override from opts)
7. On streaming success: collect all content tokens, send each as `{:chat_token, text}` to the caller, persist the full assistant response as a ChatMessage with role `:assistant` and the computed token_count, then send `{:chat_complete, %{token_count: count}}` to the caller
8. On streaming error: send `{:chat_error, reason}` to the caller
9. Return `{:ok, task.pid}` immediately after spawning the task

**Test Assertions**:
- returns ok tuple with a pid immediately (does not block)
- persists a user ChatMessage before spawning the Task
- spawns a Task that streams tokens to the caller as :chat_token messages
- persists an assistant ChatMessage after the stream completes
- assistant ChatMessage content equals the concatenation of all streamed tokens
- assistant ChatMessage token_count equals the length of the full content string
- sends :chat_complete message with token_count to caller when streaming finishes
- sends :chat_error message to caller when LlmClient returns an error
- returns error :not_found when session does not exist
- returns error :not_found when session belongs to a different user
- returns error :session_archived when session status is :archived

## Dependencies

- MetricFlow.Metrics
- MetricFlow.Correlations
- MetricFlow.Users.Scope

## Components

### MetricFlow.Ai.Insight

Ecto schema representing an AI-generated insight. Stores the suggestion content, a short summary, a suggestion type (e.g., `:budget_increase`, `:optimization`), an optional link to a `correlation_result_id`, a confidence score in the 0.0–1.0 range, and the timestamp when the insight was generated. Scoped to an account via `account_id`.

### MetricFlow.Ai.SuggestionFeedback

Ecto schema recording a user's rating of an AI insight. Stores the rating (`:helpful` or `:not_helpful`), an optional free-text comment, and foreign keys to both the `insight_id` and the `user_id`. Enforces a unique constraint on `[insight_id, user_id]` so each user has at most one feedback record per insight.

### MetricFlow.Ai.ChatSession

Ecto schema representing a conversational session between a user and the AI. Stores the session title, status (`:active` or `:archived`), context type (e.g., `:general`, `:correlation`, `:dashboard`), and an optional `context_id` pointing to a related domain entity. Scoped to a user via `user_id` and to an account via `account_id`. Has a `has_many` relationship to ChatMessage records.

### MetricFlow.Ai.ChatMessage

Ecto schema representing a single message in a chat session. Stores the role (`:user` or `:assistant`), the text content, and an optional token count for assistant messages. Belongs to a ChatSession via `chat_session_id`.

### MetricFlow.Ai.AiRepository

Data access layer for all Ai context CRUD operations. All queries are scoped by `account_id` and/or `user_id` via the Scope struct for multi-tenant isolation. Provides CRUD for Insight, ChatSession, ChatMessage, and SuggestionFeedback records with filtering, ordering, and upsert support.

### MetricFlow.Ai.InsightsGenerator

Calls the LLM to analyse correlation data and return a structured list of insight attribute maps. Accepts a correlation data map, a list of metric names, and keyword opts. Returns `{:ok, list(map())}` on success or `{:error, term()}` on failure.

### MetricFlow.Ai.ReportGenerator

Calls the LLM to produce a Vega-Lite v5 JSON specification from a natural language prompt and a list of available metric names. Returns `{:ok, map()}` containing the parsed spec on success or `{:error, term()}` on failure.

### MetricFlow.Ai.LlmClient

Low-level HTTP client for the LLM provider API. Provides `stream_chat/3` for sending a conversation history and receiving a streaming response, and `base_system_prompt/0` for retrieving the shared system prompt string. Wraps Req and handles token streaming via server-sent events.
