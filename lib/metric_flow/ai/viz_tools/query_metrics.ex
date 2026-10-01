defmodule MetricFlow.Ai.VizTools.QueryMetrics do
  @moduledoc "Alloy tool: list the metrics available to the current account."

  @behaviour Alloy.Tool

  @impl true
  def name, do: "query_metrics"

  @impl true
  def description,
    do:
      "Query the available metrics for this account. Returns metric names and data " <>
        "format. Use this to discover what data the user has before building a " <>
        "visualization."

  @impl true
  def input_schema do
    %{
      type: "object",
      properties: %{
        query: %{type: "string", description: "Optional search filter for metric names"}
      }
    }
  end

  @impl true
  def execute(_input, context) do
    metric_names = Map.get(context, :metric_names, [])

    result =
      if metric_names == [] do
        "No metrics available. The user needs to connect a data source first."
      else
        "Available metrics for this account: #{Enum.join(metric_names, ", ")}\n\n" <>
          "Each metric has time series data with date and value fields. " <>
          ~s(Use named data sources like {"data": {"name": "metricName"}} to reference them.)
      end

    {:ok, result}
  end
end
