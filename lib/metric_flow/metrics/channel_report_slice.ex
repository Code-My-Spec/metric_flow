defmodule MetricFlow.Metrics.ChannelReportSlice do
  @moduledoc """
  Shapes projected daily metrics for one provider without losing location detail.

  The report keeps one row per provider, location, date, and metric name. A
  stored zero stays a visible zero, and locations with observations on the
  same date remain separate.
  """

  @type daily_metric :: MetricFlow.Metrics.ChannelProjection.daily_metric()
  @type t :: %{provider: atom(), metric_names: [String.t()], daily_rows: [daily_metric()]}

  @spec build([daily_metric()], atom()) :: t()
  def build(rows, provider) when is_list(rows) and is_atom(provider) do
    daily_rows =
      rows
      |> Enum.filter(&(&1.provider == provider))
      |> Enum.sort_by(&{&1.date, &1.location_id || "", &1.metric_name})

    %{
      provider: provider,
      metric_names: daily_rows |> Enum.map(& &1.metric_name) |> Enum.uniq() |> Enum.sort(),
      daily_rows: daily_rows
    }
  end

  @spec for_location(t(), String.t()) :: [daily_metric()]
  def for_location(%{daily_rows: rows}, location_id) when is_binary(location_id) do
    Enum.filter(rows, &(&1.location_id == location_id))
  end
end
