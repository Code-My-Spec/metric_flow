defmodule MetricFlow.Ai.VizTools.QueryMetrics do
  @moduledoc """
  Query the available metrics for this account. Returns metric names and data
  format. Use this to discover what data the user has before building a
  visualization.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response

  schema do
    field :query, :string,
      description: "Optional search filter for metric names"
  end

  @impl true
  def execute(_params, frame) do
    metric_names = Map.get(frame.assigns, :metric_names, [])

    result =
      if metric_names == [] do
        "No metrics available. The user needs to connect a data source first."
      else
        "Available metrics for this account: #{Enum.join(metric_names, ", ")}\n\n" <>
          "Each metric has time series data with date and value fields. " <>
          "Use named data sources like {\"data\": {\"name\": \"metricName\"}} to reference them."
      end

    {:reply, Response.text(Response.tool(), result), frame}
  end
end
