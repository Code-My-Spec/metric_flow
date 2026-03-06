defmodule MetricFlow.Ai.AiRepository do
  @moduledoc """
  Data access layer for all Ai context CRUD operations.

  All queries are scoped by account_id and/or user_id via the Scope struct for
  multi-tenant isolation. Provides CRUD for Insight, ChatSession, ChatMessage,
  and SuggestionFeedback records with filtering and ordering.
  """

  import Ecto.Query

  alias MetricFlow.Accounts
  alias MetricFlow.Ai.ChatMessage
  alias MetricFlow.Ai.ChatSession
  alias MetricFlow.Ai.Insight
  alias MetricFlow.Ai.SuggestionFeedback
  alias MetricFlow.Repo
  alias MetricFlow.Users.Scope

  # ---------------------------------------------------------------------------
  # Insight operations
  # ---------------------------------------------------------------------------

  @doc """
  Lists AI insights for the scoped account with optional filtering and pagination.

  Options:
  - suggestion_type: atom — filters by suggestion type
  - correlation_result_id: integer — filters by correlation result
  - limit: integer — maximum number of results
  - offset: integer — number of records to skip

  Results are ordered by generated_at descending (most recent first).
  """
  @spec list_insights(Scope.t(), keyword()) :: list(Insight.t())
  def list_insights(%Scope{} = scope, opts \\ []) do
    account_id = get_account_id(scope)

    Insight
    |> where(account_id: ^account_id)
    |> maybe_filter_suggestion_type(Keyword.get(opts, :suggestion_type))
    |> maybe_filter_correlation_result(Keyword.get(opts, :correlation_result_id))
    |> order_by([i], desc: i.generated_at)
    |> maybe_limit(Keyword.get(opts, :limit))
    |> maybe_offset(Keyword.get(opts, :offset))
    |> Repo.all()
  end

  @doc """
  Retrieves a specific insight by ID, scoped to the account.

  Returns {:ok, insight} when found or {:error, :not_found} when the insight
  does not exist or belongs to a different account.
  """
  @spec get_insight(Scope.t(), integer()) :: {:ok, Insight.t()} | {:error, :not_found}
  def get_insight(%Scope{} = scope, id) do
    account_id = get_account_id(scope)

    case Repo.get_by(Insight, id: id, account_id: account_id) do
      nil -> {:error, :not_found}
      insight -> {:ok, insight}
    end
  end

  @doc """
  Creates a new Insight record with the account_id taken from the Scope.

  Returns {:ok, insight} on success or {:error, changeset} on validation failure.
  """
  @spec create_insight(Scope.t(), map()) :: {:ok, Insight.t()} | {:error, Ecto.Changeset.t()}
  def create_insight(%Scope{} = scope, attrs) do
    account_id = get_account_id(scope)

    %Insight{}
    |> Insight.changeset(Map.put(attrs, :account_id, account_id))
    |> Repo.insert()
  end

  # ---------------------------------------------------------------------------
  # ChatSession operations
  # ---------------------------------------------------------------------------

  @doc """
  Lists all chat sessions for the user from Scope, ordered by most recently updated.
  """
  @spec list_chat_sessions(Scope.t()) :: list(ChatSession.t())
  def list_chat_sessions(%Scope{user: user}) do
    ChatSession
    |> where(user_id: ^user.id)
    |> order_by([s], desc: s.updated_at)
    |> Repo.all()
  end

  @doc """
  Retrieves a specific chat session with all messages preloaded, scoped to the user.

  Messages are ordered by inserted_at ascending to preserve chronological order.
  Returns {:ok, session} when found or {:error, :not_found} when the session
  does not exist or belongs to a different user.
  """
  @spec get_chat_session(Scope.t(), integer()) ::
          {:ok, ChatSession.t()} | {:error, :not_found}
  def get_chat_session(%Scope{user: user}, id) do
    case Repo.get_by(ChatSession, id: id, user_id: user.id) do
      nil ->
        {:error, :not_found}

      session ->
        messages_query = from(m in ChatMessage, order_by: [asc: m.inserted_at])
        loaded = Repo.preload(session, chat_messages: messages_query)
        {:ok, loaded}
    end
  end

  @doc """
  Creates a new ChatSession with user_id and account_id from Scope.

  Returns {:ok, session} on success or {:error, changeset} on validation failure.
  """
  @spec create_chat_session(Scope.t(), map()) ::
          {:ok, ChatSession.t()} | {:error, Ecto.Changeset.t()}
  def create_chat_session(%Scope{user: user} = scope, attrs) do
    account_id = get_account_id(scope)

    merged = attrs |> Map.put(:user_id, user.id) |> Map.put(:account_id, account_id)

    %ChatSession{}
    |> ChatSession.changeset(merged)
    |> Repo.insert()
  end

  @doc """
  Updates an existing ChatSession record (e.g., title, status).

  Returns {:ok, updated_session} on success or {:error, changeset} on validation failure.
  """
  @spec update_chat_session(Scope.t(), ChatSession.t(), map()) ::
          {:ok, ChatSession.t()} | {:error, Ecto.Changeset.t()}
  def update_chat_session(%Scope{}, %ChatSession{} = session, attrs) do
    session
    |> ChatSession.changeset(attrs)
    |> Repo.update()
  end

  # ---------------------------------------------------------------------------
  # ChatMessage operations
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new ChatMessage record.

  Returns {:ok, message} on success or {:error, changeset} on validation failure.
  """
  @spec create_chat_message(Scope.t(), map()) ::
          {:ok, ChatMessage.t()} | {:error, Ecto.Changeset.t()}
  def create_chat_message(%Scope{}, attrs) do
    %ChatMessage{}
    |> ChatMessage.changeset(attrs)
    |> Repo.insert()
  end

  # ---------------------------------------------------------------------------
  # SuggestionFeedback operations
  # ---------------------------------------------------------------------------

  @doc """
  Upserts user feedback for an insight.

  Uses on_conflict update on [insight_id, user_id] so a user can change their
  rating. Returns {:ok, feedback} on success or {:error, changeset} on failure.
  """
  @spec upsert_feedback(Scope.t(), integer(), map()) ::
          {:ok, SuggestionFeedback.t()} | {:error, Ecto.Changeset.t()}
  def upsert_feedback(%Scope{user: user}, insight_id, attrs) do
    merged = attrs |> Map.put(:user_id, user.id) |> Map.put(:insight_id, insight_id)

    %SuggestionFeedback{}
    |> SuggestionFeedback.changeset(merged)
    |> Repo.insert(
      on_conflict: {:replace, [:rating, :comment]},
      conflict_target: [:insight_id, :user_id]
    )
  end

  @doc """
  Gets the current user's feedback for a specific insight.

  Returns the SuggestionFeedback struct or nil when no feedback has been submitted.
  """
  @spec get_feedback_for_insight(Scope.t(), integer()) :: SuggestionFeedback.t() | nil
  def get_feedback_for_insight(%Scope{user: user}, insight_id) do
    Repo.get_by(SuggestionFeedback, insight_id: insight_id, user_id: user.id)
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp get_account_id(%Scope{} = scope) do
    Accounts.get_personal_account_id(scope)
  end

  defp maybe_filter_suggestion_type(query, nil), do: query
  defp maybe_filter_suggestion_type(query, type), do: where(query, suggestion_type: ^type)

  defp maybe_filter_correlation_result(query, nil), do: query

  defp maybe_filter_correlation_result(query, id) do
    where(query, correlation_result_id: ^id)
  end

  defp maybe_limit(query, nil), do: query
  defp maybe_limit(query, lim), do: limit(query, ^lim)

  defp maybe_offset(query, nil), do: query
  defp maybe_offset(query, off), do: offset(query, ^off)
end
