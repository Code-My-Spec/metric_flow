defmodule MetricFlow.DataSync.YouTubeVideos do
  @moduledoc "Discovers uploads and fetches channel-owned video metadata in bounded batches."

  alias MetricFlow.DataSync.{YouTubeHttp, YouTubeVideo}

  @playlist_url "https://www.googleapis.com/youtube/v3/playlistItems"
  @videos_url "https://www.googleapis.com/youtube/v3/videos"

  def fetch(integration, channel_id, playlist_id, opts)
      when is_binary(playlist_id) and byte_size(playlist_id) > 0 do
    with {:ok, ids} <- inventory(integration, playlist_id, nil, MapSet.new(), [], opts) do
      fetch_metadata(integration, channel_id, ids, opts)
    end
  end

  def fetch(_, _, _, _), do: {:error, :missing_uploads_playlist}

  defp inventory(integration, playlist_id, token, seen, pages, opts) do
    params = [part: "contentDetails", playlistId: playlist_id, maxResults: 50]
    params = if token, do: Keyword.put(params, :pageToken, token), else: params

    with {:ok, body} <- YouTubeHttp.get(integration, @playlist_url, params, opts),
         {:ok, page} <- YouTubeVideo.parse_page(body) do
      next_page(page, integration, playlist_id, seen, [page.ids | pages], opts)
    end
  end

  defp next_page(%{next_page_token: nil}, _integration, _playlist_id, _seen, pages, _opts) do
    {:ok, pages |> Enum.reverse() |> List.flatten() |> Enum.uniq()}
  end

  defp next_page(%{next_page_token: token}, integration, playlist_id, seen, pages, opts) do
    if MapSet.member?(seen, token) do
      {:error, :repeated_page_token}
    else
      inventory(integration, playlist_id, token, MapSet.put(seen, token), pages, opts)
    end
  end

  defp fetch_metadata(integration, channel_id, ids, opts) do
    result =
      ids
      |> Enum.chunk_every(50)
      |> Enum.reduce_while({:ok, []}, fn batch, {:ok, pages} ->
        case metadata_batch(integration, channel_id, batch, opts) do
          {:ok, videos} -> {:cont, {:ok, [videos | pages]}}
          {:error, _} = error -> {:halt, error}
        end
      end)

    case result do
      {:ok, pages} -> {:ok, pages |> Enum.reverse() |> List.flatten()}
      error -> error
    end
  end

  defp metadata_batch(integration, channel_id, ids, opts) do
    params = [part: "snippet", id: Enum.join(ids, ","), maxResults: 50]

    with {:ok, body} <- YouTubeHttp.get(integration, @videos_url, params, opts) do
      YouTubeVideo.parse_metadata(body, channel_id, ids)
    end
  end
end
