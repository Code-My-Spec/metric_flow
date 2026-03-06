defmodule MetricFlow.Ai.ReportGenerator do
  @moduledoc """
  Translates natural language descriptions into Vega-Lite v5 JSON specifications.

  Accepts a user prompt string and a list of available metric names for the
  account. Builds a system prompt from `LlmClient.base_system_prompt/0` with
  task-specific Vega-Lite instructions, and calls `LlmClient.generate_vega_spec/3`
  using the Sonnet model.

  Returns `{:ok, map()}` with the validated spec or `{:error, reason}` when
  the model fails to produce a conforming output.
  """

  alias MetricFlow.Ai.LlmClient

  @task_instructions """
  You are generating Vega-Lite v5 JSON specifications for data visualizations.

  Always include:
  - "$schema": "https://vega.github.io/schema/vega-lite/v5.json"
  - "mark": the chart type (bar, line, point, area, etc.)
  - "encoding": field mappings with types (temporal, quantitative, nominal, ordinal)

  Use the available metric names provided to map data fields correctly.
  Return a complete, valid Vega-Lite v5 spec as a JSON object.
  """

  @doc """
  Generates a Vega-Lite v5 specification from a natural language prompt.

  Returns `{:ok, map()}` with the Vega-Lite spec on success, or
  `{:error, reason}` on failure.

  Pass `req_http_options: [plug: plug]` in opts for ReqCassette test recording.
  """
  @spec generate(String.t(), list(String.t()), keyword()) :: {:ok, map()} | {:error, term()}
  def generate(user_prompt, metric_names, opts \\ []) do
    system_prompt = build_system_prompt()
    user_content = build_user_content(user_prompt, metric_names)

    LlmClient.generate_vega_spec(system_prompt, user_content, opts)
  end

  # ---------------------------------------------------------------------------
  # Prompt construction (pure functions)
  # ---------------------------------------------------------------------------

  @doc false
  def build_system_prompt do
    LlmClient.base_system_prompt() <> "\n\n" <> String.trim(@task_instructions)
  end

  @doc false
  def build_user_content(user_prompt, metric_names) do
    """
    #{user_prompt}

    Available Metrics: #{Enum.join(metric_names, ", ")}
    """
  end
end
