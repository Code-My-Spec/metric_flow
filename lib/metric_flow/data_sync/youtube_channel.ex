defmodule MetricFlow.DataSync.YouTubeChannel do
  @moduledoc "Parses a selected channel and its current statistics."

  def parse(%{"items" => items}, channel_id, date) when is_list(items) do
    case Enum.filter(items, &match?(%{"id" => ^channel_id}, &1)) do
      [item] -> parse_item(item, date)
      [] -> {:error, :channel_not_found}
      _ -> {:error, :malformed_channel}
    end
  end

  def parse(_, _, _), do: {:error, :malformed_channel}

  defp parse_item(
         %{
           "snippet" => %{"title" => title, "publishedAt" => published},
           "statistics" => statistics
         },
         date
       )
       when is_binary(title) and is_binary(published) and is_map(statistics) do
    with {:ok, published_at, _offset} <- DateTime.from_iso8601(published),
         {:ok, snapshots} <- snapshots(statistics, date) do
      {:ok,
       %{
         attrs: %{display_name: title, published_at: published_at},
         snapshots: snapshots,
         created_on: DateTime.to_date(published_at)
       }}
    else
      _ -> {:error, :malformed_channel}
    end
  end

  defp parse_item(_, _), do: {:error, :malformed_channel}

  defp snapshots(statistics, date) do
    names =
      if Map.get(statistics, "hiddenSubscriberCount", false),
        do: ["viewCount", "videoCount"],
        else: ["subscriberCount", "viewCount", "videoCount"]

    Enum.reduce_while(names, {:ok, []}, fn name, {:ok, rows} ->
      case parse_count(Map.get(statistics, name)) do
        {:ok, value} ->
          {:cont, {:ok, [%{metric_name: name, report_date: date, value: value} | rows]}}

        :error ->
          {:halt, {:error, :malformed_channel}}
      end
    end)
  end

  defp parse_count(value) when is_binary(value) do
    case Integer.parse(value) do
      {count, ""} when count >= 0 -> {:ok, count}
      _ -> :error
    end
  end

  defp parse_count(value) when is_integer(value) and value >= 0, do: {:ok, value}
  defp parse_count(_), do: :error
end
