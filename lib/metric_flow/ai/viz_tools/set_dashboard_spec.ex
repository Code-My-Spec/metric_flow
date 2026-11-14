defmodule MetricFlow.Ai.VizTools.SetDashboardSpec do
  @moduledoc """
  The dashboard builder's one write tool (Story 74).

  Sets the dashboard's entire A2UI spec in a single call -- there is no
  separate edit tool, so every call carries the COMPLETE updated spec, not
  a delta. Each `"chart"` or `"stat"` component must bind to a metric via
  a `"query"` map (never inline `"data"`/`"values"` -- real values are
  fetched at render time), checked against the account's available
  metrics the same way `VizTools.UpdateSpec` checks Vega-Lite named data
  sources, including the same `unresolvable_metric:` error prefix so
  `MetricFlow.Ai.VizChat.UnresolvableMetricHalt` halts on it too.
  """

  @behaviour Alloy.Tool

  @unresolvable_prefix "unresolvable_metric:"

  @impl true
  def name, do: "set_dashboard_spec"

  @impl true
  def description,
    do:
      "Set the dashboard's COMPLETE A2UI spec. Pass the whole spec every time -- there is " <>
        "no separate edit tool. Shape: {\"title\": ..., \"components\": [...]}. The first " <>
        "time you build a dashboard, give it a short title describing what it shows -- a " <>
        "few words, never the user's raw request verbatim. Omit title on a later call to " <>
        "leave the dashboard's existing name alone. Each \"chart\" or \"stat\" component " <>
        "must carry a \"query\" map with a \"metric\" key naming an available metric -- " <>
        "never embed \"data\" or \"values\"; real values are fetched at render time. " <>
        "Filters are ordinary components bound to the dashboard's data model. When the " <>
        "user asks for several widgets, put all of them in this one call's components " <>
        "list -- never call this tool more than once for a single message."

  @impl true
  def input_schema do
    %{
      type: "object",
      properties: %{
        a2ui_json: %{
          type: "string",
          description:
            "The complete A2UI spec as a JSON string: {\"title\": ..., \"components\": [...]}. " <>
              "\"title\" is a short name you choose for the dashboard -- set it the first time " <>
              "you build one, omit it on later calls to leave the existing name alone. " <>
              "Always the full \"components\" list, including every component that should remain."
        }
      },
      required: ["a2ui_json"]
    }
  end

  @doc "The error-text prefix used to signal an unresolvable metric name."
  def unresolvable_prefix, do: @unresolvable_prefix

  @impl true
  def execute(%{"a2ui_json" => json}, context) do
    metric_names = Map.get(context, :metric_names, [])

    with {:ok, spec} <- Jason.decode(json),
         :ok <- validate_components(spec),
         :ok <- validate_metric_names(spec, metric_names) do
      {:ok, "Dashboard spec updated successfully.", %{spec: spec}}
    else
      {:error, {:unresolvable_metrics, names}} ->
        {:error, @unresolvable_prefix <> Enum.join(names, ", ")}

      {:error, msg} when is_binary(msg) ->
        {:error, msg}

      {:error, _} ->
        {:error, "Invalid JSON in a2ui_json. Check syntax and try again."}
    end
  end

  defp validate_components(%{"components" => components}) when is_list(components) do
    Enum.reduce_while(components, :ok, fn component, _ ->
      case validate_component(component) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_components(_),
    do: {:error, ~s(a2ui_json must be an object with a "components" list)}

  defp validate_component(%{"type" => type} = component) when type in ["chart", "stat"] do
    cond do
      Map.has_key?(component, "data") or Map.has_key?(component, "values") ->
        {:error, ~s(components must not embed "data" or "values" -- bind via "query" instead)}

      not match?(%{"metric" => m} when is_binary(m), component["query"]) ->
        {:error, ~s(chart/stat components must carry a "query" map with a "metric" key)}

      true ->
        :ok
    end
  end

  defp validate_component(_component), do: :ok

  # No known metrics to validate against (shouldn't normally happen -- the
  # chat is only reachable once an account has metrics) -- let it through
  # rather than reject every spec outright, same as VizTools.UpdateSpec.
  defp validate_metric_names(_spec, []), do: :ok

  defp validate_metric_names(%{"components" => components}, metric_names) do
    referenced =
      components
      |> Enum.flat_map(fn
        %{"query" => %{"metric" => metric}} -> [metric]
        _ -> []
      end)
      |> Enum.uniq()

    case Enum.reject(referenced, &(&1 in metric_names)) do
      [] -> :ok
      unresolved -> {:error, {:unresolvable_metrics, unresolved}}
    end
  end
end
