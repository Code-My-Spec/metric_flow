defmodule MetricFlow.DataSync.YouTubeBreakdownReport do
  @moduledoc "Validates daily channel breakdown tables without mixing them with totals."

  alias MetricFlow.DataSync.YouTubeReport

  @dimensions %{
    "traffic_source" => "insightTrafficSourceType",
    "device_type" => "deviceType",
    "country" => "country",
    "subscribed_status" => "subscribedStatus",
    "content_type" => "creatorContentType"
  }
  @metrics ~w(views estimatedMinutesWatched)

  def types, do: @dimensions |> Map.keys() |> Enum.sort()
  def metrics, do: @metrics

  def dimensions("country"), do: ["country"]
  def dimensions(type), do: ["day", Map.fetch!(@dimensions, type)]

  def parse(%{"columnHeaders" => headers, "rows" => rows} = body, type, range)
      when is_list(headers) and is_list(rows) do
    with true <- Map.get(body, "nextPageToken") in [nil, ""],
         {:ok, dimension} <- Map.fetch(@dimensions, type),
         true <- valid_headers?(headers, dimensions(type)),
         true <- valid_range?(type, range) do
      columns = Enum.map(headers, & &1["name"])
      parse_rows(rows, columns, dimension, type, range)
    else
      _ -> {:error, :malformed_report}
    end
  end

  def parse(%{"columnHeaders" => _} = body, type, range) do
    if Map.has_key?(body, "rows"),
      do: {:error, :malformed_report},
      else: parse(Map.put(body, "rows", []), type, range)
  end

  def parse(_, _, _), do: {:error, :malformed_report}

  defp valid_headers?(headers, dimensions) do
    expected = MapSet.new(dimensions ++ @metrics)

    length(headers) == MapSet.size(expected) and
      Enum.all?(headers, fn
        %{"name" => name, "columnType" => "DIMENSION"} -> name in dimensions
        %{"name" => name, "columnType" => "METRIC"} -> name in @metrics
        _ -> false
      end) and MapSet.new(Enum.map(headers, &Map.get(&1, "name"))) == expected
  end

  defp valid_range?("country", {first, last}), do: first == last
  defp valid_range?(_, _), do: true

  defp parse_rows(rows, columns, dimension, type, range) do
    result =
      Enum.reduce_while(rows, {:ok, [], MapSet.new()}, fn row, acc ->
        accumulate_row(row, columns, dimension, type, range, acc)
      end)

    case result do
      {:ok, groups, _seen} -> {:ok, groups |> Enum.reverse() |> List.flatten()}
      error -> error
    end
  end

  defp accumulate_row(row, columns, dimension, type, {first, _last} = range, {:ok, acc, seen}) do
    with true <- is_list(row) and length(row) == length(columns),
         values = Map.new(Enum.zip(columns, row)),
         key when is_binary(key) and byte_size(key) > 0 <- Map.get(values, dimension),
         day = Map.get(values, "day", Date.to_iso8601(first)),
         false <- MapSet.member?(seen, {day, key}),
         {:ok, observations} <- parse_values(values, day, range) do
      observations =
        Enum.map(observations, &Map.merge(&1, %{breakdown_type: type, breakdown_key: key}))

      {:cont, {:ok, [observations | acc], MapSet.put(seen, {day, key})}}
    else
      _ -> {:halt, {:error, :malformed_report}}
    end
  end

  defp parse_values(values, day, range) do
    headers =
      [%{"name" => "day", "columnType" => "DIMENSION"}] ++
        Enum.map(@metrics, &%{"name" => &1, "columnType" => "METRIC"})

    body = %{
      "columnHeaders" => headers,
      "rows" => [[day | Enum.map(@metrics, &Map.fetch!(values, &1))]]
    }

    YouTubeReport.parse(body, @metrics, range)
  end
end
