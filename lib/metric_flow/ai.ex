defmodule MetricFlow.Ai do
  @moduledoc """
  Public API boundary for the Ai bounded context.

  Provides AI-powered features for MetricFlow: generating actionable insights
  from correlation data, conversational chat for data exploration, and Vega-Lite
  visualization generation from natural language descriptions.

  All public functions accept a `%Scope{}` as the first parameter for
  multi-tenant isolation.
  """

  use Boundary,
    deps: [MetricFlow, MetricFlow.Metrics, MetricFlow.Correlations, MetricFlow.Dashboards],
    exports: [
      Insight,
      SuggestionFeedback,
      ChatSession,
      ChatMessage,
      AiRepository,
      InsightsGenerator,
      ReportGenerator,
      LlmClient,
      VegaDocsReference,
      VizChat
    ]

  alias MetricFlow.Ai.AiRepository
  alias MetricFlow.Ai.Insight
  alias MetricFlow.Ai.InsightsGenerator
  alias MetricFlow.Ai.LlmClient
  alias MetricFlow.Ai.ReportGenerator
  alias MetricFlow.Ai.VizChat
  alias MetricFlow.Correlations
  alias MetricFlow.Dashboards
  alias MetricFlow.Metrics
  alias MetricFlow.Users.Scope

  # ---------------------------------------------------------------------------
  # Delegated repository functions
  # ---------------------------------------------------------------------------

  defdelegate list_insights(scope, opts \\ []), to: AiRepository
  defdelegate list_insights_for_metric(scope, metric_name, opts \\ []), to: AiRepository
  defdelegate get_insight(scope, id), to: AiRepository
  defdelegate delete_insight(scope, id), to: AiRepository
  defdelegate delete_all_insights(scope), to: AiRepository
  defdelegate list_chat_sessions(scope), to: AiRepository
  defdelegate get_chat_session(scope, id), to: AiRepository
  defdelegate get_shared_chat_session(scope, id), to: AiRepository
  defdelegate get_chat_session_by_context(scope, context_type, context_id), to: AiRepository
  defdelegate update_chat_session(scope, session, attrs), to: AiRepository
  defdelegate create_chat_message(scope, attrs), to: AiRepository
  defdelegate get_feedback_for_insight(scope, insight_id), to: AiRepository

  # ---------------------------------------------------------------------------
  # Feedback
  # ---------------------------------------------------------------------------

  @doc """
  Records user feedback on a specific insight. Upserts on the unique
  [insight_id, user_id] constraint so a user can change their rating.
  """
  @spec submit_feedback(Scope.t(), integer(), map()) ::
          {:ok, MetricFlow.Ai.SuggestionFeedback.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def submit_feedback(%Scope{} = scope, insight_id, attrs) do
    case AiRepository.get_insight(scope, insight_id) do
      {:ok, _insight} -> AiRepository.upsert_feedback(scope, insight_id, attrs)
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  # ---------------------------------------------------------------------------
  # Chat session management
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new chat session for the scoped user with a context type and
  optional context_id.
  """
  @spec create_chat_session(Scope.t(), map()) ::
          {:ok, MetricFlow.Ai.ChatSession.t()} | {:error, Ecto.Changeset.t()}
  def create_chat_session(%Scope{} = scope, attrs) do
    merged =
      attrs
      |> Map.put_new(:status, :active)
      |> Map.put_new(:title, default_title(attrs))

    AiRepository.create_chat_session(scope, merged)
  end

  # ---------------------------------------------------------------------------
  # Insight generation
  # ---------------------------------------------------------------------------

  @doc """
  Generates AI insights for a completed correlation job.

  Loads correlation results, delegates to InsightsGenerator for LLM processing,
  and persists the returned Insight records.

  Pass `command_runner:` in opts to inject a MetricFlowTest.ClaudeCodeStub for test recording.
  """
  @spec generate_insights(Scope.t(), integer(), keyword()) ::
          {:ok, list(Insight.t())} | {:error, term()}
  def generate_insights(%Scope{} = scope, correlation_job_id, opts \\ []) do
    with {:ok, job} <- Correlations.get_correlation_job(scope, correlation_job_id),
         :ok <- verify_completed(job),
         {:ok, results} <- load_results(scope, job),
         correlation_data <- build_correlation_data(job, results),
         metric_names <- extract_metric_names(results),
         {:ok, insight_attrs_list} <-
           InsightsGenerator.generate(correlation_data, metric_names, opts) do
      persist_insights(scope, insight_attrs_list, results)
    end
  end

  # ---------------------------------------------------------------------------
  # Vega-Lite spec generation
  # ---------------------------------------------------------------------------

  @doc """
  Generates a Vega-Lite v5 visualization specification from a natural language
  prompt.

  Pass `command_runner:` in opts to inject a MetricFlowTest.ClaudeCodeStub for test recording.
  """
  @spec generate_vega_spec(Scope.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def generate_vega_spec(%Scope{} = scope, user_prompt, opts \\ []) do
    metric_names = Metrics.list_metric_names(scope)

    case ReportGenerator.generate(user_prompt, metric_names, opts) do
      {:ok, spec} -> validate_vega_spec(spec)
      {:error, reason} -> {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Visualization chat (conversational with tools)
  # ---------------------------------------------------------------------------

  @doc """
  Sends a message in the visualization chat. The model can respond with text,
  update the Vega-Lite spec, browse docs, or query metrics.

  Uses `VizChat`, backed by Alloy's agent loop. Pass the prior `Alloy.Message`
  list to maintain multi-turn conversation history (or nil for the first message).

  Returns `{:ok, %{text: String.t(), spec: map() | nil, context: [Alloy.Message.t()]}}`.
  """
  @spec viz_chat(Scope.t(), [Alloy.Message.t()] | nil, String.t(), keyword()) ::
          {:ok, %{text: String.t(), spec: map() | nil, context: [Alloy.Message.t()]}}
          | {:error, term()}
  def viz_chat(%Scope{} = scope, context, user_message, opts \\ []) do
    metric_names = Metrics.list_normalized_metric_names(scope)

    VizChat.send_message(
      context,
      user_message,
      Keyword.merge(opts, metric_names: metric_names)
    )
  end

  # ---------------------------------------------------------------------------
  # Chat messaging (streaming)
  # ---------------------------------------------------------------------------

  @doc """
  Sends a user message in a chat session. Persists the user message, spawns a
  Task that streams the assistant response, and returns the Task pid.

  Pass `req_http_options: [plug: plug]` in opts for ReqCassette test recording.
  """
  @spec send_chat_message(Scope.t(), integer(), String.t(), keyword()) ::
          {:ok, pid()} | {:error, :not_found | :session_archived}
  def send_chat_message(%Scope{} = scope, session_id, content, opts \\ []) do
    with {:ok, session} <- AiRepository.get_chat_session(scope, session_id),
         :ok <- verify_active(session),
         {:ok, _user_msg} <- persist_user_message(scope, session, content) do
      caller = self()

      task =
        Task.async(fn ->
          stream_assistant_response(scope, session, caller, opts)
        end)

      {:ok, task.pid}
    end
  end

  # ---------------------------------------------------------------------------
  # Private: generate_insights helpers
  # ---------------------------------------------------------------------------

  defp verify_completed(%{status: :completed}), do: :ok
  defp verify_completed(_job), do: {:error, :job_not_complete}

  defp load_results(scope, _job) do
    case Correlations.list_correlation_results(scope) do
      [] -> {:error, :no_results}
      results -> {:ok, results}
    end
  end

  defp build_correlation_data(job, results) do
    %{
      results:
        Enum.map(results, fn r ->
          %{
            metric_name: r.metric_name,
            goal_metric_name: r.goal_metric_name,
            coefficient: r.coefficient,
            optimal_lag: r.optimal_lag,
            correlation_result_id: r.id
          }
        end),
      data_window: %{
        start_date: job.data_window_start || Date.utc_today(),
        end_date: job.data_window_end || Date.utc_today()
      }
    }
  end

  defp extract_metric_names(results) do
    results
    |> Enum.flat_map(fn r -> [r.metric_name, r.goal_metric_name] end)
    |> Enum.uniq()
  end

  defp persist_insights(scope, insight_attrs_list, _results) do
    now = DateTime.utc_now()

    insights =
      insight_attrs_list
      |> Enum.map(fn attrs ->
        attrs
        |> Map.put_new(:generated_at, now)
        |> then(&AiRepository.create_insight(scope, &1))
      end)
      |> Enum.filter(&match?({:ok, _}, &1))
      |> Enum.map(fn {:ok, insight} -> insight end)

    {:ok, insights}
  end

  # ---------------------------------------------------------------------------
  # Private: generate_vega_spec helpers
  # ---------------------------------------------------------------------------

  defp validate_vega_spec(spec) when is_map(spec) do
    has_schema = Map.has_key?(spec, "$schema")
    has_mark_encoding = Map.has_key?(spec, "mark") and Map.has_key?(spec, "encoding")
    has_layer = Map.has_key?(spec, "layer") and is_list(spec["layer"])

    if has_schema and (has_mark_encoding or has_layer) do
      {:ok, spec}
    else
      {:error, :invalid_vega_spec}
    end
  end

  # ---------------------------------------------------------------------------
  # Private: send_chat_message helpers
  # ---------------------------------------------------------------------------

  defp verify_active(%{status: :active}), do: :ok
  defp verify_active(_session), do: {:error, :session_archived}

  defp persist_user_message(scope, session, content) do
    AiRepository.create_chat_message(scope, %{
      chat_session_id: session.id,
      role: :user,
      content: content
    })
  end

  defp stream_assistant_response(scope, session, caller, opts) do
    {:ok, loaded_session} = AiRepository.get_chat_session(scope, session.id)
    system_prompt = LlmClient.base_system_prompt() <> "\n\n" <> build_data_context(scope, loaded_session)

    messages =
      Enum.map(loaded_session.chat_messages, fn msg ->
        %{role: to_string(msg.role), content: msg.content}
      end)

    on_chunk = fn text -> send(caller, {:chat_token, text}) end
    stream_fn = Keyword.get(opts, :stream_chat_fn, &LlmClient.stream_chat/4)

    case stream_fn.(system_prompt, messages, on_chunk, opts) do
      {:ok, content} ->
        content =
          if content == "",
            do: "I wasn't able to generate a response. Please try again.",
            else: content

        {:ok, _msg} =
          AiRepository.create_chat_message(scope, %{
            chat_session_id: session.id,
            role: :assistant,
            content: content,
            token_count: String.length(content)
          })

        send(caller, {:chat_complete, %{token_count: String.length(content)}})

      {:error, reason} ->
        send(caller, {:chat_error, reason})
    end
  end

  defp default_title(%{context_type: type}) when is_atom(type), do: "#{type} chat"
  defp default_title(%{"context_type" => type}), do: "#{type} chat"
  defp default_title(_), do: "Chat"

  # ---------------------------------------------------------------------------
  # Private: chat data context
  # ---------------------------------------------------------------------------

  # Gives the assistant real access to the account's metrics and correlation
  # data (criteria 214/882), plus a summary of whatever the session's own
  # context_type/context_id points at (criteria 212/879), instead of just a
  # generic system prompt with no account-specific content.
  defp build_data_context(scope, session) do
    [
      metrics_summary(Metrics.list_metric_names(scope)),
      correlations_summary(Correlations.list_correlation_results(scope, limit: 10)),
      current_view_summary(scope, session)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n\n")
  end

  defp metrics_summary([]), do: "The account has no metrics connected yet."

  defp metrics_summary(names) do
    "Available metrics across all connected platforms: " <> Enum.join(names, ", ")
  end

  defp correlations_summary([]), do: nil

  defp correlations_summary(results) do
    lines =
      Enum.map(results, fn r ->
        "- #{r.metric_name} vs #{r.goal_metric_name}: coefficient #{r.coefficient}, lag #{r.optimal_lag}"
      end)

    "Known correlation results:\n" <> Enum.join(lines, "\n")
  end

  defp current_view_summary(_scope, %{context_type: :general}), do: nil
  defp current_view_summary(_scope, %{context_id: nil}), do: nil

  defp current_view_summary(scope, %{context_type: :visualization, context_id: id}) do
    case Dashboards.get_visualization(scope, id) do
      {:ok, viz} ->
        names = Dashboards.get_visualization_metric_names(viz)

        "The user is currently viewing the visualization \"#{viz.name || "Untitled"}\", " <>
          "which charts: #{Enum.join(names, ", ")}."

      {:error, :not_found} ->
        nil
    end
  end

  defp current_view_summary(scope, %{context_type: :dashboard, context_id: id}) do
    case Dashboards.get_dashboard(scope, id) do
      {:ok, dashboard} -> "The user is currently viewing the dashboard \"#{dashboard.name}\"."
      {:error, :not_found} -> nil
    end
  end

  defp current_view_summary(scope, %{context_type: :metric, context_id: id}) do
    case Metrics.get_metric(scope, id) do
      {:ok, metric} -> "The user is currently focused on the metric \"#{metric.metric_name}\"."
      {:error, :not_found} -> nil
    end
  end

  defp current_view_summary(scope, %{context_type: :correlation, context_id: id}) do
    case Correlations.get_correlation_result(scope, id) do
      {:ok, result} ->
        "The user is currently viewing a correlation between #{result.metric_name} and " <>
          "#{result.goal_metric_name} (coefficient #{result.coefficient}, lag #{result.optimal_lag})."

      {:error, :not_found} ->
        nil
    end
  end

  defp current_view_summary(_scope, _session), do: nil
end
