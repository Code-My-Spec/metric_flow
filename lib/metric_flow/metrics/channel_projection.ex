defmodule MetricFlow.Metrics.ChannelProjection do
  @moduledoc """
  Projects stored metrics into daily totals by provider, location, and metric name.

  Reads are scoped to the current user. An optional `:provider` and inclusive
  `:date_range` filter narrow the projection before aggregation.
  """

  import Ecto.Query

  alias MetricFlow.Metrics.ChannelAggregation
  alias MetricFlow.Metrics.Metric
  alias MetricFlow.Repo
  alias MetricFlow.Users.Scope

  @type daily_metric :: %{
          provider: atom(),
          location_id: String.t() | nil,
          date: Date.t(),
          metric_name: String.t(),
          value: float()
        }

  @spec list_daily(Scope.t(), keyword()) :: [daily_metric()]
  def list_daily(%Scope{user: user}, opts \\ []) do
    from(m in Metric, where: m.user_id == ^user.id)
    |> filter_provider(Keyword.get(opts, :provider))
    |> filter_date_range(Keyword.get(opts, :date_range))
    |> Repo.all()
    |> ChannelAggregation.aggregate_daily()
    |> Enum.map(fn {{provider, location_id, date, metric_name}, value} ->
      %{
        provider: provider,
        location_id: location_id,
        date: date,
        metric_name: metric_name,
        value: value
      }
    end)
    |> Enum.sort_by(fn row ->
      {row.date, row.provider, row.location_id || "", row.metric_name}
    end)
  end

  defp filter_provider(query, nil), do: query
  defp filter_provider(query, provider), do: where(query, [m], m.provider == ^provider)

  defp filter_date_range(query, nil), do: query

  defp filter_date_range(query, {%Date{} = first, %Date{} = last}) do
    start_at = DateTime.new!(first, ~T[00:00:00], "Etc/UTC")
    end_at = DateTime.new!(Date.add(last, 1), ~T[00:00:00], "Etc/UTC")
    where(query, [m], m.recorded_at >= ^start_at and m.recorded_at < ^end_at)
  end
end
