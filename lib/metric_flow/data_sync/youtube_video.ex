defmodule MetricFlow.DataSync.YouTubeVideo do
  @moduledoc "Validates upload inventory pages and channel-owned video metadata."

  def parse_page(%{"items" => items} = body) when is_list(items) do
    token = Map.get(body, "nextPageToken")

    with true <- is_nil(token) or (is_binary(token) and token != ""),
         {:ok, ids} <- collect(items, &upload_id/1),
         true <- length(ids) == length(Enum.uniq(ids)) do
      {:ok, %{ids: ids, next_page_token: token}}
    else
      _ -> {:error, :malformed_video_inventory}
    end
  end

  def parse_page(_), do: {:error, :malformed_video_inventory}

  def parse_metadata(%{"items" => items}, channel_id, requested_ids) when is_list(items) do
    with {:ok, videos} <- collect(items, &parse_video(&1, channel_id, requested_ids)),
         ids = Enum.map(videos, & &1.external_id),
         true <- length(ids) == length(Enum.uniq(ids)) do
      # Deleted or inaccessible IDs may be absent. Their existing storage is retained.
      {:ok, videos}
    else
      _ -> {:error, :malformed_video_metadata}
    end
  end

  def parse_metadata(_, _, _), do: {:error, :malformed_video_metadata}

  defp upload_id(%{"contentDetails" => %{"videoId" => id}})
       when is_binary(id) and byte_size(id) > 0, do: {:ok, id}

  defp upload_id(_), do: {:error, :malformed_video_inventory}

  defp parse_video(%{"id" => id, "snippet" => snippet}, channel_id, requested_ids)
       when is_binary(id) and is_map(snippet) do
    with true <- id in requested_ids,
         ^channel_id <- Map.get(snippet, "channelId"),
         title when is_binary(title) <- Map.get(snippet, "title"),
         true <- String.trim(title) != "",
         published when is_binary(published) <- Map.get(snippet, "publishedAt"),
         {:ok, published_at, _} <- DateTime.from_iso8601(published) do
      {:ok,
       %{
         external_id: id,
         attrs: %{display_name: title, published_at: published_at},
         created_on: DateTime.to_date(published_at)
       }}
    else
      _ -> {:error, :malformed_video_metadata}
    end
  end

  defp parse_video(_, _, _), do: {:error, :malformed_video_metadata}

  defp collect(items, parser) do
    result =
      Enum.reduce_while(items, {:ok, []}, fn item, {:ok, acc} ->
        case parser.(item) do
          {:ok, value} -> {:cont, {:ok, [value | acc]}}
          {:error, _} = error -> {:halt, error}
        end
      end)

    case result do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      error -> error
    end
  end
end
