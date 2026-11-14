defmodule MetricFlow.Ai.DashboardBuilder do
  @moduledoc """
  Story 74's builder-only agent for the dashboard editor's chat.

  Replaces `MetricFlow.Ai.VizChat` on that one path: its only write tool is
  `set_dashboard_spec` (the dashboard's complete A2UI blob, every call),
  plus the read-only `query_metrics` -- no Vega-Lite doc browsing, no
  per-widget `update_spec`. `VizChat` stays as-is for any other caller
  (`VisualizationLive.Editor`'s single-chart editor).
  """

  alias MetricFlow.Ai.LlmProvider
  alias MetricFlow.Ai.VizChat.UnresolvableMetricHalt
  alias MetricFlow.Ai.VizTools

  @tool_modules [VizTools.SetDashboardSpec, VizTools.QueryMetrics]

  @fallback_text "I've completed my research. Let me know if you'd like me to try again."

  @doc """
  Send a message in the dashboard builder chat.

  ## Parameters

    * `messages` — prior `Alloy.Message` history (or `nil` for the first message)
    * `user_message` — the new user message text
    * `opts` — keyword list:
      - `:metric_names` — list of metric name strings available to the account
      - `:current_spec` — the dashboard's current A2UI spec map (or nil)
      - `:req_http_options` / `:command_runner` — forwarded to the provider for tests

  ## Returns

    * `{:ok, %{text: String.t(), spec: map() | nil, context: [Alloy.Message.t()]}}`
      -- `spec` is the A2UI blob from the last `set_dashboard_spec` call, the
      dashboard's complete new spec (nil if the model didn't call it this turn).
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

    run_opts = [
      provider: LlmProvider.chat_provider(opts),
      tools: @tool_modules,
      system_prompt: build_system_prompt(current_spec),
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
      %{name: "set_dashboard_spec", structured_data: %{spec: spec}} -> spec
      _ -> nil
    end)
  end

  defp parse_unresolvable_names(error) when is_binary(error) do
    prefix = VizTools.SetDashboardSpec.unresolvable_prefix()

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
  You are a dashboard-building assistant for a marketing analytics platform.
  You build dashboards out of A2UI components: charts, stat tiles, and
  filter controls bound to the user's metrics.

  You have exactly one way to change the dashboard: set_dashboard_spec. It
  takes the dashboard's COMPLETE A2UI spec every time you call it --
  {"title": ..., "components": [...]}. There is no separate edit tool; to
  add, change, or remove a widget, pass back the complete, updated
  component list.

  The first time you build a dashboard, give it a short title (a few words)
  describing what it shows -- never the user's raw request verbatim. Omit
  title on every later call so the dashboard's existing name is left alone.

  Each chart or stat component must bind to a metric via a "query" map with
  a "metric" key (e.g. {"metric": "impressions"}) -- never embed "data" or
  "values"; the real numbers are fetched at render time. Filters are
  ordinary components bound to the dashboard's data model; their chosen
  values are saved with the dashboard, not held only in memory.

  When the user asks for more than one thing (e.g. "a stat tile and a line
  chart"), that means more than one component in the SAME spec, in the SAME
  call -- add every one of them to the "components" list you pass to
  set_dashboard_spec. Do not call set_dashboard_spec more than once per
  message, and do not combine several widgets into one component.

  Use query_metrics to see what the account has before building.

  When the user doesn't name a date range, default to the last 30 days
  ending yesterday (today's incomplete data is not included).

  Be conversational -- explain what you're doing, answer questions, and
  suggest improvements. Not every message needs a spec update.
  """

  defp build_system_prompt(nil) do
    String.trim(@base_system_prompt) <>
      "\n\nNo dashboard exists yet. Build one by calling set_dashboard_spec."
  end

  defp build_system_prompt(current_spec) do
    String.trim(@base_system_prompt) <>
      "\n\nCurrent dashboard spec:\n```json\n" <>
      Jason.encode!(current_spec, pretty: true) <>
      "\n```\nWhen changing it, pass back the COMPLETE updated spec."
  end
end
