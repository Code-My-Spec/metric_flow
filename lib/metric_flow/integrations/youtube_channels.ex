defmodule MetricFlow.Integrations.YouTubeChannels do
  @moduledoc "Retrieves channels available to an authorized YouTube identity."

  @url "https://www.googleapis.com/youtube/v3/channels"

  def list_channels(access_token, opts \\ []) when is_binary(access_token) do
    fetch_page(access_token, opts, nil, MapSet.new(), [])
  end

  defp fetch_page(access_token, opts, page_token, seen, pages) do
    params = [part: "snippet", mine: true, maxResults: 50]
    params = if page_token, do: Keyword.put(params, :pageToken, page_token), else: params

    request =
      Application.get_env(:metric_flow, :req_http_options, [])
      |> Keyword.merge(
        method: :get,
        url: @url,
        params: params,
        headers: [{"authorization", "Bearer #{access_token}"}],
        retry: false,
        redirect: false
      )

    request =
      case Keyword.fetch(opts, :http_plug) do
        {:ok, plug} -> Keyword.put(request, :plug, plug)
        :error -> request
      end

    case Req.request(request) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        with {:ok, channels, next} <- parse_page(body) do
          continue_pages(access_token, opts, next, seen, [channels | pages])
        end

      {:ok, %Req.Response{status: 401}} ->
        {:error, :unauthorized}

      {:ok, %Req.Response{status: 403}} ->
        {:error, :forbidden}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_error, status}}

      {:error, _reason} ->
        {:error, :request_failed}
    end
  rescue
    Jason.DecodeError -> {:error, :malformed_response}
  end

  defp continue_pages(_access_token, _opts, next, _seen, pages) when next in [nil, ""] do
    {:ok, pages |> Enum.reverse() |> List.flatten() |> Enum.uniq_by(& &1.id)}
  end

  defp continue_pages(access_token, opts, next, seen, pages) do
    if MapSet.member?(seen, next) do
      {:error, :invalid_pagination}
    else
      fetch_page(access_token, opts, next, MapSet.put(seen, next), pages)
    end
  end

  defp parse_page(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> parse_page(decoded)
      {:error, _} -> {:error, :malformed_response}
    end
  end

  defp parse_page(%{"items" => items} = body) when is_list(items) do
    next = Map.get(body, "nextPageToken")

    if (is_nil(next) or is_binary(next)) and Enum.all?(items, &valid_channel?/1) do
      channels =
        Enum.map(items, fn item ->
          %{id: item["id"], name: item["snippet"]["title"]}
        end)

      {:ok, channels, next}
    else
      {:error, :malformed_response}
    end
  end

  defp parse_page(_), do: {:error, :malformed_response}

  defp valid_channel?(%{"id" => id, "snippet" => %{"title" => title}}),
    do: is_binary(id) and id != "" and is_binary(title)

  defp valid_channel?(_), do: false
end
