defmodule MetricFlow.Metrics.ChannelAggregation do
  @moduledoc """
  Pure daily aggregation of stored metrics by provider, location, and metric name.

  Location stays in the key so observations from separate business profiles
  cannot be combined accidentally. Sync replaces stale observations before
  storage; this module sums the rows it receives.
  """

  alias MetricFlow.Metrics.Metric

  @type key :: {atom(), String.t() | nil, Date.t(), String.t()}
  @type totals :: %{optional(key()) => float()}

  @spec aggregate_daily([Metric.t()]) :: totals()
  def aggregate_daily(metrics) when is_list(metrics) do
    Enum.reduce(metrics, %{}, fn
      %Metric{
        provider: provider,
        dimensions: dimensions,
        recorded_at: %DateTime{} = recorded_at,
        metric_name: name,
        value: value
      },
      totals
      when is_atom(provider) and is_map(dimensions) and is_binary(name) ->
        key = {provider, location_id(dimensions), DateTime.to_date(recorded_at), name}
        Map.update(totals, key, numeric_value(value), &(&1 + numeric_value(value)))
    end)
  end

  defp location_id(%{"location_id" => id}) when is_binary(id), do: id
  defp location_id(%{location_id: id}) when is_binary(id), do: id
  defp location_id(_dimensions), do: nil

  defp numeric_value(nil), do: 0.0
  defp numeric_value(value) when is_number(value), do: value * 1.0
end
