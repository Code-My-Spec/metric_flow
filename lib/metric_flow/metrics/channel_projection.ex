defmodule MetricFlow.Metrics.ChannelProjection do
  @moduledoc "Explicit account-scoped channel totals for All Metrics."
  import Ecto.Query

  alias MetricFlow.Metrics.{
    ChannelAggregation,
    EntityMetricObservation,
    EntityMetricRepository,
    MetricEntity,
    YouTubeMetricDefinitions
  }

  alias MetricFlow.Repo

  def series(scope, opts \\ []) do
    with :ok <- EntityMetricRepository.authorize(scope, :read) do
      rows = scope |> query() |> filter_dates(Keyword.get(opts, :date_range)) |> Repo.all()
      weights = Map.new(rows, &{{&1.entity_id, &1.report_date, &1.metric_name}, &1.value})

      rows
      |> Enum.group_by(& &1.metric_name)
      |> Enum.flat_map(fn {name, observations} ->
        case YouTubeMetricDefinitions.fetch(name) do
          {:ok, definition} ->
            samples =
              observations
              |> Enum.filter(
                &(&1.unit == definition.unit and &1.measurement_kind == definition.kind and
                    &1.source_report == definition.family)
              )
              |> Enum.map(&sample(&1, definition, weights))

            if samples == [], do: [], else: [build_series(name, samples, definition.aggregation)]

          :error ->
            []
        end
      end)
      |> Enum.sort_by(& &1.metric_name)
    else
      {:error, :unauthorized} -> []
    end
  end

  def aggregate_points(points, semantics) do
    points |> Enum.flat_map(& &1.samples) |> ChannelAggregation.value(semantics)
  end

  def summary(%{data: points, aggregation: semantics}) do
    values = points |> Enum.map(& &1.value) |> Enum.filter(&is_number/1)
    aggregate = aggregate_points(points, semantics)

    average =
      case {semantics, values} do
        {:sum, [_ | _]} -> Enum.sum(values) / length(values)
        _ -> aggregate
      end

    %{
      sum: aggregate,
      avg: average,
      min: Enum.min(values, fn -> nil end),
      max: Enum.max(values, fn -> nil end),
      count: length(values)
    }
  end

  defp query(scope) do
    from(o in EntityMetricObservation,
      join: e in MetricEntity,
      on: e.id == o.entity_id and e.account_id == o.account_id,
      where:
        o.account_id == ^scope.account_id and e.provider == "youtube" and
          e.entity_type == "channel" and o.breakdown_type == "total" and
          o.breakdown_key == "all" and o.report_timezone == "America/Los_Angeles",
      order_by: [asc: o.report_date, asc: o.entity_id]
    )
  end

  defp filter_dates(query, nil), do: query

  defp filter_dates(query, {first, last}),
    do: where(query, [o], o.report_date >= ^first and o.report_date <= ^last)

  defp sample(row, definition, weights) do
    weight =
      case definition.aggregation do
        {:weighted, name} ->
          case Map.get(weights, {row.entity_id, row.report_date, name}) do
            nil -> nil
            value -> Decimal.to_float(value)
          end

        _ ->
          nil
      end

    %{
      entity_id: row.entity_id,
      date: row.report_date,
      value: Decimal.to_float(row.value),
      unit: row.unit,
      weight: weight
    }
  end

  defp build_series(name, samples, semantics) do
    data =
      samples
      |> Enum.group_by(& &1.date)
      |> Enum.map(fn {date, rows} ->
        %{date: date, value: ChannelAggregation.value(rows, semantics), samples: rows}
      end)
      |> Enum.sort_by(& &1.date, Date)

    %{
      metric_name: YouTubeMetricDefinitions.normalized_name(name),
      data: data,
      aggregation: semantics,
      provider: :youtube
    }
  end
end
