defmodule MetricFlow.DataSync.YouTubeReport do
  @moduledoc "Validates YouTube daily report tables before persistence."

  def parse(%{"columnHeaders" => headers} = body, names, {first, last})
      when is_list(headers) and is_list(names) do
    rows = Map.get(body, "rows", [])

    with true <- valid_headers?(headers, names),
         true <- is_list(rows),
         true <- Map.get(body, "nextPageToken") in [nil, ""] do
      columns = Enum.map(headers, & &1["name"])
      parse_rows(rows, columns, names, first, last)
    else
      _ -> {:error, :malformed_report}
    end
  end

  def parse(_, _, _), do: {:error, :malformed_report}

  defp valid_headers?(headers, names) do
    expected = MapSet.new(["day" | names])

    length(headers) == MapSet.size(expected) and
      Enum.all?(headers, fn
        %{"name" => "day", "columnType" => "DIMENSION"} -> true
        %{"name" => name, "columnType" => "METRIC"} -> name in names
        _ -> false
      end) and
      MapSet.new(Enum.map(headers, &Map.get(&1, "name"))) == expected
  end

  defp parse_rows(rows, columns, names, first, last) do
    result =
      Enum.reduce_while(rows, {:ok, [], MapSet.new()}, fn row, {:ok, acc, seen} ->
        with true <- is_list(row) and length(row) == length(columns),
             values = Map.new(Enum.zip(columns, row)),
             day when is_binary(day) <- Map.get(values, "day"),
             {:ok, date} <- Date.from_iso8601(day),
             true <- Date.compare(date, first) != :lt and Date.compare(date, last) != :gt,
             false <- MapSet.member?(seen, date),
             {:ok, observations} <- observations(values, names, date) do
          {:cont, {:ok, [observations | acc], MapSet.put(seen, date)}}
        else
          _ -> {:halt, {:error, :malformed_report}}
        end
      end)

    case result do
      {:ok, pages, _seen} -> {:ok, pages |> Enum.reverse() |> List.flatten()}
      error -> error
    end
  end

  defp observations(values, names, date) do
    Enum.reduce_while(names, {:ok, []}, fn name, {:ok, acc} ->
      raw_value = Map.fetch!(values, name)
      value = if name == "comments" and is_nil(raw_value), do: 0, else: raw_value

      case decimal(value) do
        {:ok, value} ->
          {:cont, {:ok, [%{metric_name: name, report_date: date, value: value} | acc]}}

        :error ->
          {:halt, {:error, :invalid_value}}
      end
    end)
  end

  defp decimal(value) when is_integer(value) and value >= 0, do: {:ok, Decimal.new(value)}
  defp decimal(value) when is_float(value) and value >= 0, do: {:ok, Decimal.from_float(value)}
  defp decimal(_), do: :error
end
