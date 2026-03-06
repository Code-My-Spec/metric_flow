defmodule MetricFlowTest.AiFixtures do
  @moduledoc """
  Test helpers for creating entities in the Ai domain.

  All insert helpers bypass the AiRepository and write directly through Ecto
  schemas so the fixture layer remains independent of the module under test.

  Use `user_with_scope/0` to obtain a user, their personal account_id, and a
  populated Scope in a single call. The returned map has the keys :user,
  :account_id, and :scope.
  """

  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Accounts.AccountMember
  alias MetricFlow.Ai.ChatMessage
  alias MetricFlow.Ai.ChatSession
  alias MetricFlow.Ai.Insight
  alias MetricFlow.Ai.SuggestionFeedback
  alias MetricFlow.Correlations.CorrelationJob
  alias MetricFlow.Correlations.CorrelationResult
  alias MetricFlow.Repo
  alias MetricFlow.Users.Scope

  # ---------------------------------------------------------------------------
  # User + account + scope helpers
  # ---------------------------------------------------------------------------

  defp unique_slug, do: "account-#{System.unique_integer([:positive])}"

  @doc """
  Creates a confirmed user with their auto-created personal account.
  Returns {user, scope}.
  """
  def user_with_scope do
    user = user_fixture()
    create_personal_account!(user)
    scope = Scope.for_user(user)
    {user, scope}
  end

  defp create_personal_account!(user) do
    {:ok, account} =
      %Account{}
      |> Account.creation_changeset(%{
        name: "#{user.email} Personal",
        slug: unique_slug(),
        type: "personal",
        originator_user_id: user.id
      })
      |> Repo.insert()

    %AccountMember{}
    |> AccountMember.changeset(%{
      account_id: account.id,
      user_id: user.id,
      role: :owner
    })
    |> Repo.insert!()

    account
  end

  # ---------------------------------------------------------------------------
  # Insight fixtures
  # ---------------------------------------------------------------------------

  @doc """
  Returns a map of valid attributes for Insight.changeset/2.
  Requires an integer account_id from a persisted Account.
  """
  def valid_insight_attrs(account_id, overrides \\ %{}) do
    Map.merge(
      %{
        account_id: account_id,
        content: "Increasing budget on Google Ads campaigns targeting high-intent keywords could improve revenue.",
        summary: "Increase Google Ads budget to improve revenue",
        suggestion_type: :budget_increase,
        confidence: 0.85,
        generated_at: DateTime.utc_now()
      },
      overrides
    )
  end

  @doc """
  Creates and persists an Insight for the given account_id.
  Accepts optional attribute overrides.
  """
  def insert_insight!(account_id, overrides \\ %{}) do
    attrs = valid_insight_attrs(account_id, overrides)

    %Insight{}
    |> Insight.changeset(attrs)
    |> Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # ChatSession fixtures
  # ---------------------------------------------------------------------------

  @doc """
  Returns a map of valid attributes for ChatSession.changeset/2.
  Requires integer user_id and account_id from persisted records.
  """
  def valid_chat_session_attrs(user_id, account_id, overrides \\ %{}) do
    Map.merge(
      %{
        user_id: user_id,
        account_id: account_id,
        context_type: :general
      },
      overrides
    )
  end

  @doc """
  Creates and persists a ChatSession for the given user and account.
  Accepts optional attribute overrides.
  """
  def insert_chat_session!(user_id, account_id, overrides \\ %{}) do
    attrs = valid_chat_session_attrs(user_id, account_id, overrides)

    %ChatSession{}
    |> ChatSession.changeset(attrs)
    |> Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # ChatMessage fixtures
  # ---------------------------------------------------------------------------

  @doc """
  Returns a map of valid attributes for ChatMessage.changeset/2.
  Requires an integer chat_session_id from a persisted ChatSession.
  """
  def valid_chat_message_attrs(chat_session_id, overrides \\ %{}) do
    Map.merge(
      %{
        chat_session_id: chat_session_id,
        role: :user,
        content: "What metrics are driving revenue growth?"
      },
      overrides
    )
  end

  @doc """
  Creates and persists a ChatMessage for the given chat_session_id.
  Accepts optional attribute overrides.
  """
  def insert_chat_message!(chat_session_id, overrides \\ %{}) do
    attrs = valid_chat_message_attrs(chat_session_id, overrides)

    %ChatMessage{}
    |> ChatMessage.changeset(attrs)
    |> Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # SuggestionFeedback fixtures
  # ---------------------------------------------------------------------------

  @doc """
  Returns a map of valid attributes for SuggestionFeedback.changeset/2.
  Requires integer insight_id and user_id from persisted records.
  """
  def valid_suggestion_feedback_attrs(insight_id, user_id, overrides \\ %{}) do
    Map.merge(
      %{
        insight_id: insight_id,
        user_id: user_id,
        rating: :helpful
      },
      overrides
    )
  end

  @doc """
  Creates and persists a SuggestionFeedback for the given insight and user.
  Accepts optional attribute overrides.
  """
  def insert_suggestion_feedback!(insight_id, user_id, overrides \\ %{}) do
    attrs = valid_suggestion_feedback_attrs(insight_id, user_id, overrides)

    %SuggestionFeedback{}
    |> SuggestionFeedback.changeset(attrs)
    |> Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # CorrelationResult fixture (for linking to Insights)
  # ---------------------------------------------------------------------------

  @doc """
  Creates and persists a CorrelationResult (and its parent CorrelationJob)
  for the given account_id. Returns the CorrelationResult struct.
  """
  def insert_correlation_result!(account_id) do
    job =
      %CorrelationJob{}
      |> CorrelationJob.changeset(%{
        account_id: account_id,
        status: :completed,
        goal_metric_name: "revenue"
      })
      |> Repo.insert!()

    %CorrelationResult{}
    |> CorrelationResult.changeset(%{
      account_id: account_id,
      correlation_job_id: job.id,
      metric_name: "sessions",
      goal_metric_name: "revenue",
      coefficient: 0.85,
      optimal_lag: 3,
      data_points: 90,
      calculated_at: DateTime.utc_now()
    })
    |> Repo.insert!()
  end
end
