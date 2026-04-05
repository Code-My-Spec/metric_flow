defmodule MetricFlow.Ai.LlmClient do
  @moduledoc """
  Thin wrapper around ReqLLM that centralises model selection, system prompts,
  and error handling for all three AI features.

  Defines module constants for the two Anthropic Claude model tiers used across
  the Ai context:

  - `@chat_model` — Claude Sonnet 4.5 for interactive chat and Vega-Lite report generation
  - `@insights_model` — Claude Haiku 4.5 for cost-efficient batch insights generation

  All API functions accept an optional `opts` keyword list that is forwarded to
  ReqLLM. In tests, pass `req_http_options: [plug: plug]` (from ReqCassette) to
  intercept HTTP calls without hitting the real Anthropic API.
  """

  @chat_model "anthropic:claude-sonnet-4-5"
  @insights_model "anthropic:claude-haiku-4-5"

  @insight_schema [
    insights: [
      type:
        {:list,
         {:map,
          [
            summary: [type: :string, required: true],
            content: [type: :string, required: true],
            suggestion_type: [type: :string, required: true],
            confidence: [type: :float, required: true]
          ]}},
      required: true
    ]
  ]

  # Anthropic structured output rejects `additionalProperties: true` on objects.
  # Vega-Lite specs are inherently open-ended, so we wrap the entire spec as a
  # JSON string and decode it ourselves.
  @vega_wrapper_schema [
    vega_lite_json: [type: :string, required: true]
  ]

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
  Returns the model string used for interactive chat and Vega-Lite report generation.
  """
  @spec chat_model() :: String.t()
  def chat_model, do: @chat_model

  @doc """
  Returns the model string used for batch insights generation.
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

  Calls `ReqLLM.generate_object/4` with `@insights_model` and the NimbleOptions
  insight schema.

  Pass `req_http_options: [plug: plug]` in opts for ReqCassette test recording.
  """
  @spec generate_insights(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def generate_insights(system_prompt, user_content, opts \\ []) do
    case ReqLLM.generate_object(
           @insights_model,
           user_content,
           @insight_schema,
           Keyword.merge(opts, system_prompt: system_prompt)
         ) do
      {:ok, %{object: data}} -> {:ok, data}
      {:error, reason} -> {:error, reason}
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

  Uses a NimbleOptions wrapper schema that asks the LLM to return the Vega-Lite
  spec as a JSON string, which is then decoded. This avoids Anthropic's restriction
  on `additionalProperties: true` in structured output schemas.

  Pass `req_http_options: [plug: plug]` in opts for ReqCassette test recording.
  """
  @spec generate_vega_spec(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def generate_vega_spec(system_prompt, user_content, opts \\ []) do
    enhanced_content =
      user_content <>
        "\n\nReturn the COMPLETE Vega-Lite v5 specification as a valid JSON string " <>
        "in the vega_lite_json field. The JSON must include $schema, mark, and encoding keys."

    case ReqLLM.generate_object(
           @chat_model,
           enhanced_content,
           @vega_wrapper_schema,
           Keyword.merge(opts, system_prompt: system_prompt)
         ) do
      {:ok, %{object: %{"vega_lite_json" => json_str}}} ->
        case Jason.decode(json_str) do
          {:ok, spec} -> {:ok, spec}
          {:error, _} -> {:error, :invalid_vega_spec}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
