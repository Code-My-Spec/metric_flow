defmodule MetricFlow.DataSync.YouTubeHttp do
  @moduledoc "Authenticated YouTube requests with sanitized provider error capture."

  alias MetricFlow.DataSync.ProviderHttp

  def get(integration, url, params, opts \\ []) do
    request =
      Application.get_env(:metric_flow, :req_http_options, [])
      |> Keyword.merge(
        method: :get,
        url: url,
        params: params,
        headers: [{"authorization", "Bearer #{integration.access_token}"}],
        retry: false,
        redirect: false
      )

    request =
      case Keyword.fetch(opts, :http_plug) do
        {:ok, plug} -> Keyword.put(request, :plug, plug)
        :error -> request
      end

    {result, detail} =
      ProviderHttp.capture(
        fn -> request(request) end,
        [integration.access_token, integration.refresh_token]
      )

    case result do
      {:error, reason} when not is_nil(detail) -> {:error, {:provider_http_error, reason, detail}}
      other -> other
    end
  end

  defp request(opts) do
    case ProviderHttp.request(opts) do
      {:ok, %Req.Response{status: 200, body: body}} -> decode(body)
      {:ok, %Req.Response{status: 401}} -> {:error, :unauthorized}
      {:ok, %Req.Response{status: 403, body: body}} -> {:error, forbidden_reason(body)}
      {:ok, %Req.Response{status: 429}} -> {:error, :quota_exceeded}
      {:ok, %Req.Response{status: status}} -> {:error, {:http_error, status}}
      {:error, _} -> {:error, :request_failed}
    end
  rescue
    Jason.DecodeError -> {:error, :malformed_response}
  end

  defp decode(body) when is_map(body) do
    if Map.has_key?(body, "error"), do: {:error, :provider_error}, else: {:ok, body}
  end

  defp decode(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} when is_map(decoded) -> decode(decoded)
      _ -> {:error, :malformed_response}
    end
  end

  defp decode(_), do: {:error, :malformed_response}

  defp forbidden_reason(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> forbidden_reason(decoded)
      _ -> :forbidden
    end
  end

  defp forbidden_reason(%{"error" => %{"errors" => errors}}) when is_list(errors) do
    if Enum.any?(errors, fn
         %{"reason" => reason} ->
           reason in [
             "quotaExceeded",
             "dailyLimitExceeded",
             "rateLimitExceeded",
             "userRateLimitExceeded"
           ]

         _ ->
           false
       end), do: :quota_exceeded, else: :forbidden
  end

  defp forbidden_reason(_), do: :forbidden
end
