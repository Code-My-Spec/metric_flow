defmodule MetricFlow.Ai.InsightsGenerator do
  @moduledoc """
  Generates actionable insights from correlation results.

  Accepts a correlation data map (metric names, coefficients, optimal lags,
  data window dates) and a list of available metric names. Builds a system
  prompt from `LlmClient.base_system_prompt/0` with task-specific instructions,
  and calls `LlmClient.generate_insights/3` using the Haiku model.

  Parses the structured response into a list of attribute maps suitable for
  building Insight changesets.
  """

  alias MetricFlow.Ai.LlmClient

  @task_instructions """
  You are generating structured insights from marketing correlation data.

  For each significant correlation, provide:
  - A detailed content explanation of the relationship and recommended action
  - A brief one-line summary
  - A suggestion_type: one of budget_increase, budget_decrease, optimization, monitoring, or general
  - A confidence score between 0.0 and 1.0

  Focus on actionable recommendations that connect marketing spend to business outcomes.
  Consider the optimal lag when suggesting timing adjustments.
  """

  @doc """
  Generates insights from correlation data.

  Returns `{:ok, list(map())}` where each map contains insight attributes
  suitable for `Insight.changeset/2`, or `{:error, reason}` on failure.

  Pass `req_http_options: [plug: plug]` in opts for ReqCassette test recording.
  """
  @spec generate(map(), list(String.t()), keyword()) ::
          {:ok, list(map())} | {:error, term()}
  def generate(correlation_data, metric_names, opts \\ []) do
    system_prompt = build_system_prompt()
    user_content = build_user_content(correlation_data, metric_names)

    case LlmClient.generate_insights(system_prompt, user_content, opts) do
      {:ok, response} -> {:ok, parse_response(response, correlation_data)}
      {:error, reason} -> {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Prompt construction (pure functions)
  # ---------------------------------------------------------------------------

  @doc false
  def build_system_prompt do
    LlmClient.base_system_prompt() <> "\n\n" <> String.trim(@task_instructions)
  end

  @doc false
  def build_user_content(correlation_data, metric_names) do
    results_text =
      correlation_data.results
      |> Enum.map_join("\n", fn r ->
        "- #{r.metric_name} → #{r.goal_metric_name}: " <>
          "coefficient=#{r.coefficient}, optimal_lag=#{r.optimal_lag} days"
      end)

    window = correlation_data.data_window

    """
    Correlation Results:
    #{results_text}

    Data Window: #{window.start_date} to #{window.end_date}

    Available Metrics: #{Enum.join(metric_names, ", ")}
    """
  end

  # ---------------------------------------------------------------------------
  # Response parsing
  # ---------------------------------------------------------------------------

  defp parse_response(response, _correlation_data) when is_list(response), do: response

  defp parse_response(response, correlation_data) when is_map(response) do
    suggestions = Map.get(response, :suggestions, Map.get(response, "suggestions", []))
    confidence = Map.get(response, :confidence, Map.get(response, "confidence", 0.5))
    summary = Map.get(response, :summary, Map.get(response, "summary", ""))

    results = Map.get(correlation_data, :results, [])

    suggestions
    |> Enum.with_index()
    |> Enum.map(fn {suggestion_text, index} ->
      result = Enum.at(results, index)

      %{
        content: suggestion_text,
        summary: summary,
        suggestion_type: :general,
        confidence: confidence,
        correlation_result_id: result && Map.get(result, :correlation_result_id),
        metadata: build_metadata(result)
      }
    end)
  end

  defp build_metadata(nil), do: %{}

  defp build_metadata(result) do
    %{
      metric_name: result.metric_name,
      coefficient: result.coefficient,
      optimal_lag: result.optimal_lag
    }
  end
end
