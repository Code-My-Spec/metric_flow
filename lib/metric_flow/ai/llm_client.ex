defmodule MetricFlow.Ai.LlmClient do
  @moduledoc """
  Thin wrapper centralising model selection, system prompts, and error
  handling for all three AI features.

  - `generate_insights/3` and `generate_vega_spec/3` run through `Alloy.run/2`
    with a single forced tool (`until_tool:`) whose `input_schema` is the
    structured shape each feature needs — see `MetricFlow.Ai.LlmTools`. The
    provider is resolved by `MetricFlow.Ai.LlmProvider` (Claude Code CLI in
    dev/test, the real Anthropic Messages API in prod); pass `command_runner:`
    in opts to inject a `MetricFlowTest.ClaudeCodeStub` in tests.
  - `stream_chat/3` is unchanged: it still calls `ReqLLM.stream_text/3`
    directly. Pass `req_http_options: [plug: plug]` (from ReqCassette) in
    opts for test recording, as before.

  Defines module constants for the two Anthropic Claude model tiers used
  across the Ai context:

  - `@chat_model` — Claude Sonnet 4.5, used by `stream_chat/3`
  - `@insights_model` — Claude Haiku 4.5 (kept for reference; `generate_insights/3`
    now runs on the shared chat provider's configured model)
  """

  alias MetricFlow.Ai.LlmProvider
  alias MetricFlow.Ai.LlmTools.{EmitInsights, EmitVegaSpec}

  @chat_model "anthropic:claude-sonnet-4-5"
  @insights_model "anthropic:claude-haiku-4-5"

  @base_system_prompt """
  You are a marketing analytics assistant specialising in multi-platform
  performance data. You help users understand their marketing metrics across
  Google Analytics, Google Ads, Facebook Ads, and QuickBooks revenue data.

  When analysing data, focus on actionable insights that connect marketing
  spend and activity to measurable business outcomes. Be concise, precise,
  and data-driven in your responses.
  """

  # ---------------------------------------------------------------------------
  # Accessor functions for module constants
  # ---------------------------------------------------------------------------

  @doc """
  Returns the model string used for interactive chat (`stream_chat/3`).
  """
  @spec chat_model() :: String.t()
  def chat_model, do: @chat_model

  @doc """
  Returns the model string historically used for batch insights generation.
  Kept for reference; `generate_insights/3` now runs on the Alloy chat
  provider's configured model rather than selecting a model per call.
  """
  @spec insights_model() :: String.t()
  def insights_model, do: @insights_model

  @doc """
  Returns the shared marketing analytics assistant system prompt.

  This prompt is used as the base for all three AI features. Each feature
  appends a task-specific instruction block before calling the relevant
  LlmClient function.
  """
  @spec base_system_prompt() :: String.t()
  def base_system_prompt, do: String.trim(@base_system_prompt)

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Generates structured AI insights from correlation data.

  Runs `Alloy.run/2` with the `emit_insights` tool forced via `until_tool:`.

  Pass `command_runner:` in opts to inject a `MetricFlowTest.ClaudeCodeStub`
  for test recording.
  """
  @spec generate_insights(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def generate_insights(system_prompt, user_content, opts \\ []) do
    run_opts = [
      provider: LlmProvider.chat_provider(opts),
      tools: [EmitInsights],
      until_tool: "emit_insights",
      system_prompt: system_prompt
    ]

    case Alloy.run(user_content, run_opts) do
      {:ok, result} -> extract_tool_input(result, "emit_insights")
      {:error, result} -> {:error, result.error}
    end
  end

  @doc """
  Streams a chat response using the interactive chat model.

  Calls `ReqLLM.stream_text/3` with `@chat_model`. The caller receives a
  `ReqLLM.StreamResponse` containing a lazy token stream and a concurrent
  metadata handle.

  Pass `req_http_options: [plug: plug]` in opts for ReqCassette test recording.
  """
  @spec stream_chat(String.t(), list(), keyword()) ::
          {:ok, ReqLLM.StreamResponse.t()} | {:error, term()}
  def stream_chat(system_prompt, messages, opts \\ []) do
    ReqLLM.stream_text(
      @chat_model,
      messages,
      Keyword.merge(opts, system_prompt: system_prompt)
    )
  end

  @doc """
  Generates a Vega-Lite v5 JSON specification from a natural language description.

  Runs `Alloy.run/2` with the `emit_vega_spec` tool forced via `until_tool:`.

  Pass `command_runner:` in opts to inject a `MetricFlowTest.ClaudeCodeStub`
  for test recording.
  """
  @spec generate_vega_spec(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def generate_vega_spec(system_prompt, user_content, opts \\ []) do
    run_opts = [
      provider: LlmProvider.chat_provider(opts),
      tools: [EmitVegaSpec],
      until_tool: "emit_vega_spec",
      system_prompt: system_prompt
    ]

    case Alloy.run(user_content, run_opts) do
      {:ok, result} -> extract_vega_spec(result)
      {:error, result} -> {:error, result.error}
    end
  end

  # ---------------------------------------------------------------------------
  # Private: tool-result extraction
  # ---------------------------------------------------------------------------

  defp extract_tool_input(%{tool_calls: tool_calls}, tool_name) do
    case Enum.find(tool_calls, &(&1[:name] == tool_name)) do
      %{structured_data: data} -> {:ok, data}
      _ -> {:error, :tool_not_called}
    end
  end

  defp extract_vega_spec(result) do
    case extract_tool_input(result, "emit_vega_spec") do
      {:ok, %{"spec" => spec}} -> {:ok, spec}
      {:ok, _other} -> {:error, :invalid_vega_spec}
      {:error, reason} -> {:error, reason}
    end
  end
end
