defmodule MetricFlow.Ai.LlmClient do
  @moduledoc """
  Thin wrapper centralising model selection, system prompts, and error
  handling for all three AI features.

  All three run through `Alloy` now, resolved via `MetricFlow.Ai.LlmProvider`
  (Claude Code CLI in dev/test, the real Anthropic Messages API in prod);
  pass `command_runner:` in opts to inject a `MetricFlowTest.ClaudeCodeStub`
  in tests.

  - `generate_insights/3` and `generate_vega_spec/3` run through `Alloy.run/2`
    with a single forced tool (`until_tool:`) whose `input_schema` is the
    structured shape each feature needs — see `MetricFlow.Ai.LlmTools`.
  - `stream_chat/4` runs through `Alloy.stream/3`, Alloy's token-streaming
    entry point: it blocks for the whole turn, invoking the given `on_chunk`
    callback with each text delta as it arrives, and returns the fully
    assembled text once the turn completes. There is no fixed output schema
    to force here (`until_tool:` does not apply to free-form chat replies),
    so this is the one LlmClient function that does not go through `Alloy.run/2`.

  Defines a module constant for historical reference:

  - `@insights_model` — Claude Haiku 4.5 (kept for reference; `generate_insights/3`
    now runs on the shared chat provider's configured model)
  """

  alias Alloy.Message
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
  Returns the model string historically used for interactive chat.
  Kept for reference; `stream_chat/4` now runs on the Alloy chat provider's
  configured model rather than selecting a model per call.
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
  Streams a chat response using the interactive chat provider.

  Runs `Alloy.stream/3`, which blocks for the whole turn and invokes
  `on_chunk` with each text delta as it arrives. Returns the fully
  assembled reply text once the turn completes.

  `messages` is a list of `%{role: "user" | "assistant", content: String.t()}`
  maps (the shape `MetricFlow.Ai`'s chat history already builds).

  Pass `command_runner:` in opts to inject a `MetricFlowTest.ClaudeCodeStub`
  for test recording.
  """
  @spec stream_chat(String.t(), [map()], (String.t() -> any()), keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def stream_chat(system_prompt, messages, on_chunk, opts \\ []) do
    run_opts = [
      provider: LlmProvider.chat_provider(opts),
      system_prompt: system_prompt,
      messages: to_alloy_messages(messages)
    ]

    case Alloy.stream(nil, on_chunk, run_opts) do
      {:ok, result} -> {:ok, result.text || ""}
      {:error, result} -> {:error, result.error}
    end
  end

  defp to_alloy_messages(messages) do
    Enum.map(messages, fn
      %{role: role, content: content} when role in [:user, "user"] -> Message.user(content)
      %{role: role, content: content} when role in [:assistant, "assistant"] -> Message.assistant(content)
    end)
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
