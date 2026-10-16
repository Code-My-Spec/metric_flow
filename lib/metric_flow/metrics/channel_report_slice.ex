defmodule MetricFlow.Metrics.ChannelReportSlice do
  @moduledoc "Validates a complete channel-total report before its atomic replacement."

  alias MetricFlow.Metrics.{EntityMetricObservation, YouTubeMetricDefinitions}

  def validate(account_id, entity_id, family, {first, last}, observations, fetched_at)
      when is_struct(first, Date) and is_struct(last, Date) and
             is_list(observations) and is_struct(fetched_at, DateTime) do
    if family in YouTubeMetricDefinitions.families() and Date.compare(first, last) != :gt do
      validate_rows(account_id, entity_id, family, first, last, observations, fetched_at)
    else
      {:error, :invalid_report_slice}
    end
  end

  def validate(_account_id, _entity_id, _family, _range, _observations, _fetched_at),
    do: {:error, :invalid_report_slice}

  defp validate_rows(account_id, entity_id, family, first, last, observations, fetched_at) do
    result =
      Enum.reduce_while(observations, {:ok, [], MapSet.new()}, fn attrs, {:ok, rows, seen} ->
        case validate_row(account_id, entity_id, family, first, last, attrs, fetched_at) do
          {:ok, row} ->
            key = {row.metric_name, row.report_date}

            if MapSet.member?(seen, key) do
              {:halt, {:error, :duplicate_observation}}
            else
              {:cont, {:ok, [row | rows], MapSet.put(seen, key)}}
            end

          {:error, _} = error ->
            {:halt, error}
        end
      end)

    case result do
      {:ok, rows, _seen} -> {:ok, Enum.reverse(rows)}
      error -> error
    end
  end

  defp validate_row(account_id, entity_id, family, first, last, attrs, fetched_at)
       when is_map(attrs) do
    with {:ok, name} <- Map.fetch(attrs, :metric_name),
         {:ok, definition} <- YouTubeMetricDefinitions.fetch(name),
         true <- definition.family == family,
         {:ok, date} <- Map.fetch(attrs, :report_date),
         true <- is_struct(date, Date),
         true <- Date.compare(date, first) != :lt and Date.compare(date, last) != :gt,
         true <- metadata_matches?(attrs, definition, family) do
      canonical = %{
        metric_name: name,
        report_date: date,
        value: Map.get(attrs, :value),
        unit: definition.unit,
        measurement_kind: definition.kind,
        source_report: family,
        report_timezone: YouTubeMetricDefinitions.report_timezone(),
        breakdown_type: "total",
        breakdown_key: "all",
        fetched_at: fetched_at
      }

      %EntityMetricObservation{account_id: account_id, entity_id: entity_id}
      |> EntityMetricObservation.changeset(canonical)
      |> Ecto.Changeset.validate_number(:value, greater_than_or_equal_to: 0)
      |> Ecto.Changeset.apply_action(:insert)
    else
      _ -> {:error, :invalid_observation}
    end
  end

  defp validate_row(_account_id, _entity_id, _family, _first, _last, _attrs, _fetched_at),
    do: {:error, :invalid_observation}

  defp metadata_matches?(attrs, definition, family) do
    expected = %{
      unit: definition.unit,
      measurement_kind: definition.kind,
      source_report: family,
      report_timezone: YouTubeMetricDefinitions.report_timezone(),
      breakdown_type: "total",
      breakdown_key: "all"
    }

    Enum.all?(expected, fn {key, value} -> Map.get(attrs, key, value) == value end) and
      not Enum.any?(
        [:account_id, :entity_id, "account_id", "entity_id"],
        &Map.has_key?(attrs, &1)
      )
  end
end
