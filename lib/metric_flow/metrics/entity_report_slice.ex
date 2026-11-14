defmodule MetricFlow.Metrics.EntityReportSlice do
  @moduledoc "Validates video totals and channel breakdown slices before replacement."

  alias MetricFlow.Metrics.ChannelReportSlice

  @breakdowns ~w(traffic_source device_type country subscribed_status content_type)
  @breakdown_metrics ~w(views estimatedMinutesWatched)

  def breakdown_types, do: @breakdowns

  def validate(entity, family, breakdown, range, observations, fetched_at) do
    with :ok <- validate_grain(entity.entity_type, family, breakdown),
         {:ok, groups} <- group_rows(observations, breakdown) do
      validate_groups(entity, family, breakdown, range, groups, fetched_at)
    end
  end

  defp validate_grain("video", family, "total") when family in ["analytics", "revenue"],
    do: :ok

  defp validate_grain("channel", "analytics", breakdown) when breakdown in @breakdowns,
    do: :ok

  defp validate_grain(_, _, _), do: {:error, :invalid_report_grain}

  defp group_rows(rows, breakdown) when is_list(rows) do
    Enum.reduce_while(rows, {:ok, %{}}, fn attrs, {:ok, groups} ->
      case row_key(attrs, breakdown) do
        {:ok, key} ->
          canonical = Map.drop(attrs, [:breakdown_type, :breakdown_key])
          {:cont, {:ok, Map.update(groups, key, [canonical], &[canonical | &1])}}

        {:error, _} = error ->
          {:halt, error}
      end
    end)
  end

  defp group_rows(_, _), do: {:error, :invalid_report_slice}

  defp row_key(attrs, breakdown) when is_map(attrs) do
    key = Map.get(attrs, :breakdown_key, default_key(breakdown))

    with true <- Map.get(attrs, :breakdown_type, breakdown) == breakdown,
         true <- valid_key?(breakdown, key),
         true <- valid_metric?(breakdown, Map.get(attrs, :metric_name)),
         false <- Map.has_key?(attrs, "breakdown_type") or Map.has_key?(attrs, "breakdown_key") do
      {:ok, key}
    else
      _ -> {:error, :invalid_observation}
    end
  end

  defp row_key(_, _), do: {:error, :invalid_observation}

  defp default_key("total"), do: "all"
  defp default_key(_), do: nil
  defp valid_key?("total", key), do: key == "all"

  defp valid_key?(_breakdown, key) when is_binary(key),
    do: byte_size(key) > 0 and byte_size(key) <= 255 and String.trim(key) == key

  defp valid_key?(_, _), do: false
  defp valid_metric?("total", _), do: true
  defp valid_metric?(_, name), do: name in @breakdown_metrics

  defp validate_groups(entity, family, breakdown, range, groups, fetched_at) do
    # Validate even an empty report's dates and timestamps before reconciliation.
    with {:ok, []} <-
           ChannelReportSlice.validate(
             entity.account_id,
             entity.id,
             family,
             range,
             [],
             fetched_at
           ) do
      Enum.reduce_while(groups, {:ok, []}, fn {key, attrs}, {:ok, acc} ->
        result =
          ChannelReportSlice.validate(
            entity.account_id,
            entity.id,
            family,
            range,
            attrs,
            fetched_at
          )

        append_group(result, breakdown, key, acc)
      end)
    end
  end

  defp append_group({:ok, rows}, breakdown, key, acc) do
    rows = Enum.map(rows, &%{&1 | breakdown_type: breakdown, breakdown_key: key})
    {:cont, {:ok, rows ++ acc}}
  end

  defp append_group({:error, _} = error, _breakdown, _key, _acc), do: {:halt, error}
end
