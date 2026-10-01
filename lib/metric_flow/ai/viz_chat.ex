defmodule MetricFlow.Ai.VizChat do
  @moduledoc """
  Conversational visualization agent backed by Alloy's agent loop.

  The model can update the Vega-Lite spec, browse Vega-Lite documentation,
  and query available metrics via the `Alloy.Tool` modules in
  `MetricFlow.Ai.VizTools`. Multi-turn history is the `Alloy.Message` list
  `Alloy.run/2` returns, threaded back in as `messages` on the next call.
  """

  alias MetricFlow.Ai.LlmProvider
  alias MetricFlow.Ai.VizChat.UnresolvableMetricHalt
  alias MetricFlow.Ai.VizTools

  @tool_modules [
    VizTools.UpdateSpec,
    VizTools.ListDocs,
    VizTools.ReadDoc,
    VizTools.SearchDocs,
    VizTools.QueryMetrics
  ]

  @fallback_text "I've completed my research. Let me know if you'd like me to try again."

  @doc """
  Send a message in the visualization chat.

  ## Parameters

    * `messages` — prior `Alloy.Message` history (or `nil` for the first message)
    * `user_message` — the new user message text
    * `opts` — keyword list:
      - `:metric_names` — list of metric name strings available to the account
      - `:current_spec` — current Vega-Lite spec map (or nil)
      - `:system_prompt` — override the default system prompt
      - `:req_http_options` — forwarded to the Anthropic provider for test cassettes

  ## Returns

    * `{:ok, %{text: String.t(), spec: map() | nil, context: [Alloy.Message.t()]}}`
    * `{:error, {:unresolvable_metric, [String.t()]}}` — the model referenced a
      metric name that doesn't exist for this account
    * `{:error, term()}`
  """
  @spec send_message([Alloy.Message.t()] | nil, String.t(), keyword()) ::
          {:ok, %{text: String.t(), spec: map() | nil, context: [Alloy.Message.t()]}}
          | {:error, term()}
  def send_message(messages, user_message, opts \\ []) do
    {metric_names, opts} = Keyword.pop(opts, :metric_names, [])
    {current_spec, opts} = Keyword.pop(opts, :current_spec)
    {system_prompt, opts} = Keyword.pop(opts, :system_prompt)

    system_prompt = system_prompt || build_system_prompt(current_spec)

    run_opts = [
      provider: LlmProvider.chat_provider(opts),
      tools: @tool_modules,
      system_prompt: system_prompt,
      messages: messages || [],
      context: %{metric_names: metric_names},
      middleware: [UnresolvableMetricHalt]
    ]

    case Alloy.run(user_message, run_opts) do
      {:ok, result} ->
        {:ok,
         %{
           text: result.text || @fallback_text,
           spec: extract_spec(result),
           context: result.messages
         }}

      {:error, %{status: :halted, error: error}} ->
        {:error, {:unresolvable_metric, parse_unresolvable_names(error)}}

      {:error, result} ->
        {:error, result.error}
    end
  end

  # ---------------------------------------------------------------------------
  # Result extraction
  # ---------------------------------------------------------------------------

  defp extract_spec(%{tool_calls: tool_calls}) do
    tool_calls
    |> Enum.reverse()
    |> Enum.find_value(fn
      %{name: "update_spec", structured_data: %{spec: spec}} -> spec
      _ -> nil
    end)
  end

  defp parse_unresolvable_names(error) when is_binary(error) do
    prefix = VizTools.UpdateSpec.unresolvable_prefix()

    error
    |> String.replace_prefix("Halted by middleware: ", "")
    |> String.replace_prefix(prefix, "")
    |> String.split(", ", trim: true)
  end

  defp parse_unresolvable_names(_error), do: []

  # ---------------------------------------------------------------------------
  # System prompt
  # ---------------------------------------------------------------------------

  @base_system_prompt """
  You are a data visualization assistant for a marketing analytics platform.
  You help users create and refine Vega-Lite v5 chart specifications.

  You have access to tools for:
  - Updating the Vega-Lite spec (creates/modifies the chart)
  - Browsing Vega-Lite documentation (list_docs, read_doc, search_docs)
  - Querying available metrics for the account

  IMPORTANT conventions:
  - Always use named data sources: {"data": {"name": "metricName"}}
  - Never embed data values — they are injected at render time
  - For multiple metrics, use "layer" with separate named data sources per layer
  - Include "$schema": "https://vega.github.io/schema/vega-lite/v5.json"

  When the user asks you to create or change a chart, call the update_spec tool.
  When you need to verify Vega-Lite syntax, browse the docs first.
  When you need to know what data is available, use query_metrics.

  Be conversational — explain what you're doing, answer questions, and suggest
  improvements. Not every message needs a spec update.
  """

  defp build_system_prompt(nil) do
    String.trim(@base_system_prompt) <>
      "\n\nNo chart exists yet. When the user asks for a visualization, " <>
      "create one by calling update_spec."
  end

  defp build_system_prompt(current_spec) do
    String.trim(@base_system_prompt) <>
      "\n\nCurrent Vega-Lite spec:\n```json\n" <>
      Jason.encode!(current_spec, pretty: true) <>
      "\n```\nWhen editing, pass the COMPLETE updated spec to update_spec."
  end
end
