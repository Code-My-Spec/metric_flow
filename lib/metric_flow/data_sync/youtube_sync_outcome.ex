defmodule MetricFlow.DataSync.YouTubeSyncOutcome do
  @moduledoc "Summarizes independent YouTube report results for Sync History."

  def summarize({:error, reason}) do
    %{
      status: :failed,
      records_synced: 0,
      error_message: message(reason),
      provider_error_detail: detail(reason)
    }
  end

  def summarize({:ok, outcomes}) do
    errors = Enum.filter(outcomes, &match?(%{result: {:error, _}}, &1))
    successes = Enum.filter(outcomes, &match?(%{result: {:ok, _}}, &1))

    count =
      Enum.reduce(successes, 0, fn %{result: {:ok, result}}, acc ->
        acc + result.observations_written
      end)

    status =
      cond do
        errors == [] -> :success
        successes == [] -> :failed
        true -> :partial_success
      end

    messages =
      Enum.flat_map(outcomes, fn
        %{channel_id: id, family: family, result: {:error, reason}} ->
          ["Channel #{id} #{family}: #{message(reason)}"]

        %{channel_id: id, family: "revenue", result: {:skipped, :missing_revenue_permission}} ->
          ["Channel #{id}: revenue skipped because revenue permission was not granted."]

        _ ->
          []
      end)

    provider_detail =
      Enum.find_value(errors, fn %{result: {:error, reason}} -> detail(reason) end)

    %{
      status: status,
      records_synced: count,
      error_message: if(messages == [], do: nil, else: Enum.join(messages, "; ")),
      provider_error_detail: provider_detail
    }
  end

  defp message({:provider_http_error, reason, detail}) do
    base = message(reason)

    with %{"body" => body} when is_binary(body) <- detail,
         {:ok, %{"error" => %{"message" => provider_message}}} <- Jason.decode(body),
         true <- is_binary(provider_message) and provider_message != "" do
      base <> " " <> String.slice(provider_message, 0, 1000)
    else
      _ -> base
    end
  end

  defp message(:quota_exceeded),
    do: "YouTube daily quota or request limit was reached. Retry after the quota resets."

  defp message(:unauthorized), do: "YouTube access was revoked or denied. Reconnect YouTube."

  defp message(:forbidden),
    do: "YouTube access forbidden. Check channel access and reconnect if needed."

  defp message(:token_expired),
    do: "YouTube authorization expired or was revoked. Reconnect YouTube."

  defp message(:channel_not_found), do: "Selected channel is no longer accessible."
  defp message(:missing_channels), do: "Select at least one YouTube channel before syncing."
  defp message({:http_error, status}), do: "YouTube returned HTTP #{status}."

  defp message(_),
    do: "YouTube report could not be validated or saved. Existing data was retained."

  defp detail({:provider_http_error, _, detail}), do: detail
  defp detail(_), do: nil
end
